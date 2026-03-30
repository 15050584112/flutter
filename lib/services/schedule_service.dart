import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:ccviewer_mobile_hub/models/saved_connection.dart";
import "package:ccviewer_mobile_hub/models/scheduled_task.dart";
import "package:ccviewer_mobile_hub/services/storage_service.dart";

class TerminalSessionInfo {
  TerminalSessionInfo({
    required this.sessionId,
    required this.running,
    required this.initialized,
    required this.createdAt,
    this.currentLauncherCommand,
  });

  final String sessionId;
  final bool running;
  final bool initialized;
  final DateTime createdAt;
  final String? currentLauncherCommand;

  String get shortId {
    if (sessionId.isEmpty) return sessionId;
    return sessionId.length <= 6 ? sessionId : sessionId.substring(0, 6);
  }

  static TerminalSessionInfo fromJson(Map<String, dynamic> json) {
    return TerminalSessionInfo(
      sessionId: json["sessionId"]?.toString() ?? "",
      running: json["running"] == true,
      initialized: json["initialized"] == true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json["createdAt"] is int ? json["createdAt"] as int : int.tryParse(json["createdAt"]?.toString() ?? "0") ?? 0),
        isUtc: false,
      ),
      currentLauncherCommand: json["currentLauncherCommand"]?.toString(),
    );
  }
}

class TerminalSessionFetchResult {
  const TerminalSessionFetchResult({
    required this.sessions,
    this.errorMessage,
    this.sourceUri,
  });

  final List<TerminalSessionInfo> sessions;
  final String? errorMessage;
  final Uri? sourceUri;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;
}

class ScheduleService extends ChangeNotifier {
  ScheduleService._internal();

  static final ScheduleService instance = ScheduleService._internal();

  static const String _storageKey = "scheduled_tasks";

  final StorageService _storage = StorageService();
  final Map<String, Timer> _timers = {};

  List<ScheduledTask> _tasks = <ScheduledTask>[];

  List<ScheduledTask> get tasks {
    final sorted = List<ScheduledTask>.from(_tasks);
    sorted.sort((a, b) {
      final aNext = a.nextRunAt ?? a.scheduledTime ?? a.createdAt;
      final bNext = b.nextRunAt ?? b.scheduledTime ?? b.createdAt;
      return aNext.compareTo(bNext);
    });
    return sorted;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? "";
    _tasks = ScheduledTask.listFromJson(raw);
    _tasks = _tasks.map((t) => _withNextRun(t)).toList();
    _scheduleAll();
    notifyListeners();
  }

  Future<void> saveTask(ScheduledTask task) async {
    final existing = _tasks.indexWhere((t) => t.id == task.id);
    final updated = _withNextRun(task);
    if (existing >= 0) {
      _tasks[existing] = updated;
    } else {
      _tasks.add(updated);
    }
    await _persist();
    _scheduleTask(updated);
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    _cancelTimer(id);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleTask(String id, bool enabled) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final updated = _tasks[index].copyWith(enabled: enabled);
    _tasks[index] = _withNextRun(updated);
    await _persist();
    _scheduleTask(_tasks[index]);
    notifyListeners();
  }

  Future<List<SavedConnection>> loadConnections() async {
    return _storage.loadConnections();
  }

  Future<TerminalSessionFetchResult> fetchTerminalSessions(SavedConnection connection) async {
    final endpoints = _resolveTerminalSessionEndpoints(connection);
    if (endpoints.isEmpty) {
      return const TerminalSessionFetchResult(
        sessions: <TerminalSessionInfo>[],
        errorMessage: "未找到可用的终端地址",
      );
    }

    String? firstError;
    for (final endpoint in endpoints) {
      final result = await _fetchTerminalSessionsFromEndpoint(endpoint);
      if (result.sessions.isNotEmpty || !result.hasError) {
        return result;
      }
      firstError ??= result.errorMessage;
    }

    return TerminalSessionFetchResult(
      sessions: <TerminalSessionInfo>[],
      errorMessage: firstError ?? "无法获取终端列表",
    );
  }

