import "package:flutter/material.dart";

import "package:ccviewer_mobile_hub/models/saved_connection.dart";
import "package:ccviewer_mobile_hub/models/scheduled_task.dart";
import "package:ccviewer_mobile_hub/services/schedule_service.dart";
import "package:ccviewer_mobile_hub/theme/app_theme.dart";
import "package:ccviewer_mobile_hub/widgets/task_editor_page.dart";

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final ScheduleService _service = ScheduleService.instance;
  final Map<String, List<TerminalSessionInfo>> _sessionCache = {};
  final Map<String, bool> _sessionLoading = {};
  final Map<String, String?> _sessionErrors = {};
  List<SavedConnection> _connections = <SavedConnection>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _service.addListener(_handleUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_handleUpdate);
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrap() async {
    await _service.load();
    _connections = await _service.loadConnections();
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value;
    final mm = local.month.toString().padLeft(2, "0");
    final dd = local.day.toString().padLeft(2, "0");
    final hh = local.hour.toString().padLeft(2, "0");
    final min = local.minute.toString().padLeft(2, "0");
    return "${local.year}-$mm-$dd $hh:$min";
  }

  String _taskScheduleLabel(ScheduledTask task) {
    if (task.scheduleKind == TaskScheduleKind.once) {
      if (task.scheduledTime == null) return "固定时间";
      return "固定时间 · ${_formatDateTime(task.scheduledTime!)}";
    }
    final value = task.intervalValue ?? 0;
    final unit = task.intervalUnit ?? IntervalUnit.minutes;
    final unitLabel = switch (unit) {
      IntervalUnit.hours => "小时",
      IntervalUnit.days => "天",
      IntervalUnit.minutes => "分钟",
    };
    return "循环 · 每 $value $unitLabel";
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.title.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.subtitle.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context, List<ScheduledTask> tasks) {
    final scheme = Theme.of(context).colorScheme;
    final enabledCount = tasks.where((task) => task.enabled).length;
    final pendingRuns = tasks
        .where((task) => task.enabled && task.nextRunAt != null)
        .map((task) => task.nextRunAt!)
        .toList()
      ..sort();
    final nextRun = pendingRuns.isEmpty ? null : pendingRuns.first;
    final nextLabel = nextRun == null ? "暂无待执行任务" : _formatDateTime(nextRun);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: scheme.brightness == Brightness.dark ? 0.22 : 0.45),
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "定时任务",
                  style: AppTextStyles.headline.copyWith(
                    color: scheme.onSurface,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "固定时间或循环执行，按连接和终端维度自动触发命令。",
                  style: AppTextStyles.subtitle.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(context, Icons.task_alt_rounded, "${tasks.length} 个任务", scheme.primary),
                    _buildInfoChip(context, Icons.play_circle_outline_rounded, "$enabledCount 个启用", scheme.secondary),
                    _buildInfoChip(context, Icons.access_time_rounded, nextLabel, scheme.tertiary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required List<Color> colors,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.title.copyWith(color: scheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  SavedConnection? _findConnectionById(String id) {
    try {
      return _connections.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  TerminalSessionInfo? _findSession(String connectionId, String sessionId) {
    final list = _sessionCache[connectionId] ?? <TerminalSessionInfo>[];
    try {
      return list.firstWhere((s) => s.sessionId == sessionId);
    } catch (_) {
      return null;
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

  Future<void> _openTaskEditor({ScheduledTask? task}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditorPage(task: task),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tasks = _service.tasks;
    final activeTasks = tasks.where((task) => task.enabled).length;
    final soonestNextRun = tasks
        .where((task) => task.enabled && task.nextRunAt != null)
        .map((task) => task.nextRunAt!)
        .toList()
      ..sort();
    final nextRunLabel = soonestNextRun.isEmpty ? "暂无" : _formatDateTime(soonestNextRun.first);
    final connectionCount = _connections.length;

    return Scaffold(
      appBar: AppBar(
        title: Text("定时任务", style: AppTextStyles.headline.copyWith(color: scheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _connections.isEmpty ? null : () => _openTaskEditor(),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: "新建任务",
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.12),
              scheme.surface,
              scheme.surfaceContainer.withValues(alpha: 0.94),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildHeroCard(context, tasks),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context: context,
                            icon: Icons.devices_rounded,
                            label: "连接数",
                            value: "$connectionCount",
                            colors: [scheme.primary, scheme.secondary],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context: context,
                            icon: Icons.check_circle_outline_rounded,
                            label: "启用中",
                            value: "$activeTasks",
                            colors: [scheme.secondary, scheme.tertiary],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMetricCard(
                      context: context,
                      icon: Icons.access_time_filled_rounded,
                      label: "最近下一次执行",
                      value: nextRunLabel,
                      colors: [scheme.tertiary, scheme.primaryContainer],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                      context,
                      "任务列表",
                      "按卡片方式展示任务状态、连接和终端。",
                    ),
                    const SizedBox(height: 12),
                    if (_connections.isEmpty)
                      _buildEmptyConnection(context)
                    else if (tasks.isEmpty)
                      _buildEmptyState(context)
                    else
                      ...tasks.map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildTaskCard(context, task),
                        ),
                      ),
                  ],
                ),
        ),
      ),
      floatingActionButton: _connections.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openTaskEditor(),
              icon: const Icon(Icons.add),
              backgroundColor: scheme.primary,
              label: const Text("新建任务"),
            ),
    );
  }

  Widget _buildEmptyConnection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.link_off_rounded, size: 28, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            "暂无连接",
            style: AppTextStyles.title.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            "请先扫码连接一台电脑，再创建定时任务",
            style: AppTextStyles.subtitle.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.schedule_rounded, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            "还没有任务",
            style: AppTextStyles.title.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            "添加固定时间或循环任务，让终端自动执行",
            style: AppTextStyles.subtitle.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, ScheduledTask task) {
    final scheme = Theme.of(context).colorScheme;
    final connectionName = _connectionLabel(task.connectionId);
    final sessionInfo = _findSession(task.connectionId, task.sessionId);
    final sessionLabel = _sessionLabel(sessionInfo, fallbackSessionId: task.sessionId);
    final scheduleLabel = _taskScheduleLabel(task);
    final nextRun = task.nextRunAt;
    final nextLabel = nextRun == null ? "未安排" : _formatDateTime(nextRun);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: task.enabled
              ? scheme.outlineVariant
              : scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: task.enabled
                          ? [scheme.primary, scheme.secondary]
                          : [scheme.outline, scheme.surfaceContainerHighest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.name,
                              style: AppTextStyles.title.copyWith(color: scheme.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Switch(
                            value: task.enabled,
                            onChanged: (value) => _service.toggleTask(task.id, value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scheduleLabel,
                        style: AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(context, Icons.cloud_outlined, connectionName, scheme.primary),
                _buildInfoChip(context, Icons.terminal_rounded, sessionLabel, scheme.tertiary),
                _buildInfoChip(context, Icons.access_time_rounded, nextLabel, scheme.secondary),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                task.command,
                style: AppTextStyles.subtitle.copyWith(color: scheme.onSurface, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await _service.runTaskNow(task);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("已触发执行")),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text("立即执行"),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _openTaskEditor(task: task),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("编辑"),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    await _service.deleteTask(task.id);
                  },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: "删除",
                ),
              ],
            ),
            if ((task.lastError ?? "").isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "上次错误: ${task.lastError}",
                    style: AppTextStyles.caption.copyWith(color: scheme.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
