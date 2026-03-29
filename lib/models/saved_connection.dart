/// 已保存的连接信息模型
class SavedConnection {
  SavedConnection({
    required this.id,
    required this.alias,
    required this.mode,
    required this.projectName,
    required this.workspacePath,
    this.hubDomain,
    required this.lastConnectedAt,
    required this.lastStatus,
    this.lastWsUrl,
    this.lastConnectionSessionId,
    this.lastWebviewUrl,
    this.lastToken,
    this.hubClientToken,
  });

  /// UUID，唯一标识
  final String id;

  /// 用户自定义别名（默认用 projectName）
  String alias;

  /// 连接模式："lan" | "hub"
  final String mode;

  /// 项目名称
  final String projectName;

  /// 工作区路径
  final String workspacePath;

  /// HUB 域名（仅 hub 模式）
  final String? hubDomain;

  /// 最近连接时间
  DateTime lastConnectedAt;

  /// 上次状态："connected" | "disconnected" | "error"
  String lastStatus;

  /// 上次的 wsUrl（LAN 模式可复连）
  String? lastWsUrl;

  /// 上次的会话 ID
  String? lastConnectionSessionId;

  /// 上次的 WebView URL（完整的移动端页面 URL）
  String? lastWebviewUrl;

  /// 上次的 Token（用于鉴权）
  String? lastToken;

  /// HUB 模式客户端 Token（用于 hub 鉴权）
  String? hubClientToken;

  /// 是否为 HUB 模式
  bool get isHubMode => mode == "hub";

  /// 是否为 LAN 模式
  bool get isLanMode => mode == "lan";

  /// 从 JSON 创建实例
  factory SavedConnection.fromJson(Map<String, dynamic> json) {
    return SavedConnection(
      id: json["id"]?.toString() ?? "",
      alias: json["alias"]?.toString() ?? "",
      mode: json["mode"]?.toString() ?? "lan",
      projectName: json["projectName"]?.toString() ?? "",
      workspacePath: json["workspacePath"]?.toString() ?? "",
      hubDomain: json["hubDomain"]?.toString(),
      lastConnectedAt: _parseDateTime(json["lastConnectedAt"]),
      lastStatus: json["lastStatus"]?.toString() ?? "disconnected",
      lastWsUrl: json["lastWsUrl"]?.toString(),
      lastConnectionSessionId: json["lastConnectionSessionId"]?.toString(),
      lastWebviewUrl: json["lastWebviewUrl"]?.toString(),
      lastToken: json["lastToken"]?.toString(),
      hubClientToken: json["hubClientToken"]?.toString(),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "alias": alias,
      "mode": mode,
      "projectName": projectName,
      "workspacePath": workspacePath,
      "hubDomain": hubDomain,
      "lastConnectedAt": lastConnectedAt.toIso8601String(),
      "lastStatus": lastStatus,
      "lastWsUrl": lastWsUrl,
      "lastConnectionSessionId": lastConnectionSessionId,
      "lastWebviewUrl": lastWebviewUrl,
      "lastToken": lastToken,
      "hubClientToken": hubClientToken,
    };
  }

  /// 复制并修改
  SavedConnection copyWith({
    String? id,
    String? alias,
    String? mode,
    String? projectName,
    String? workspacePath,
    String? hubDomain,
    bool clearHubDomain = false,
    DateTime? lastConnectedAt,
    String? lastStatus,
    String? lastWsUrl,
    bool clearLastWsUrl = false,
    String? lastConnectionSessionId,
    bool clearLastConnectionSessionId = false,
    String? lastWebviewUrl,
    bool clearLastWebviewUrl = false,
    String? lastToken,
    bool clearLastToken = false,
    String? hubClientToken,
    bool clearHubClientToken = false,
  }) {
    return SavedConnection(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      mode: mode ?? this.mode,
      projectName: projectName ?? this.projectName,
      workspacePath: workspacePath ?? this.workspacePath,
      hubDomain: clearHubDomain ? null : (hubDomain ?? this.hubDomain),
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastStatus: lastStatus ?? this.lastStatus,
      lastWsUrl: clearLastWsUrl ? null : (lastWsUrl ?? this.lastWsUrl),
      lastConnectionSessionId: clearLastConnectionSessionId
          ? null
          : (lastConnectionSessionId ?? this.lastConnectionSessionId),
      lastWebviewUrl: clearLastWebviewUrl ? null : (lastWebviewUrl ?? this.lastWebviewUrl),
      lastToken: clearLastToken ? null : (lastToken ?? this.lastToken),
      hubClientToken: clearHubClientToken ? null : (hubClientToken ?? this.hubClientToken),
    );
  }

  /// 解析日期时间
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  /// 生成新的连接 ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  String toString() {
    return "SavedConnection(id: $id, alias: $alias, mode: $mode, projectName: $projectName)";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedConnection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