  Future<void> runTaskNow(ScheduledTask task) async {
    final connection = await _findConnection(task.connectionId);
    if (connection == null) {
      await _markTaskError(task.id, "找不到连接");
      return;
    }

    final ok = await _sendCommand(
      connection: connection,
      sessionId: task.sessionId,
      command: task.command,
    );

    if (!ok) {
      await _markTaskError(task.id, "执行失败，无法连接终端");
      return;
    }

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0 && _tasks[index].enabled) {
      final now = DateTime.now();
      final updated = _tasks[index].copyWith(
        lastRunAt: now,
        lastError: null,
      );
      _tasks[index] = _withNextRun(updated, now: now);
      await _persist();
      _scheduleTask(_tasks[index]);
      notifyListeners();
    }
  }

  Future<bool> sendCommandNow({
    required SavedConnection connection,
    required String sessionId,
    required String command,
  }) async {
    if (command.trim().isEmpty) return false;
    return _sendCommand(
      connection: connection,
      sessionId: sessionId,
      command: command,
    );
  }

  ScheduledTask _withNextRun(ScheduledTask task, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (!task.enabled) {
      return task.copyWith(nextRunAt: null);
    }
    if (task.scheduleKind == TaskScheduleKind.once) {
      final scheduled = task.scheduledTime;
      if (scheduled == null) return task.copyWith(nextRunAt: null);
      if (scheduled.isBefore(current)) {
        return task.copyWith(nextRunAt: scheduled);
      }
      return task.copyWith(nextRunAt: scheduled);
    }

    final value = task.intervalValue ?? 0;
    final unit = task.intervalUnit ?? IntervalUnit.minutes;
    if (value <= 0) return task.copyWith(nextRunAt: null);

    final base = task.lastRunAt ?? task.scheduledTime ?? task.createdAt;
    Duration step;
    switch (unit) {
      case IntervalUnit.hours:
        step = Duration(hours: value);
        break;
      case IntervalUnit.days:
        step = Duration(days: value);
        break;
      case IntervalUnit.minutes:
      default:
        step = Duration(minutes: value);
        break;
    }

    var next = base.add(step);
    while (next.isBefore(current)) {
      next = next.add(step);
    }
    return task.copyWith(nextRunAt: next);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, ScheduledTask.listToJson(_tasks));
  }

  void _scheduleAll() {
    for (final task in _tasks) {
      _scheduleTask(task);
    }
  }

  void _scheduleTask(ScheduledTask task) {
    _cancelTimer(task.id);
    if (!task.enabled) return;
    final next = task.nextRunAt;
    if (next == null) return;
    final delay = next.difference(DateTime.now());
    final safeDelay = delay.isNegative ? const Duration(seconds: 1) : delay;
    _timers[task.id] = Timer(safeDelay, () async {
      final taskId = task.id;
      final latest = _tasks.where((t) => t.id == taskId).firstOrNull;
      if (latest == null || !latest.enabled) return;
      await runTaskNow(latest);
      if (latest.scheduleKind == TaskScheduleKind.once) {
        await toggleTask(latest.id, false);
      }
    });
  }

  void _cancelTimer(String id) {
    final t = _timers.remove(id);
    if (t != null) {
      t.cancel();
    }
  }

  Future<SavedConnection?> _findConnection(String id) async {
    final all = await _storage.loadConnections();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _markTaskError(String id, String error) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(lastError: error);
    await _persist();
    notifyListeners();
  }

  List<Uri> _resolveTerminalSessionEndpoints(SavedConnection connection) {
    final candidates = <Uri>[];
    final seen = <String>{};

    void addCandidate({
      required Uri? baseUri,
      String? token,
      bool mobileMode = false,
    }) {
      if (baseUri == null || baseUri.host.isEmpty) return;
      final normalizedToken = token?.trim();
      final queryParameters = <String, String>{};
      if (mobileMode) {
        queryParameters["mobile"] = "true";
      }
      if (normalizedToken != null && normalizedToken.isNotEmpty) {
        queryParameters["token"] = normalizedToken;
      }
      final endpoint = Uri(
        scheme: baseUri.scheme == "https" ? "https" : "http",
        host: baseUri.host,
        port: baseUri.hasPort ? baseUri.port : null,
        path: "/api/terminal-sessions",
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );
      final key = endpoint.toString();
      if (seen.add(key)) {
        candidates.add(endpoint);
      }
    }

    Uri? parseWebviewUri(String? raw) {
      final value = raw?.trim() ?? "";
      if (value.isEmpty) return null;
      return Uri.tryParse(value);
    }

    Uri? parseWsUri(String? raw) {
      final value = raw?.trim() ?? "";
      if (value.isEmpty) return null;
      final uri = Uri.tryParse(value);
      if (uri == null) return null;
      final scheme = uri.scheme == "wss" ? "https" : "http";
      return Uri(
        scheme: scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      );
    }

    String? resolveToken(Uri? uri) {
      final tokenFromUri = uri?.queryParameters["token"]?.trim();
      if (tokenFromUri != null && tokenFromUri.isNotEmpty) {
        return tokenFromUri;
      }
      final connectionToken = connection.lastToken?.trim();
      if (connectionToken != null && connectionToken.isNotEmpty) {
        return connectionToken;
      }
      return null;
    }

    final webviewUri = parseWebviewUri(connection.lastWebviewUrl);
    addCandidate(
      baseUri: webviewUri,
      token: resolveToken(webviewUri),
      mobileMode: webviewUri?.queryParameters["mobile"] == "true",
    );

    final rawWsUri = parseWebviewUri(connection.lastWsUrl);
    final wsUri = parseWsUri(connection.lastWsUrl);
    if (connection.isHubMode) {
      final hubDomain = connection.hubDomain?.trim() ?? "";
      final hubToken = connection.hubClientToken?.trim();
      if (hubDomain.isNotEmpty && hubToken != null && hubToken.isNotEmpty) {
        final hubUri = Uri.tryParse(hubDomain);
        addCandidate(
          baseUri: hubUri,
          token: hubToken,
        );
      }
    }

    addCandidate(
      baseUri: wsUri,
      token: resolveToken(webviewUri) ?? resolveToken(rawWsUri),
    );

    return candidates;
  }

  Uri? _resolveViewerUri(SavedConnection connection) {
    if (connection.isHubMode) {
      final hubDomain = connection.hubDomain?.trim() ?? "";
      if (hubDomain.isNotEmpty) {
        final hubUri = Uri.tryParse(hubDomain);
        if (hubUri != null && hubUri.host.isNotEmpty) {
          return hubUri;
        }
      }
    }

    final webviewUri = Uri.tryParse((connection.lastWebviewUrl ?? "").trim());
    if (webviewUri != null && webviewUri.host.isNotEmpty) {
      return webviewUri;
    }

    final wsUri = Uri.tryParse((connection.lastWsUrl ?? "").trim());
    if (wsUri != null && wsUri.host.isNotEmpty) {
      return Uri(
        scheme: wsUri.scheme == "wss" ? "https" : "http",
        host: wsUri.host,
        port: wsUri.hasPort ? wsUri.port : null,
      );
    }

    return null;
  }

  String? _resolveTerminalToken(SavedConnection connection) {
    if (connection.isHubMode) {
      final hubToken = connection.hubClientToken?.trim();
      if (hubToken != null && hubToken.isNotEmpty) return hubToken;
    }

    final webviewUri = Uri.tryParse((connection.lastWebviewUrl ?? "").trim());
    final webviewToken = webviewUri?.queryParameters["token"]?.trim();
    if (webviewToken != null && webviewToken.isNotEmpty) {
      return webviewToken;
    }

    final wsUri = Uri.tryParse((connection.lastWsUrl ?? "").trim());
    final wsToken = wsUri?.queryParameters["token"]?.trim();
    if (wsToken != null && wsToken.isNotEmpty) {
      return wsToken;
    }

    final connectionToken = connection.lastToken?.trim();
    if (connectionToken != null && connectionToken.isNotEmpty) {
      return connectionToken;
    }

    return null;
  }

  Future<TerminalSessionFetchResult> _fetchTerminalSessionsFromEndpoint(Uri endpoint) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(endpoint).timeout(const Duration(seconds: 8));
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decodeStream(res);

      if (res.statusCode >= 400) {
        return TerminalSessionFetchResult(
          sessions: <TerminalSessionInfo>[],
          errorMessage: "HTTP ${res.statusCode}",
          sourceUri: endpoint,
        );
      }

      final contentType = res.headers.contentType?.mimeType.toLowerCase() ?? "";
      if (contentType.isNotEmpty && !contentType.contains("json")) {
        return TerminalSessionFetchResult(
          sessions: <TerminalSessionInfo>[],
          errorMessage: "接口返回了非 JSON 内容",
          sourceUri: endpoint,
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return TerminalSessionFetchResult(
          sessions: <TerminalSessionInfo>[],
          errorMessage: "接口数据格式不正确",
          sourceUri: endpoint,
        );
      }

      final sessions = decoded["sessions"];
      if (sessions is! List) {
        return TerminalSessionFetchResult(
          sessions: <TerminalSessionInfo>[],
          errorMessage: "接口中没有 sessions 字段",
          sourceUri: endpoint,
        );
      }

      return TerminalSessionFetchResult(
        sessions: sessions
            .whereType<Map>()
            .map((item) => TerminalSessionInfo.fromJson(item.cast<String, dynamic>()))
            .toList(),
        sourceUri: endpoint,
      );
    } on TimeoutException {
      return TerminalSessionFetchResult(
        sessions: <TerminalSessionInfo>[],
        errorMessage: "请求终端列表超时",
        sourceUri: endpoint,
      );
    } catch (error) {
      return TerminalSessionFetchResult(
        sessions: <TerminalSessionInfo>[],
        errorMessage: "获取终端列表失败: $error",
        sourceUri: endpoint,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _sendCommand({
    required SavedConnection connection,
    required String sessionId,
    required String command,
  }) async {
    if (connection.isHubMode) {
      return _sendHubCommand(
        connection: connection,
        sessionId: sessionId,
        command: command,
      );
    }

    return _sendLanCommand(
      connection: connection,
      sessionId: sessionId,
      command: command,
    );
  }

  Future<bool> _sendHubCommand({
    required SavedConnection connection,
    required String sessionId,
    required String command,
  }) async {
    final hubUri = _resolveHubRelayUri(connection);
    final hubToken = connection.hubClientToken?.trim();
    if (hubUri == null || hubToken == null || hubToken.isEmpty) {
      return false;
    }

    final wsUri = Uri(
      scheme: hubUri.scheme == "https" ? "wss" : "ws",
      host: hubUri.host,
      port: hubUri.hasPort ? hubUri.port : null,
      path: "/ws/mobile/client",
      queryParameters: <String, String>{"token": hubToken},
    );

    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<bool>();
    WebSocket? socket;
    StreamSubscription<dynamic>? subscription;

    try {
      socket = await WebSocket.connect(wsUri.toString()).timeout(const Duration(seconds: 6));
      subscription = socket.listen(
        (data) {
          if (completer.isCompleted) return;
          try {
            final decoded = jsonDecode(data.toString());
            if (decoded is! Map) return;
            final message = decoded.cast<String, dynamic>();
            final type = message["type"]?.toString();
            final responseRequestId = message["requestId"]?.toString();
            if (responseRequestId != requestId) return;
            if (type == "send_message_result") {
              completer.complete(message["ok"] == true);
              return;
            }
            if (type == "error") {
              completer.complete(false);
            }
          } catch (_) {
            // Ignore non-JSON bootstrap messages from the Hub socket.
          }
        },
        onError: (_) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      );

      socket.add(
        jsonEncode(
          <String, dynamic>{
            "type": "send_message",
            "sessionId": sessionId,
            "text": command.replaceAll(RegExp(r"[\r\n]+$"), ""),
            "requestId": requestId,
          },
        ),
      );

      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    } finally {
      await subscription?.cancel();
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  Future<bool> _sendLanCommand({
    required SavedConnection connection,
    required String sessionId,
    required String command,
  }) async {
    final viewerUri = _resolveViewerUri(connection);
    if (viewerUri == null) return false;

    final token = _resolveTerminalToken(connection) ?? viewerUri.queryParameters["token"];
    final wsScheme = viewerUri.scheme == "https" ? "wss" : "ws";
    final wsUri = Uri(
      scheme: wsScheme,
      host: viewerUri.host,
      port: viewerUri.hasPort ? viewerUri.port : null,
      path: "/ws/terminal",
      queryParameters: {
        if (token != null) "token": token,
        "sessionId": sessionId,
      },
    );

    try {
      final socket = await WebSocket.connect(wsUri.toString()).timeout(const Duration(seconds: 6));
      final sanitized = command.replaceAll(RegExp(r"[\r\n]+$"), "");
      socket.add(jsonEncode({"type": "input", "data": sanitized}));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      socket.add(jsonEncode({"type": "input", "data": "\r"}));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Uri? _resolveHubRelayUri(SavedConnection connection) {
    final hubDomain = connection.hubDomain?.trim() ?? "";
    if (hubDomain.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(hubDomain);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }
}
