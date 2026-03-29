import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";

import "package:ccviewer_mobile_hub/models/connect_payload.dart";
import "package:ccviewer_mobile_hub/models/hub_pairing_result.dart";
import "package:ccviewer_mobile_hub/models/saved_connection.dart";
import "package:ccviewer_mobile_hub/services/storage_service.dart";

/// 连接管理器 - 管理多个已保存连接和当前活跃连接
/// 新版方案：使用 WebView 加载 cc-viewer 页面，无需维护 WebSocket 连接
class ConnectionManager extends ChangeNotifier {
  ConnectionManager({
    StorageService? storage,
  }) : _storage = storage ?? StorageService();

  final StorageService _storage;

  List<SavedConnection> _connections = <SavedConnection>[];
  String? _activeConnectionId;

  /// 获取已保存连接列表（按 lastConnectedAt 倒序排列）
  List<SavedConnection> get connections {
    final sorted = List<SavedConnection>.from(_connections);
    sorted.sort((a, b) => b.lastConnectedAt.compareTo(a.lastConnectedAt));
    return sorted;
  }

  /// 获取当前活跃连接
  SavedConnection? get activeConnection {
    if (_activeConnectionId == null) return null;
    try {
      return _connections.firstWhere((c) => c.id == _activeConnectionId);
    } catch (_) {
      return null;
    }
  }

  /// 获取当前活跃连接 ID
  String? get activeConnectionId => _activeConnectionId;

  /// 从存储加载已保存的连接
  Future<void> loadConnections() async {
    _connections = await _storage.loadConnections();
    // 加载后去重，处理已有的重复数据
    await _deduplicateConnections();
    notifyListeners();
  }

  /// 连接到指定的 payload 并保存连接信息
  /// 
  /// 新版 WebView 方案：不需要建立 WebSocket 连接
  /// 只需保存连接信息，由 WebView 加载 cc-viewer 页面后自行处理连接
  Future<void> connectTo(ConnectPayload payload) async {
    // 先断开当前连接（清理旧状态）
    await disconnect();

    HubPairingResult? hubResult;
    if (payload.isHubMode) {
      hubResult = await _consumeHubPairing(payload);
    }

    final resolvedViewerUrl = _resolveViewerUrl(payload, hubResult);
    final resolvedWorkspacePath = _resolveWorkspacePath(payload, hubResult);
    final resolvedProjectName = _resolveProjectName(payload, hubResult);
    final resolvedWebviewUrl = _resolveWebviewUrl(payload, hubResult);
    final resolvedToken = _resolveToken(payload, hubResult);
    final resolvedConnectionSessionId =
        _resolveConnectionSessionId(payload, hubResult);

    // 查找是否已存在相同连接（优先用 viewerUrl，其次用 workspacePath）
    // viewerUrl 是最稳定的标识，同一台电脑的 cc-viewer 地址不变
    SavedConnection? existing;
    for (final c in _connections) {
      final connViewerUrl = _deriveViewerUrlFromConnection(c);
      
      // 优先匹配 viewerUrl（最稳定）
      if (resolvedViewerUrl.isNotEmpty && 
          connViewerUrl.isNotEmpty && 
          resolvedViewerUrl == connViewerUrl) {
        existing = c;
        break;
      }
      
      // 其次匹配 workspacePath（需要两边都非空）
      if (resolvedWorkspacePath.isNotEmpty && 
          c.workspacePath.isNotEmpty && 
          resolvedWorkspacePath == c.workspacePath) {
        existing = c;
        break;
      }
    }

    // 创建或更新 SavedConnection
    // 新版方案：直接保存为 connected 状态，不需要等待 WebSocket 连接
    final nextProjectName =
        resolvedProjectName.isNotEmpty ? resolvedProjectName : (existing?.projectName ?? "");
    final nextWorkspacePath = resolvedWorkspacePath.isNotEmpty
        ? resolvedWorkspacePath
        : (existing?.workspacePath ?? "");
    final nextAlias = _resolveAlias(
      currentAlias: existing?.alias,
      currentProjectName: existing?.projectName,
      nextProjectName: nextProjectName,
      viewerUrl: resolvedViewerUrl,
    );

    final shouldClearWebviewUrl = resolvedWebviewUrl.isEmpty;

    final connection = existing?.copyWith(
          alias: nextAlias,
          projectName: nextProjectName,
          workspacePath: nextWorkspacePath,
          lastConnectedAt: DateTime.now(),
          lastStatus: "connected",
          lastWsUrl: null,
          lastConnectionSessionId: resolvedConnectionSessionId,
          hubDomain: payload.hubDomain,
          lastWebviewUrl: resolvedWebviewUrl.isEmpty ? null : resolvedWebviewUrl,
          clearLastWebviewUrl: shouldClearWebviewUrl,
          lastToken: resolvedToken,
          hubClientToken: payload.isHubMode ? resolvedToken : null,
          clearHubClientToken: !payload.isHubMode,
          clearHubDomain: !payload.isHubMode,
        ) ??
        SavedConnection(
          id: SavedConnection.generateId(),
          alias: nextAlias,
          mode: payload.mode,
          projectName: nextProjectName,
          workspacePath: nextWorkspacePath,
          hubDomain: payload.hubDomain,
          lastConnectedAt: DateTime.now(),
          lastStatus: "connected",
          lastWsUrl: null,
          lastConnectionSessionId: resolvedConnectionSessionId,
          lastWebviewUrl: resolvedWebviewUrl.isEmpty ? null : resolvedWebviewUrl,
          lastToken: resolvedToken,
          hubClientToken: payload.isHubMode ? resolvedToken : null,
        );

    // 设置当前活跃连接
    _activeConnectionId = connection.id;

    // 新版 WebView 方案：不需要建立 WebSocket 连接
    // WebView 加载 cc-viewer 页面后，cc-viewer 自己会处理 WebSocket 连接
    // 直接保存连接信息并通知 UI
    await _saveAndUpdateConnection(connection);
    await _deduplicateConnections();
    notifyListeners();
  }

