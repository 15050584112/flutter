import "dart:io";

import "package:flutter/services.dart";

class LocalNetworkAccessResult {
  const LocalNetworkAccessResult({
    required this.granted,
    this.message,
  });

  final bool granted;
  final String? message;
}

class LocalNetworkAccess {
  static const MethodChannel _channel = MethodChannel("ccviewer/local_network");

  static Future<LocalNetworkAccessResult> request() async {
    if (!Platform.isIOS) {
      return const LocalNetworkAccessResult(granted: true);
    }

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>("requestAccess");
      final granted = response?["granted"] == true;
      final message = response?["message"]?.toString();
      return LocalNetworkAccessResult(
        granted: granted,
        message: message == null || message.isEmpty ? null : message,
      );
    } on PlatformException catch (error) {
      return LocalNetworkAccessResult(
        granted: false,
        message: error.message,
      );
    }
  }
}
