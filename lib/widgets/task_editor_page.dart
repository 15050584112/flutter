import "dart:math";

import "package:flutter/material.dart";

import "package:ccviewer_mobile_hub/models/saved_connection.dart";
import "package:ccviewer_mobile_hub/models/scheduled_task.dart";
import "package:ccviewer_mobile_hub/services/schedule_service.dart";
import "package:ccviewer_mobile_hub/theme/app_theme.dart";

const String _defaultTerminalSessionId = "default";

class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    super.key,
    this.task,
  });

  final ScheduledTask? task;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  final ScheduleService _service = ScheduleService.instance;
  final Map<String, List<TerminalSessionInfo>> _sessionCache = {};
  final Map<String, bool> _sessionLoading = {};
  final Map<String, String?> _sessionErrors = {};
  final _formKey = GlobalKey<FormState>();

  List<SavedConnection> _connections = <SavedConnection>[];
  bool _loading = true;

  late final TextEditingController _nameController;
  late final TextEditingController _commandController;
  late final TextEditingController _intervalController;

  SavedConnection? _selectedConnection;
  String? _selectedSessionId;
  TaskScheduleKind _scheduleKind = TaskScheduleKind.once;
  DateTime? _scheduledTime;
  int _intervalValue = 15;
  IntervalUnit _intervalUnit = IntervalUnit.minutes;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _nameController = TextEditingController(text: task?.name ?? "");
    _commandController = TextEditingController(text: task?.command ?? "");
    _intervalController = TextEditingController(text: (task?.intervalValue ?? 15).toString());
    _scheduleKind = task?.scheduleKind ?? TaskScheduleKind.once;
    _scheduledTime = task?.scheduledTime;
    _intervalValue = task?.intervalValue ?? 15;
    _intervalUnit = task?.intervalUnit ?? IntervalUnit.minutes;
    _enabled = task?.enabled ?? true;

    _bootstrap();
  }

  @override
  void dispose() {
    _service.removeListener(_handleServiceUpdate);
    _nameController.dispose();
    _commandController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  void _handleServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    _service.addListener(_handleServiceUpdate);
    await _service.load();
    _connections = await _service.loadConnections();

    if (widget.task != null) {
      _selectedConnection = _findConnectionById(widget.task!.connectionId);
      _selectedSessionId = widget.task!.sessionId;
    }
    if (_selectedConnection == null && _connections.isNotEmpty) {
      _selectedConnection = _connections.first;
    }
    if (_selectedConnection != null) {
      await _refreshSessions(_selectedConnection!);
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refreshSessions(SavedConnection connection) async {
    _sessionLoading[connection.id] = true;
    _sessionErrors.remove(connection.id);
    if (mounted) setState(() {});
    final result = await _service.fetchTerminalSessions(connection);
    _sessionCache[connection.id] = result.sessions;
    _sessionErrors[connection.id] = result.errorMessage;
    _sessionLoading[connection.id] = false;
    if (mounted) setState(() {});
  }

  List<TerminalSessionInfo> _visibleSessions(List<TerminalSessionInfo> sessions) {
    return sessions
        .where((session) => session.sessionId.trim() != _defaultTerminalSessionId)
        .toList();
  }

  String _formatDateTime(DateTime value) {
    final local = value;
    final mm = local.month.toString().padLeft(2, "0");
    final dd = local.day.toString().padLeft(2, "0");
    final hh = local.hour.toString().padLeft(2, "0");
    final min = local.minute.toString().padLeft(2, "0");
    return "${local.year}-$mm-$dd $hh:$min";
  }

  String _connectionLabel(String connectionId) {
    final match = _connections.where((c) => c.id == connectionId).toList();
    if (match.isEmpty) return "未选择连接";
    final c = match.first;
    if (c.projectName.trim().isNotEmpty) return c.projectName.trim();
    if (c.alias.trim().isNotEmpty) return c.alias.trim();
    if (c.workspacePath.trim().isNotEmpty) {
      final parts = c.workspacePath.split("/").where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.last;
    }
    return c.lastWebviewUrl ?? "未知连接";
  }

  String _sessionLabel(TerminalSessionInfo? session, {String? fallbackSessionId}) {
    if (session == null) {
      final value = fallbackSessionId?.trim() ?? "";
      if (value.isEmpty) return "未选择终端";
      final shortId = value.length <= 6 ? value : value.substring(0, 6);
      return "终端 $shortId";
    }
    final command = (session.currentLauncherCommand ?? "").trim();
    if (command.isNotEmpty) {
      return command[0].toUpperCase() + command.substring(1);
    }
    return "Session ${session.shortId}";
  }

  String _sessionSubLabel(TerminalSessionInfo session) {
    final id = session.sessionId.trim();
    if (id.isEmpty) return "";
    return "ID: $id";
  }

  String _taskScheduleLabel() {
    if (_scheduleKind == TaskScheduleKind.once) {
      if (_scheduledTime == null) return "固定时间";
      return "固定时间 · ${_formatDateTime(_scheduledTime!)}";
    }
    final unitLabel = switch (_intervalUnit) {
      IntervalUnit.hours => "小时",
      IntervalUnit.days => "天",
      IntervalUnit.minutes => "分钟",
    };
    return "循环 · 每 $_intervalValue $unitLabel";
  }

  TerminalSessionInfo? get _resolvedSession {
    if (_selectedConnection == null || _selectedSessionId == null) return null;
    try {
      return _visibleSessions(_sessionCache[_selectedConnection!.id] ?? <TerminalSessionInfo>[])
          .firstWhere((s) => s.sessionId == _selectedSessionId);
    } catch (_) {
      return null;
    }
  }

  SavedConnection? _findConnectionById(String id) {
    try {
      return _connections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTask() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final command = _commandController.text.trim();
    final resolvedSession = _resolvedSession;

    if (name.isEmpty || command.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请填写任务名称和命令")),
      );
      return;
    }
    if (_selectedConnection == null || resolvedSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请选择连接和终端")),
      );
      return;
    }
    if (_scheduleKind == TaskScheduleKind.once && _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请选择固定时间")),
      );
      return;
    }
    if (_scheduleKind == TaskScheduleKind.interval && _intervalValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("请输入有效的间隔数值")),
      );
      return;
    }

    final task = widget.task;
    final taskId = task?.id ?? _newId();
    final createdAt = task?.createdAt ?? DateTime.now();
    final next = ScheduledTask(
      id: taskId,
      name: name,
      command: command,
      connectionId: _selectedConnection!.id,
      sessionId: resolvedSession.sessionId,
      scheduleKind: _scheduleKind,
      enabled: _enabled,
      createdAt: createdAt,
      scheduledTime: _scheduleKind == TaskScheduleKind.once ? _scheduledTime : null,
      intervalValue: _scheduleKind == TaskScheduleKind.interval ? _intervalValue : null,
      intervalUnit: _scheduleKind == TaskScheduleKind.interval ? _intervalUnit : null,
      lastRunAt: task?.lastRunAt,
      nextRunAt: task?.nextRunAt,
      lastError: null,
    );

    await _service.saveTask(next);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  String _newId() {
    final rand = Random().nextInt(9999).toString().padLeft(4, "0");
    return "task_${DateTime.now().millisecondsSinceEpoch}_$rand";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sessionError = _selectedConnection == null ? null : _sessionErrors[_selectedConnection!.id];
    final isSessionLoading = _selectedConnection == null ? false : (_sessionLoading[_selectedConnection!.id] ?? false);
    final connectionSessions = _selectedConnection == null
        ? <TerminalSessionInfo>[]
        : (_sessionCache[_selectedConnection!.id] ?? <TerminalSessionInfo>[]);
    final visibleSessions = _visibleSessions(connectionSessions);
    final visibleSessionIds = visibleSessions.map((session) => session.sessionId).toSet();
    final selectedVisibleSession = _selectedSessionId != null && visibleSessionIds.contains(_selectedSessionId)
        ? _resolvedSession
        : null;
    final heroConnection = _selectedConnection == null ? "未选择连接" : _connectionLabel(_selectedConnection!.id);
    final heroSession = _sessionLabel(selectedVisibleSession, fallbackSessionId: null);
    final taskTitle = widget.task == null ? "新建任务" : "编辑任务";
    final taskSubtitle = _enabled ? "任务已启用，保存后会立即进入调度。" : "任务当前关闭，保存后不会自动执行。";

    return Scaffold(
      appBar: AppBar(
        title: Text(taskTitle, style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFEFF6FF),
              AppColors.background,
              const Color(0xFFFDFDFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: AppDecorations.cardShadow,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    taskTitle,
                                    style: AppTextStyles.headline.copyWith(color: Colors.white, fontSize: 26),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    taskSubtitle,
                                    style: AppTextStyles.subtitle.copyWith(color: Colors.white.withValues(alpha: 0.92)),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildChip(Icons.cloud_outlined, heroConnection),
                                      _buildChip(Icons.terminal_rounded, heroSession),
                                      _buildChip(
                                        _enabled ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                        _enabled ? "启用中" : "已关闭",
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: "基础信息",
                        subtitle: "填写任务名称和要执行的命令。",
                        trailing: Switch(
                          value: _enabled,
                          onChanged: (value) => setState(() => _enabled = value),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: "任务名称",
                                hintText: "例如：每日检查",
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _commandController,
                              maxLines: 3,
                              textInputAction: TextInputAction.done,
                              scrollPadding: const EdgeInsets.only(bottom: 180),
                              onSubmitted: (_) => FocusScope.of(context).unfocus(),
                              decoration: const InputDecoration(
                                labelText: "执行内容",
                                hintText: "例如：/plan 或其他 CLI 命令",
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: "连接与终端",
                        subtitle: "选择在哪台机器、哪个终端里执行。",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<SavedConnection>(
                              value: _selectedConnection,
                              decoration: const InputDecoration(labelText: "选择连接"),
                              items: _connections
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(_connectionLabel(c.id)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) async {
                                setState(() {
                                  _selectedConnection = value;
                                  _selectedSessionId = null;
                                });
                                if (value != null) {
                                  await _refreshSessions(value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<TerminalSessionInfo>(
                                    value: selectedVisibleSession,
                                    decoration: InputDecoration(
                                      labelText: "选择终端",
                                      hintText: isSessionLoading
                                          ? "正在加载终端列表..."
                                          : sessionError != null && sessionError.trim().isNotEmpty
                                              ? "无法获取终端列表"
                                              : visibleSessions.isEmpty
                                                  ? "当前没有可用终端"
                                                  : "请选择终端",
                                    ),
                                    items: visibleSessions
                                        .map(
                                          (s) => DropdownMenuItem(
                                            value: s,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(_sessionLabel(s)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _sessionSubLabel(s),
                                                  style: AppTextStyles.caption.copyWith(
                                                    color: scheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) => setState(() => _selectedSessionId = value?.sessionId),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: IconButton(
                                    onPressed: _selectedConnection == null || isSessionLoading
                                        ? null
                                        : () => _refreshSessions(_selectedConnection!),
                                    icon: isSessionLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.refresh_rounded),
                                    tooltip: "刷新终端",
                                  ),
                                ),
                              ],
                            ),
                            if (sessionError != null && sessionError.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    sessionError,
                                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
                                  ),
                                ),
                              )
                            else if (!isSessionLoading && visibleSessions.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    "当前连接还没有可用终端。若刚打开桌面端，请先展开一个真实终端后再刷新。",
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        title: "调度方式",
                        subtitle: "选择固定时间执行或循环执行。",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                ChoiceChip(
                                  label: const Text("固定时间"),
                                  selected: _scheduleKind == TaskScheduleKind.once,
                                  onSelected: (_) => setState(() => _scheduleKind = TaskScheduleKind.once),
                                ),
                                ChoiceChip(
                                  label: const Text("循环"),
                                  selected: _scheduleKind == TaskScheduleKind.interval,
                                  onSelected: (_) => setState(() => _scheduleKind = TaskScheduleKind.interval),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_scheduleKind == TaskScheduleKind.once)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: _scheduledTime ?? now,
                                      firstDate: now.subtract(const Duration(days: 1)),
                                      lastDate: now.add(const Duration(days: 365 * 3)),
                                    );
                                    if (pickedDate == null) return;
                                    final pickedTime = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(_scheduledTime ?? now),
                                    );
                                    if (pickedTime == null) return;
                                    setState(() {
                                      _scheduledTime = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.calendar_month_rounded),
                                  label: Text(_scheduledTime == null ? "选择时间" : _formatDateTime(_scheduledTime!)),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _intervalController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      scrollPadding: const EdgeInsets.only(bottom: 180),
                                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                      decoration: const InputDecoration(
                                        labelText: "间隔数值",
                                      ),
                                      onChanged: (value) {
                                        final parsed = int.tryParse(value);
                                        if (parsed != null) _intervalValue = parsed;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<IntervalUnit>(
                                      value: _intervalUnit,
                                      decoration: const InputDecoration(labelText: "单位"),
                                      items: const [
                                        DropdownMenuItem(value: IntervalUnit.minutes, child: Text("分钟")),
                                        DropdownMenuItem(value: IntervalUnit.hours, child: Text("小时")),
                                        DropdownMenuItem(value: IntervalUnit.days, child: Text("天")),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() => _intervalUnit = value);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("取消"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveTask,
                              icon: Icon(widget.task == null ? Icons.add_rounded : Icons.save_rounded),
                              label: Text(widget.task == null ? "创建任务" : "保存任务"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title.copyWith(color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
