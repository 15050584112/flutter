import "dart:async";
import "dart:convert";
import "dart:io";

import "package:ccviewer_mobile_hub/models/saved_connection.dart";
import "package:ccviewer_mobile_hub/models/scheduled_task.dart";
import "package:ccviewer_mobile_hub/services/schedule_service.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

Future<HttpServer> _startTerminalSessionsServer({
  required Future<void> Function(HttpRequest request) handler,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

Future<HttpServer> _startHubRelayServer({
  required Future<void> Function(WebSocket socket, HttpRequest request) handler,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (request.uri.path != "/ws/mobile/client" || !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    await handler(socket, request);
  });
  return server;
}

SavedConnection _buildConnection({
  required String id,
  String? lastWebviewUrl,
  String? lastWsUrl,
  String? lastToken,
  String? hubDomain,
  String? hubClientToken,
  String mode = "lan",
}) {
  return SavedConnection(
    id: id,
    alias: "alias",
    mode: mode,
    projectName: "project",
    workspacePath: "/tmp/project",
    lastConnectedAt: DateTime.now(),
    lastStatus: "connected",
    lastWebviewUrl: lastWebviewUrl,
    lastWsUrl: lastWsUrl,
    lastToken: lastToken,
    hubDomain: hubDomain,
    hubClientToken: hubClientToken,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ScheduleService.instance.load();
  });

  test("fetchTerminalSessions reads sessions from webview origin", () async {
    String? receivedToken;
    final server = await _startTerminalSessionsServer(
      handler: (request) async {
        if (request.uri.path != "/api/terminal-sessions") {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        receivedToken = request.uri.queryParameters["token"];
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            "sessions": [
              {
                "sessionId": "alpha",
                "running": true,
                "initialized": true,
                "createdAt": 1700000000000,
                "currentLauncherCommand": "claude",
              }
            ]
          }),
        );
        await request.response.close();
      },
    );
    addTearDown(() async => server.close(force: true));

    final connection = _buildConnection(
      id: "1",
      lastWebviewUrl: "http://127.0.0.1:${server.port}/?token=abc123",
    );

    final result = await ScheduleService.instance.fetchTerminalSessions(connection);

    expect(result.errorMessage, isNull);
    expect(result.sessions, hasLength(1));
    expect(result.sessions.first.sessionId, "alpha");
    expect(result.sessions.first.currentLauncherCommand, "claude");
    expect(receivedToken, "abc123");
  });

  test("fetchTerminalSessions preserves mobile auth flag for mobile webview urls", () async {
    String? receivedMobileFlag;
    String? receivedToken;
    final server = await _startTerminalSessionsServer(
      handler: (request) async {
        if (request.uri.path != "/api/terminal-sessions") {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        receivedMobileFlag = request.uri.queryParameters["mobile"];
        receivedToken = request.uri.queryParameters["token"];
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            "sessions": [
              {
                "sessionId": "mobile",
                "running": true,
                "initialized": true,
                "createdAt": 1700000002000,
              }
            ]
          }),
        );
        await request.response.close();
      },
    );
    addTearDown(() async => server.close(force: true));

    final connection = _buildConnection(
      id: "1m",
      lastWebviewUrl: "http://127.0.0.1:${server.port}/?mobile=true&token=mobile-token&sessionId=abc",
    );

    final result = await ScheduleService.instance.fetchTerminalSessions(connection);

    expect(result.errorMessage, isNull);
    expect(result.sessions, hasLength(1));
    expect(receivedMobileFlag, "true");
    expect(receivedToken, "mobile-token");
  });

  test("fetchTerminalSessions falls back to wsUrl when webviewUrl is missing", () async {
    final server = await _startTerminalSessionsServer(
      handler: (request) async {
        if (request.uri.path != "/api/terminal-sessions") {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            "sessions": [
              {
                "sessionId": "beta",
                "running": false,
                "initialized": true,
                "createdAt": 1700000001000,
              }
            ]
          }),
        );
        await request.response.close();
      },
    );
    addTearDown(() async => server.close(force: true));

    final connection = _buildConnection(
      id: "2",
      lastWsUrl: "ws://127.0.0.1:${server.port}/ws/terminal?token=ws-token",
    );

    final result = await ScheduleService.instance.fetchTerminalSessions(connection);

    expect(result.errorMessage, isNull);
    expect(result.sessions, hasLength(1));
    expect(result.sessions.first.sessionId, "beta");
  });

  test("fetchTerminalSessions reports non-JSON responses", () async {
    final server = await _startTerminalSessionsServer(
      handler: (request) async {
        request.response.headers.contentType = ContentType.html;
        request.response.write("<html><body>not json</body></html>");
        await request.response.close();
      },
    );
    addTearDown(() async => server.close(force: true));

    final connection = _buildConnection(
      id: "3",
      lastWebviewUrl: "http://127.0.0.1:${server.port}/?token=bad",
    );

    final result = await ScheduleService.instance.fetchTerminalSessions(connection);

    expect(result.sessions, isEmpty);
    expect(result.errorMessage, isNotNull);
  });

  test("fetchTerminalSessions uses hub domain with hub token in hub mode", () async {
    String? receivedToken;
    final server = await _startTerminalSessionsServer(
      handler: (request) async {
        if (request.uri.path != "/api/terminal-sessions") {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        receivedToken = request.uri.queryParameters["token"];
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            "sessions": [
              {
                "sessionId": "hub-1",
                "running": true,
                "initialized": true,
                "createdAt": 1700000003000,
              }
            ]
          }),
        );
        await request.response.close();
      },
    );
    addTearDown(() async => server.close(force: true));

    final connection = _buildConnection(
      id: "hub",
      mode: "hub",
      hubDomain: "http://127.0.0.1:${server.port}",
      hubClientToken: "hub-token",
    );

    final result = await ScheduleService.instance.fetchTerminalSessions(connection);

    expect(result.errorMessage, isNull);
    expect(result.sessions, hasLength(1));
    expect(result.sessions.first.sessionId, "hub-1");
    expect(receivedToken, "hub-token");
  });

  test("runTaskNow uses hub relay websocket for hub mode", () async {
    final receivedMessage = Completer<Map<String, dynamic>>();
    final server = await _startHubRelayServer(
      handler: (socket, request) async {
        socket.listen((data) {
          final decoded = jsonDecode(data.toString());
          if (decoded is! Map) return;
          final message = decoded.cast<String, dynamic>();
          if (message["type"]?.toString() != "send_message") return;
          if (!receivedMessage.isCompleted) {
            receivedMessage.complete(message);
          }
          socket.add(
            jsonEncode(
              <String, dynamic>{
                "type": "send_message_result",
                "requestId": message["requestId"],
                "ok": true,
              },
            ),
          );
        });
      },
    );
    addTearDown(() async => server.close(force: true));

    final connection = _buildConnection(
      id: "hub",
      mode: "hub",
      hubDomain: "http://127.0.0.1:${server.port}",
      hubClientToken: "hub-token",
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("saved_connections", jsonEncode([connection.toJson()]));

    final task = ScheduledTask(
      id: "task-hub",
      name: "hub task",
      command: "qwen",
      connectionId: connection.id,
      sessionId: "terminal-42",
      scheduleKind: TaskScheduleKind.once,
      enabled: false,
      createdAt: DateTime.now(),
      scheduledTime: null,
    );

    await ScheduleService.instance.saveTask(task);
    await ScheduleService.instance.runTaskNow(task);

    final message = await receivedMessage.future.timeout(const Duration(seconds: 4));
    expect(message["sessionId"], "terminal-42");
    expect(message["text"], "qwen");
    expect(message["requestId"], isNotNull);
  });
}
