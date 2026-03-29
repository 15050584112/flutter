class ConnectPayload {
  const ConnectPayload({
    required this.mode,
    required this.connectionSessionId,
    required this.viewerUrl,
    required this.expiresAtMs,
    this.hubDomain,
    this.pairingCode,
    this.projectName,
    this.workspacePath,
    this.webviewUrl,
    this.token,
  });

  final String mode;
  final String connectionSessionId;
  final String viewerUrl;
  final int expiresAtMs;
  final String? hubDomain;
  final String? pairingCode;
  // 这些字段在新 payload 中移除，连接后从 chat_snapshot 获取
  final String? projectName;
  final String? workspacePath;
  // WebView URL（完整的移动端页面 URL）
  final String? webviewUrl;
  // Token（用于移动端鉴权）
  final String? token;

  bool get isHubMode => mode == "hub";
  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAtMs;

  /// 构建完整的 WebView URL
  /// 如果 payload 中有 webviewUrl 则直接使用，否则根据 viewerUrl 构建
  String get fullWebviewUrl {
    // 如果有直接的 webviewUrl，优先使用
    if (webviewUrl != null && webviewUrl!.isNotEmpty) {
      return webviewUrl!;
    }
    // 否则根据 viewerUrl 构建
    if (viewerUrl.isEmpty) return "";
    final uri = Uri.tryParse(viewerUrl);
    if (uri == null) return "";
    // 构建带参数的 URL: {viewerUrl}/?mobile=true&token={token}&sessionId={sessionId}
    final params = <String, String>{
      "mobile": "true",
    };
    if (token != null && token!.isNotEmpty) {
      params["token"] = token!;
    }
    if (connectionSessionId.isNotEmpty) {
      params["sessionId"] = connectionSessionId;
    }
    final newUri = uri.replace(queryParameters: params);
    return newUri.toString();
  }

  /// 从 hubDomain 推导 hubHostWsUrl
  String? get hubHostWsUrl {
    final hd = hubDomain?.trim();
    if (hd == null || hd.isEmpty) return null;
    return deriveHubHostWsUrl(hd);
  }

  /// 从 hubDomain 推导 pairingApiUrl
  String? get pairingApiUrl {
    final hd = hubDomain?.trim();
    if (hd == null || hd.isEmpty) return null;
    return derivePairingApiUrl(hd);
  }

  factory ConnectPayload.fromJson(Map<String, dynamic> json) {
    // 支持新精简字段名和旧字段名的映射
    // 新: v, m, sid, pc, url, exp, hd
    // 旧: version, mode, connectionSessionId, pairingCode, viewerUrl/wsUrl, expiresAt, hubDomain
    
    final mode = (json["m"] ?? json["mode"] ?? "lan").toString();
    final connectionSessionId = (json["sid"] ?? json["connectionSessionId"] ?? "").toString();
    final pairingCode = _asNullableString(json["pc"] ?? json["pairingCode"]);
    final hubDomain = _asNullableString(json["hd"] ?? json["hubDomain"]);
    
    // viewerUrl: 新字段 url，旧字段 viewerUrl，或从 wsUrl 反推
    String viewerUrl = (json["url"] ?? json["viewerUrl"] ?? "").toString();
    if (viewerUrl.isEmpty) {
      // 如果没有 viewerUrl，尝试从旧的 wsUrl 字段反推
      final oldWsUrl = (json["wsUrl"] ?? "").toString();
      if (oldWsUrl.isNotEmpty) {
        viewerUrl = _deriveViewerUrlFromWsUrl(oldWsUrl);
      }
    }
    
    // expiresAt: 新字段 exp，旧字段 expiresAt
    final expiresAtMs = _asEpochMs(json["exp"] ?? json["expiresAt"]);
    
    // 这些字段在新 payload 中移除，但仍支持旧格式
    final projectName = _asNullableString(json["projectName"]);
    final workspacePath = _asNullableString(json["workspacePath"]);
    
    // 新增字段：webviewUrl 和 token
    // wvu 是精简字段名（QR码用），webviewUrl 是完整字段名
    final webviewUrl = _asNullableString(json["wvu"] ?? json["webviewUrl"]);
    // token 可能在单独字段中，也可能嵌在 webviewUrl 中
    String? tokenValue = _asNullableString(json["token"] ?? json["tk"]);
    // 如果没有独立的 token 字段，尝试从 webviewUrl 中提取
    if (tokenValue == null && webviewUrl != null) {
      final wvUri = Uri.tryParse(webviewUrl);
      if (wvUri != null) {
        tokenValue = wvUri.queryParameters["token"];
      }
    }
    
    return ConnectPayload(
      mode: mode,
      connectionSessionId: connectionSessionId,
      viewerUrl: viewerUrl,
      expiresAtMs: expiresAtMs,
      hubDomain: hubDomain,
      pairingCode: pairingCode,
      projectName: projectName,
      workspacePath: workspacePath,
      webviewUrl: webviewUrl,
      token: tokenValue,
    );
  }

  static int _asEpochMs(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final n = int.tryParse(value);
      if (n != null) return n;
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return 0;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// 从 wsUrl 反推 viewerUrl（兼容旧格式）
  static String _deriveViewerUrlFromWsUrl(String wsUrl) {
    final uri = Uri.tryParse(wsUrl);
    if (uri == null) return "";
    final httpScheme = uri.scheme == "wss" ? "https" : "http";
    final port = uri.hasPort ? ":${uri.port}" : "";
    return "$httpScheme://${uri.host}$port";
  }

  /// 从 hubDomain 推导 hubHostWsUrl
  static String deriveHubHostWsUrl(String hubDomain) {
    final trimmed = hubDomain.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.isNotEmpty) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'http') return 'ws://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/ws/mobile/client';
      if (scheme == 'https') return 'wss://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/ws/mobile/client';
    }
    final domain = trimmed.replaceFirst(RegExp(r'^https?://'), '');
    final isLocal = _isLocalLikeHost(domain);
    final scheme = isLocal ? 'ws' : 'wss';
    return '$scheme://$domain/ws/mobile/client';
  }

  /// 从 hubDomain 推导 pairingApiUrl
  static String derivePairingApiUrl(String hubDomain) {
    final trimmed = hubDomain.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.host.isNotEmpty) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        return '${scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/api/mobile/pairings/consume';
      }
    }
    final domain = trimmed.replaceFirst(RegExp(r'^https?://'), '');
    final isLocal = _isLocalLikeHost(domain);
    final scheme = isLocal ? 'http' : 'https';
    return '$scheme://$domain/api/mobile/pairings/consume';
  }

  static bool _isLocalLikeHost(String host) {
    final lower = host.toLowerCase();
    if (lower.contains('localhost') || lower.contains('127.0.0.1')) return true;
    if (lower.endsWith('.local')) return true;
    final cleanHost = lower.split('/').first.split(':').first;
    final parts = cleanHost.split('.');
    if (parts.length != 4) return false;
    final nums = parts.map((p) => int.tryParse(p)).toList();
    if (nums.any((n) => n == null || n < 0 || n > 255)) return false;
    final a = nums[0]!;
    final b = nums[1]!;
    if (a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    return false;
  }
}
