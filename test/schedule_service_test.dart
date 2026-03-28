import "dart:convert";
import "dart:io";

import "package:ccviewer_mobile_hub/models/saved_connection.dart";
import "package:ccviewer_mobile_hub/services/schedule_service.dart";
import "package:flutter_test/flutter_test.dart";

Future<HttpServer> _startTerminalSessionsServer({
  required Future<void> Function(HttpRequest request) handler,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

SavedConnection _buildConnection({
  required String id,
  String? lastWebviewUrl,
  String? lastWsUrl,
  String? lastToken,
}) {
  return SavedConnection(
    id: id,
    alias: "alias",
    mode: "lan",
    projectName: "project",
    workspacePath: "/tmp/project",
    lastConnectedAt: DateTime.now(),
    lastStatus: "connected",
    lastWebviewUrl: lastWebviewUrl,
    lastWsUrl: lastWsUrl,
    lastToken: lastToken,
  );
}

void main() {
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
}