  Future<HubPairingResult> _consumeHubPairing(ConnectPayload payload) async {
    final apiUrl = payload.pairingApiUrl;
    if (apiUrl == null || apiUrl.trim().isEmpty) {
      throw StateError("Hub 配对地址缺失，请重新扫码");
    }
    final pairingCode = (payload.pairingCode ?? "").trim();
    if (pairingCode.isEmpty) {
      throw StateError("Hub 配对码缺失，请重新扫码");
    }

    final uri = Uri.tryParse(apiUrl);
    if (uri == null) {
      throw StateError("Hub 配对地址无效: $apiUrl");
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode(
          <String, dynamic>{
            "connectionSessionId": payload.connectionSessionId,
            "pairingCode": pairingCode,
          },
        ),
      );
      final res = await req.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decodeStream(res);

      if (res.statusCode >= 400) {
        throw StateError("Hub 配对失败: HTTP ${res.statusCode}");
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw StateError("Hub 配对返回格式不正确");
      }

      final result = HubPairingResult.fromJson(decoded.cast<String, dynamic>());
      if (result.clientToken.trim().isEmpty) {
        throw StateError("Hub 配对返回缺少 clientToken");
      }

      return result;
    } on TimeoutException {
      throw StateError("Hub 配对超时，请稍后再试");
    } catch (error) {
      throw StateError("Hub 配对失败: $error");
    } finally {
      client.close(force: true);
    }
  }

  static String _resolveViewerUrl(ConnectPayload payload, HubPairingResult? hubResult) {
    if (payload.isHubMode) {
      final candidate = (hubResult?.viewerUrl ?? "").trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return payload.viewerUrl;
  }

  static String _resolveWebviewUrl(ConnectPayload payload, HubPairingResult? hubResult) {
    if (payload.isHubMode) {
      // Hub模式：使用Hub服务器返回的viewerUrl（Hub前端界面地址）
      final candidate = (hubResult?.viewerUrl ?? "").trim();
      if (candidate.isNotEmpty) return candidate;
      return "";
    }
    return payload.fullWebviewUrl;
  }

  static String _resolveToken(ConnectPayload payload, HubPairingResult? hubResult) {
    if (payload.isHubMode) {
      final candidate = (hubResult?.clientToken ?? "").trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return payload.token ?? "";
  }

  static String _resolveConnectionSessionId(ConnectPayload payload, HubPairingResult? hubResult) {
    if (payload.isHubMode) {
      final candidate = (hubResult?.connectionSessionId ?? "").trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return payload.connectionSessionId;
  }

  static String _resolveWorkspacePath(ConnectPayload payload, HubPairingResult? hubResult) {
    final hubPath = (hubResult?.workspacePath ?? "").trim();
    if (hubPath.isNotEmpty) return hubPath;
    return (payload.workspacePath ?? "").trim();
  }

  static String _resolveProjectName(ConnectPayload payload, HubPairingResult? hubResult) {
    final hubName = (hubResult?.projectName ?? "").trim();
    if (hubName.isNotEmpty) return hubName;
    return _normalizeProjectName(payload.projectName);
  }


  /// 重连已保存的连接
  /// 
  /// 新版 WebView 方案：不需要建立 WebSocket 连接
  /// 只需更新连接状态，由 WebView 加载 cc-viewer 页面后自行处理连接
  Future<void> reconnect(SavedConnection conn) async {
    // 检查是否有 webviewUrl 可用
    if (conn.lastWebviewUrl == null || conn.lastWebviewUrl!.isEmpty) {
      // 尝试从 viewerUrl 构建 webviewUrl
      if (conn.lastWsUrl == null || conn.lastWsUrl!.isEmpty) {
        throw StateError("没有可用的 WebView URL，请重新扫码连接");
      }
    }

    // 先断开当前连接（清理旧状态）
    await disconnect();

    // 设置当前活跃连接
    _activeConnectionId = conn.id;

    // 新版 WebView 方案：不需要建立 WebSocket 连接
    // 直接更新状态，让调用方使用 lastWebviewUrl 导航到 ChatPage
    final updatedConnection = conn.copyWith(
      lastStatus: "connected",
      lastConnectedAt: DateTime.now(),
    );

    await _saveAndUpdateConnection(updatedConnection);
    notifyListeners();
  }

  /// 断开当前连接
  Future<void> disconnect() async {
    if (_activeConnectionId != null) {
      // 更新当前连接状态为 disconnected
      final current = activeConnection;
      if (current != null) {
        final disconnected = current.copyWith(
          lastStatus: "disconnected",
          lastConnectedAt: DateTime.now(),
        );
        await _saveAndUpdateConnection(disconnected);
      }
    }

    _activeConnectionId = null;
    notifyListeners();
  }

  /// 删除已保存的连接
  Future<void> deleteConnection(String id) async {
    // 如果删除的是当前活跃连接，先断开
    if (_activeConnectionId == id) {
      await disconnect();
    }

    await _storage.deleteConnection(id);
    _connections.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// 更新连接别名
  Future<void> updateAlias(String id, String alias) async {
    await _storage.updateAlias(id, alias);

    final index = _connections.indexWhere((c) => c.id == id);
    if (index >= 0) {
      _connections[index].alias = alias;
      notifyListeners();
    }
  }

  /// 回写从 WebView 页面拿到的真实连接元数据
  Future<void> updateConnectionMetadata(
    String id, {
    String? projectName,
    String? workspacePath,
  }) async {
    final index = _connections.indexWhere((c) => c.id == id);
    if (index < 0) return;

    final current = _connections[index];
    final normalizedProjectName = _normalizeProjectName(projectName);
    final normalizedWorkspacePath = (workspacePath ?? "").trim();
    final shouldRefreshAlias = !_hasMeaningfulText(current.alias) ||
        current.alias.trim() == current.projectName.trim();

    final updated = current.copyWith(
      alias: shouldRefreshAlias && normalizedProjectName.isNotEmpty
          ? normalizedProjectName
          : current.alias,
      projectName: normalizedProjectName.isNotEmpty
          ? normalizedProjectName
          : current.projectName,
      workspacePath: normalizedWorkspacePath.isNotEmpty
          ? normalizedWorkspacePath
          : current.workspacePath,
    );

    await _saveAndUpdateConnection(updated);
    await _deduplicateConnections();
    notifyListeners();
  }

  /// 根据 ID 获取连接
  SavedConnection? getConnectionById(String id) {
    try {
      return _connections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 保存并更新内存中的连接
  Future<void> _saveAndUpdateConnection(SavedConnection conn) async {
    await _storage.saveConnection(conn);

    final index = _connections.indexWhere((c) => c.id == conn.id);
    if (index >= 0) {
      _connections[index] = conn;
    } else {
      _connections.add(conn);
    }
  }

  /// 从 wsUrl 反推 viewerUrl
  static String _deriveViewerUrlFromWsUrl(String wsUrl) {
    final uri = Uri.tryParse(wsUrl);
    if (uri == null) return "";
    final httpScheme = uri.scheme == "wss" ? "https" : "http";
    final port = uri.hasPort ? ":${uri.port}" : "";
    return "$httpScheme://${uri.host}$port";
  }

  static String _deriveViewerUrlFromWebviewUrl(String webviewUrl) {
    final uri = Uri.tryParse(webviewUrl);
    if (uri == null) return "";
    final port = uri.hasPort ? ":${uri.port}" : "";
    return "${uri.scheme}://${uri.host}$port";
  }

  static String _deriveViewerUrlFromConnection(SavedConnection conn) {
    if (conn.lastWebviewUrl != null && conn.lastWebviewUrl!.isNotEmpty) {
      final webviewUrl = _deriveViewerUrlFromWebviewUrl(conn.lastWebviewUrl!);
      if (webviewUrl.isNotEmpty) return webviewUrl;
    }
    if (conn.lastWsUrl != null && conn.lastWsUrl!.isNotEmpty) {
      return _deriveViewerUrlFromWsUrl(conn.lastWsUrl!);
    }
    return "";
  }

  static bool _hasMeaningfulText(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.toLowerCase() != "unknown";
  }

  static String _normalizeProjectName(String? value) {
    return _hasMeaningfulText(value) ? value!.trim() : "";
  }

  static String _resolveAlias({
    String? currentAlias,
    String? currentProjectName,
    required String nextProjectName,
    required String viewerUrl,
  }) {
    final trimmedAlias = currentAlias?.trim() ?? "";
    final trimmedProjectName = currentProjectName?.trim() ?? "";

    if (_hasMeaningfulText(trimmedAlias) &&
        trimmedAlias != trimmedProjectName &&
        trimmedAlias.toLowerCase() != "unknown") {
      return trimmedAlias;
    }
    if (nextProjectName.isNotEmpty) {
      return nextProjectName;
    }

    final uri = Uri.tryParse(viewerUrl);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return "未命名连接";
  }

  /// 对连接列表去重，保留最新的连接信息
  /// 去重键：viewerUrl（最稳定）或 workspacePath
  Future<void> _deduplicateConnections() async {
    if (_connections.isEmpty) return;

    final seen = <String, int>{}; // key -> index of first occurrence
    final toRemove = <int>[];

    for (int i = 0; i < _connections.length; i++) {
      final conn = _connections[i];
      
      // 构建去重键：优先用 viewerUrl
      String key = _deriveViewerUrlFromConnection(conn);
      // 如果 viewerUrl 为空，用 workspacePath
      if (key.isEmpty && conn.workspacePath.isNotEmpty) {
        key = "wp:${conn.workspacePath}";
      }
      // 如果都为空，保留（无法判断是否重复）
      if (key.isEmpty) continue;

      if (seen.containsKey(key)) {
        // 发现重复，保留最新的（lastConnectedAt 更大的）
        final existingIdx = seen[key]!;
        final existingConn = _connections[existingIdx];
        
        if (conn.lastConnectedAt.isAfter(existingConn.lastConnectedAt)) {
          _connections[i] = conn.copyWith(
            alias: _resolveAlias(
              currentAlias: conn.alias,
              currentProjectName: conn.projectName,
              nextProjectName: _normalizeProjectName(conn.projectName).isNotEmpty
                  ? conn.projectName
                  : existingConn.projectName,
              viewerUrl: _deriveViewerUrlFromConnection(conn),
            ),
            projectName: _normalizeProjectName(conn.projectName).isNotEmpty
                ? conn.projectName
                : existingConn.projectName,
            workspacePath: conn.workspacePath.isNotEmpty
                ? conn.workspacePath
                : existingConn.workspacePath,
            lastWebviewUrl: (conn.lastWebviewUrl?.isNotEmpty ?? false)
                ? conn.lastWebviewUrl
                : existingConn.lastWebviewUrl,
            lastToken: (conn.lastToken?.isNotEmpty ?? false)
                ? conn.lastToken
                : existingConn.lastToken,
            hubClientToken: (conn.hubClientToken?.isNotEmpty ?? false)
                ? conn.hubClientToken
                : existingConn.hubClientToken,
          );
          toRemove.add(existingIdx);
          seen[key] = i;
        } else {
          _connections[existingIdx] = existingConn.copyWith(
            alias: _resolveAlias(
              currentAlias: existingConn.alias,
              currentProjectName: existingConn.projectName,
              nextProjectName: _normalizeProjectName(existingConn.projectName).isNotEmpty
                  ? existingConn.projectName
                  : conn.projectName,
              viewerUrl: _deriveViewerUrlFromConnection(existingConn),
            ),
            projectName: _normalizeProjectName(existingConn.projectName).isNotEmpty
                ? existingConn.projectName
                : conn.projectName,
            workspacePath: existingConn.workspacePath.isNotEmpty
                ? existingConn.workspacePath
                : conn.workspacePath,
            lastWebviewUrl: (existingConn.lastWebviewUrl?.isNotEmpty ?? false)
                ? existingConn.lastWebviewUrl
                : conn.lastWebviewUrl,
            lastToken: (existingConn.lastToken?.isNotEmpty ?? false)
                ? existingConn.lastToken
                : conn.lastToken,
            hubClientToken: (existingConn.hubClientToken?.isNotEmpty ?? false)
                ? existingConn.hubClientToken
                : conn.hubClientToken,
          );
          toRemove.add(i);
        }
      } else {
        seen[key] = i;
      }
    }

    // 如果有重复，执行清理
    if (toRemove.isNotEmpty) {
      // 按倒序移除，避免索引错乱
      toRemove.sort((a, b) => b.compareTo(a));
      for (final idx in toRemove) {
        _connections.removeAt(idx);
      }
      // 保存清理后的列表
      await _storage.saveConnections(_connections);
    }
  }

}
