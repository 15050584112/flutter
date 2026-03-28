import "dart:convert";

enum TaskScheduleKind {
  once,
  interval,
}

enum IntervalUnit {
  minutes,
  hours,
  days,
}

class ScheduledTask {
  ScheduledTask({
    required this.id,
    required this.name,
    required this.command,
    required this.connectionId,
    required this.sessionId,
    required this.scheduleKind,
    required this.enabled,
    required this.createdAt,
    this.scheduledTime,
    this.intervalValue,
    this.intervalUnit,
    this.lastRunAt,
    this.nextRunAt,
    this.lastError,
  });

  final String id;
  final String name;
  final String command;
  final String connectionId;
  final String sessionId;
  final TaskScheduleKind scheduleKind;
  final bool enabled;
  final DateTime createdAt;
  final DateTime? scheduledTime;
  final int? intervalValue;
  final IntervalUnit? intervalUnit;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final String? lastError;

  ScheduledTask copyWith({
    String? id,
    String? name,
    String? command,
    String? connectionId,
    String? sessionId,
    TaskScheduleKind? scheduleKind,
    bool? enabled,
    DateTime? createdAt,
    DateTime? scheduledTime,
    int? intervalValue,
    IntervalUnit? intervalUnit,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
    String? lastError,
  }) {
    return ScheduledTask(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      connectionId: connectionId ?? this.connectionId,
      sessionId: sessionId ?? this.sessionId,
      scheduleKind: scheduleKind ?? this.scheduleKind,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      intervalValue: intervalValue ?? this.intervalValue,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "command": command,
      "connectionId": connectionId,
      "sessionId": sessionId,
      "scheduleKind": scheduleKind.name,
      "enabled": enabled,
      "createdAt": createdAt.toIso8601String(),
      "scheduledTime": scheduledTime?.toIso8601String(),
      "intervalValue": intervalValue,
      "intervalUnit": intervalUnit?.name,
      "lastRunAt": lastRunAt?.toIso8601String(),
      "nextRunAt": nextRunAt?.toIso8601String(),
      "lastError": lastError,
    };
  }

  static ScheduledTask fromJson(Map<String, dynamic> json) {
    return ScheduledTask(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      command: json["command"]?.toString() ?? "",
      connectionId: json["connectionId"]?.toString() ?? "",
      sessionId: json["sessionId"]?.toString() ?? "",
      scheduleKind: _parseScheduleKind(json["scheduleKind"]?.toString()),
      enabled: json["enabled"] == true,
      createdAt: _parseDate(json["createdAt"]) ?? DateTime.now(),
      scheduledTime: _parseDate(json["scheduledTime"]),
      intervalValue: json["intervalValue"] is int ? json["intervalValue"] as int : int.tryParse(json["intervalValue"]?.toString() ?? ""),
      intervalUnit: _parseIntervalUnit(json["intervalUnit"]?.toString()),
      lastRunAt: _parseDate(json["lastRunAt"]),
      nextRunAt: _parseDate(json["nextRunAt"]),
      lastError: json["lastError"]?.toString(),
    );
  }

  static List<ScheduledTask> listFromJson(String raw) {
    if (raw.isEmpty) return <ScheduledTask>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <ScheduledTask>[];
    return decoded
        .whereType<Map>()
        .map((item) => ScheduledTask.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  static String listToJson(List<ScheduledTask> tasks) {
    final jsonList = tasks.map((t) => t.toJson()).toList();
    return jsonEncode(jsonList);
  }

  static TaskScheduleKind _parseScheduleKind(String? raw) {
    switch (raw) {
      case "interval":
        return TaskScheduleKind.interval;
      case "once":
      default:
        return TaskScheduleKind.once;
    }
  }

  static IntervalUnit? _parseIntervalUnit(String? raw) {
    switch (raw) {
      case "minutes":
        return IntervalUnit.minutes;
      case "hours":
        return IntervalUnit.hours;
      case "days":
        return IntervalUnit.days;
      default:
        return null;
    }
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final str = raw.toString();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }
}
