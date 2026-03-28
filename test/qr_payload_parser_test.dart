import "package:ccviewer_mobile_hub/models/connect_payload.dart";
import "package:ccviewer_mobile_hub/services/qr_payload_parser.dart";
import "package:flutter_test/flutter_test.dart";
import "dart:convert";

void main() {
  test("parses ccviewer QR payload (old format)", () {
    const raw = "ccviewer://mobile-connect?payload=eyJtb2RlIjoiaHViIiwiY29ubmVjdGlvblNlc3Npb25JZCI6ImFiYyIsInByb2plY3ROYW1lIjoiY2Mtdmlld2VyIiwid29ya3NwYWNlUGF0aCI6Ii90bXAvY2Mtdmlld2VyIiwid3NVcmwiOiJ3czovL2xvY2FsaG9zdDo3MDA4L3dzL21vYmlsZS1jaGF0P3Nlc3Npb25JZD1hYmMiLCJleHBpcmVzQXQiOjQ3MDAwMDAwMDAwMDAsImh1YkRvbWFpbiI6Imh0dHBzOi8vaHViLmV4YW1wbGUuY29tIiwicGFpcmluZ0NvZGUiOiJwYWlyLTEyMyIsInBhaXJpbmdBcGlVcmwiOiJodHRwczovL2h1Yi5leGFtcGxlLmNvbS9hcGkvbW9iaWxlL3BhaXJpbmdzL2NvbnN1bWUifQ";

    final ConnectPayload payload = QrPayloadParser.parse(raw);

    expect(payload.mode, "hub");
    expect(payload.connectionSessionId, "abc");
    expect(payload.projectName, "cc-viewer");
    expect(payload.hubDomain, "https://hub.example.com");
    expect(payload.pairingCode, "pair-123");
    expect(payload.pairingApiUrl, "https://hub.example.com/api/mobile/pairings/consume");
  });

  test("parses ccviewer QR payload (new simplified format)", () {
    // 新精简格式: v, m, sid, pc, url, exp, hd
    final newPayload = {
      "v": 1,
      "m": "hub",
      "sid": "session-456",
      "pc": "pairing-789",
      "url": "https://localhost:7008",
      "exp": 4700000000000,
      "hd": "hub.example.com",
    };
    final encoded = base64Url.encode(utf8.encode(jsonEncode(newPayload)));
    final raw = "ccviewer://mobile-connect?payload=$encoded";

    final ConnectPayload payload = QrPayloadParser.parse(raw);

    expect(payload.mode, "hub");
    expect(payload.connectionSessionId, "session-456");
    expect(payload.pairingCode, "pairing-789");
    expect(payload.viewerUrl, "https://localhost:7008");
    expect(payload.hubDomain, "hub.example.com");
    expect(payload.hubHostWsUrl, "wss://hub.example.com/ws/mobile/client");
    expect(payload.pairingApiUrl, "https://hub.example.com/api/mobile/pairings/consume");
    // 新格式中这些字段为 null
    expect(payload.projectName, isNull);
    expect(payload.workspacePath, isNull);
  });

  test("derives URLs correctly from hubDomain with https prefix", () {
    expect(
      ConnectPayload.deriveHubHostWsUrl("https://hub.example.com"),
      "wss://hub.example.com/ws/mobile/client",
    );
    expect(
      ConnectPayload.derivePairingApiUrl("https://hub.example.com"),
      "https://hub.example.com/api/mobile/pairings/consume",
    );
  });

  test("derives URLs correctly for localhost", () {
    expect(
      ConnectPayload.deriveHubHostWsUrl("localhost:3000"),
      "ws://localhost:3000/ws/mobile/client",
    );
    expect(
      ConnectPayload.derivePairingApiUrl("127.0.0.1:3000"),
      "http://127.0.0.1:3000/api/mobile/pairings/consume",
    );
  });

  test("rejects non ccviewer QR", () {
    expect(
      () => QrPayloadParser.parse("https://example.com"),
      throwsA(isA<FormatException>()),
    );
  });
}
