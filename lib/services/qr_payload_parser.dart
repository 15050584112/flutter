import "dart:convert";

import "../models/connect_payload.dart";

class QrPayloadParser {
  static ConnectPayload parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) {
      throw const FormatException("Invalid QR string.");
    }
    if (uri.scheme != "ccviewer" || uri.host != "mobile-connect") {
      throw const FormatException("Not a ccviewer mobile link.");
    }
    final encoded = uri.queryParameters["payload"];
    if (encoded == null || encoded.isEmpty) {
      throw const FormatException("Missing payload.");
    }

    final payloadJson = utf8.decode(base64Url.decode(base64Url.normalize(encoded)));
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException("Payload JSON must be an object.");
    }
    return ConnectPayload.fromJson(decoded);
  }
}
