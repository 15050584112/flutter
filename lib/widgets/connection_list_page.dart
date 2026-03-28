import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:ccviewer_mobile_hub/theme/app_theme.dart";
import "package:ccviewer_mobile_hub/models/saved_connection.dart";
import "package:ccviewer_mobile_hub/services/connection_manager.dart";
import "package:ccviewer_mobile_hub/services/qr_payload_parser.dart";
import "package:ccviewer_mobile_hub/widgets/qr_scan_page.dart";
import "package:ccviewer_mobile_hub/main.dart";

enum _HomeMenuAction {
  scan,
  schedule,
  profile,
}

/// IM 风格的连接列表页，作为 App 首页
class ConnectionListPage extends StatefulWidget {
  const ConnectionListPage({
    super.key,
    required this.manager,
  });

  final ConnectionManager manager;

  @override
  State<ConnectionListPage> createState() => _ConnectionListPageState();
}

class _ConnectionListPageState extends State<ConnectionListPage> {
  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onManagerChanged);
    // 加载已保存的连接
    widget.manager.loadConnections();
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleMenuAction(_HomeMenuAction action) {
    switch (action) {
      case _HomeMenuAction.scan:
        _scanAndConnect();
        break;
      case _HomeMenuAction.schedule:
        Navigator.pushNamed(context, "/schedule");
        break;
      case _HomeMenuAction.profile:
        Navigator.pushNamed(context, "/profile");
        break;
    }
  }

  Widget _buildMenuIcon(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
    );
  }

  Future<void> _openMenuSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppDecorations.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Material(
                color: scheme.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primaryContainer.withValues(alpha: 0.45),
                            scheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "快捷入口",
                                style: AppTextStyles.title.copyWith(
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "扫码连接、定时任务与个人设置",
                            style: AppTextStyles.subtitle.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          _buildActionTile(
                            context: sheetContext,
                            icon: Icons.qr_code_scanner_rounded,
                            title: "扫码连接",
                            subtitle: "扫描连接二维码并进入对话",
                            colors: [scheme.primary, scheme.secondary],
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _handleMenuAction(_HomeMenuAction.scan);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionTile(
                            context: sheetContext,
                            icon: Icons.schedule_rounded,
                            title: "定时任务",
                            subtitle: "查看和管理自动化任务",
                            colors: [scheme.tertiary, scheme.primaryContainer],
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _handleMenuAction(_HomeMenuAction.schedule);
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionTile(
                            context: sheetContext,
                            icon: Icons.person_outline_rounded,
                            title: "个人设置",
                            subtitle: "主题、通知与连接偏好",
                            colors: [scheme.secondary, scheme.primary],
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _handleMenuAction(_HomeMenuAction.profile);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.title.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// 扫码连接
  Future<void> _scanAndConnect() async {
    // 导航到扫码页面获取结果
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );

    if (raw == null || raw.isEmpty || !mounted) return;

    try {
      // 解析 QR 码
      final payload = QrPayloadParser.parse(raw);

      // 检查是否过期
      if (payload.isExpired) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("二维码已过期，请重新扫码"),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      // 连接
      await widget.manager.connectTo(payload);

      if (!mounted) return;

      // 导航到聊天页 - 使用新的 ChatRouteArgs
      final connection = widget.manager.activeConnection;
      if (connection != null) {
        final webviewUrl = connection.lastWebviewUrl ?? payload.fullWebviewUrl;
        if (webviewUrl.isNotEmpty) {
          Navigator.pushNamed(
            context,
            "/chat",
            arguments: ChatRouteArgs(
              webviewUrl: webviewUrl,
              projectName: connection.projectName,
              connectionId: connection.id,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("无法获取 WebView URL"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("连接失败: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// 点击连接项
  void _onConnectionTap(SavedConnection connection) {
    // 检查是否有 webviewUrl
    final webviewUrl = connection.lastWebviewUrl;
    if (webviewUrl != null && webviewUrl.isNotEmpty) {
      Navigator.pushNamed(
        context,
        "/chat",
        arguments: ChatRouteArgs(
          webviewUrl: webviewUrl,
          projectName: connection.projectName,
          connectionId: connection.id,
        ),
      );
    } else {
      // 没有 webviewUrl，尝试重新连接
      _reconnectAndNavigate(connection);
    }
  }

  /// 重新连接并导航
  Future<void> _reconnectAndNavigate(SavedConnection connection) async {
    try {
      await widget.manager.reconnect(connection);
      if (!mounted) return;
      
      final updated = widget.manager.activeConnection;
      if (updated != null && updated.lastWebviewUrl != null && updated.lastWebviewUrl!.isNotEmpty) {
        Navigator.pushNamed(
          context,
          "/chat",
          arguments: ChatRouteArgs(
            webviewUrl: updated.lastWebviewUrl!,
            projectName: updated.projectName,
            connectionId: updated.id,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("无法获取 WebView URL，请重新扫码连接"),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("连接失败: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// 删除连接
  Future<void> _deleteConnection(SavedConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("删除连接"),
        content: Text("确定要删除「${connection.alias}」吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("删除"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.manager.deleteConnection(connection.id);
    }
  }

  /// 重命名连接
  Future<void> _renameConnection(SavedConnection connection) async {
    final controller = TextEditingController(text: connection.alias);

    final newAlias = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("重命名"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "别名",
            hintText: "输入新的别名",
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("确定"),
          ),
        ],
      ),
    );

    if (newAlias != null && newAlias.isNotEmpty && newAlias != connection.alias) {
      await widget.manager.updateAlias(connection.id, newAlias);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = widget.manager.connections;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: AnimatedCctvTitle(colorScheme: scheme),
        actions: [
          IconButton(
            onPressed: _openMenuSheet,
            tooltip: "菜单",
            icon: _buildMenuIcon(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.12),
              scheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: connections.isEmpty
            ? _buildEmptyState(context)
            : _buildConnectionList(connections),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _scanAndConnect,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2,
              size: 80,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "扫码添加连接",
              style: AppTextStyles.subtitle.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 连接列表
  Widget _buildConnectionList(List<SavedConnection> connections) {
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xxl,
      ),
      itemCount: connections.length,
      itemBuilder: (context, index) {
        final connection = connections[index];
        return TweenAnimationBuilder<double>(
          key: ValueKey(connection.id),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + index * 50),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: _ConnectionTile(
            connection: connection,
            onTap: () => _onConnectionTap(connection),
            onDelete: () => _deleteConnection(connection),
            onRename: () => _renameConnection(connection),
          ),
        );
      },
    );
  }
}

class AnimatedCctvTitle extends StatefulWidget {
  const AnimatedCctvTitle({
    super.key,
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  State<AnimatedCctvTitle> createState() => _AnimatedCctvTitleState();
}

class _AnimatedCctvTitleState extends State<AnimatedCctvTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final eased = Curves.easeOutCubic.transform(_controller.value);
        final lift = 1.0 - eased;
        final scale = 0.985 + (0.015 * Curves.easeOutBack.transform(eased));

        return Transform.translate(
          offset: Offset(0, 2.5 * lift),
          child: Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        Color.lerp(scheme.primary, scheme.secondary, 0.24) ?? scheme.secondary,
                        scheme.secondary.withValues(alpha: 0.95),
                      ],
                    ).createShader(bounds);
                  },
                  child: child,
                ),
                const SizedBox(height: 3),
                Container(
                  width: 24 + (6 * eased),
                  height: 1.5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary.withValues(alpha: 0.08),
                        scheme.primary.withValues(alpha: 0.72),
                        scheme.secondary.withValues(alpha: 0.88),
                        scheme.primary.withValues(alpha: 0.08),
                      ],
                      stops: const [0.0, 0.22, 0.72, 1.0],
                    ),
                  ),
                ),
              ],
              ),
          ),
        );
      },
      child: Text(
        "CCTV",
        style: GoogleFonts.outfit(
          fontSize: 20.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.55,
          height: 1.0,
          color: scheme.primary,
          shadows: [
            Shadow(
              blurRadius: 1.5,
              color: Colors.white.withValues(alpha: 0.28),
              offset: const Offset(0, 0),
            ),
            Shadow(
              blurRadius: 2.5,
              color: scheme.primary.withValues(alpha: 0.14),
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// 连接列表项
class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.connection,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  final SavedConnection connection;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  /// 根据字符串生成稳定的颜色
  Color _getAvatarColor(String text) {
    final colors = [
      const Color(0xFF5C6BC0), // Indigo
      const Color(0xFF26A69A), // Teal
      const Color(0xFFEF5350), // Red
      const Color(0xFFAB47BC), // Purple
      const Color(0xFF42A5F5), // Blue
      const Color(0xFF66BB6A), // Green
      const Color(0xFFFF7043), // Deep Orange
      const Color(0xFF8D6E63), // Brown
    ];
    final hash = text.hashCode.abs();
    return colors[hash % colors.length];
  }

  /// 获取状态颜色
  Color _getStatusColor(ColorScheme scheme) {
    switch (connection.lastStatus) {
      case "connected":
        return scheme.primary;
      case "error":
        return scheme.error;
      default:
        return scheme.outline;
    }
  }

  /// 格式化相对时间
  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return "刚刚";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes}分钟前";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}小时前";
    } else if (diff.inDays == 1) {
      return "昨天";
    } else if (diff.inDays < 30) {
      return "${diff.inDays}天前";
    } else {
      return "${time.month}月${time.day}日";
    }
  }

  bool _hasMeaningfulText(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.toLowerCase() != "unknown";
  }

  String _deriveHost() {
    final rawUrl = connection.lastWebviewUrl ?? connection.lastWsUrl ?? "";
    final uri = Uri.tryParse(rawUrl);
    return uri?.host ?? "";
  }

  String _displayTitle() {
    if (_hasMeaningfulText(connection.projectName)) return connection.projectName.trim();
    if (connection.workspacePath.trim().isNotEmpty) {
      return connection.workspacePath.trim().split("/").where((part) => part.isNotEmpty).lastOrNull ?? "未命名连接";
    }
    if (_hasMeaningfulText(connection.alias)) return connection.alias.trim();
    final host = _deriveHost();
    if (host.isNotEmpty) return host;
    return "未命名连接";
  }

  String _displaySubtitle(String title) {
    final host = _deriveHost();
    if (host.isNotEmpty) return "IP: $host";

    if (connection.workspacePath.trim().isNotEmpty) {
      return connection.workspacePath.trim();
    }
    if (_hasMeaningfulText(connection.alias) && connection.alias.trim() != title) {
      return connection.alias.trim();
    }
    return connection.isHubMode ? "HUB 连接" : "LAN 连接";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _displayTitle();
    final subtitle = _displaySubtitle(title);
    final initial = title.isNotEmpty ? title[0].toUpperCase() : "?";

    final modeLabel = connection.isHubMode ? "HUB" : "LAN";
    final relativeTime = _formatRelativeTime(connection.lastConnectedAt);

    return Dismissible(
      key: ValueKey(connection.id),
      direction: DismissDirection.endToStart,
        background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // 由 onDelete 处理确认逻辑
      },
      child: GestureDetector(
        onLongPress: onRename,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            boxShadow: AppDecorations.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // 左侧头像
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getAvatarColor(title),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // 中间内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 第一行：别名
                          Text(
                            title,
                            style: AppTextStyles.title.copyWith(color: scheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // 第二行：工作区路径
                          Text(
                            subtitle,
                            style: AppTextStyles.subtitle.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // 第三行：模式 + 相对时间
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: connection.isHubMode
                                      ? scheme.primary.withValues(alpha: 0.15)
                                      : scheme.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  modeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: connection.isHubMode
                                        ? scheme.primary
                                        : scheme.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "· $relativeTime",
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // 右侧状态指示器
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(scheme),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
