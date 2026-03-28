import "package:flutter/material.dart";
import "package:ccviewer_mobile_hub/models/theme_preferences.dart";
import "package:ccviewer_mobile_hub/services/theme_preferences_service.dart";
import "package:ccviewer_mobile_hub/theme/app_theme.dart";

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final ThemePreferencesService _service = ThemePreferencesService.instance;
  ThemePreferences? _prefs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _service.loadPreferences();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  Future<void> _updatePreferences(ThemePreferences next) async {
    setState(() {
      _prefs = next;
    });
    await _service.savePreferences(next);
  }

  AppThemeAccent _resolveAccent(ThemePreferences prefs) {
    return AppTheme.accents.firstWhere(
      (entry) => entry.color.value == prefs.accentColor,
      orElse: () => AppTheme.accents.first,
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, ThemePreferences prefs) {
    final accent = _resolveAccent(prefs);
    final brightness = Theme.of(context).brightness;
    final modeLabel = switch (prefs.mode) {
      AppThemeMode.light => "浅色模式",
      AppThemeMode.dark => "深色模式",
      AppThemeMode.system => "跟随系统",
    };
    final modeDescription = switch (prefs.mode) {
      AppThemeMode.light => "适合明亮环境，界面更轻快。",
      AppThemeMode.dark => "适合夜间使用，降低视觉负担。",
      AppThemeMode.system => "根据系统设置自动切换。",
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: brightness == Brightness.dark
              ? [
                  const Color(0xFF121922),
                  const Color(0xFF0E141C),
                ]
              : [
                  accent.gradient.first.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.92),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : accent.gradient.first.withValues(alpha: 0.14),
        ),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 560;
          final preview = Container(
            width: wide ? 190 : double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : accent.color.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: accent.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.palette_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 14),
                Text(
                  "当前色调",
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  accent.label,
                  style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  modeLabel,
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );

          final body = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "个性设置",
                  style: AppTextStyles.headline.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "调整外观模式和主题色调，让整个应用更接近你的使用习惯。",
                  style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildHeroChip(
                      icon: Icons.brightness_6_rounded,
                      label: modeLabel,
                      color: accent.color,
                    ),
                    _buildHeroChip(
                      icon: Icons.brush_rounded,
                      label: accent.label,
                      color: accent.gradient.last,
                    ),
                    _buildHeroChip(
                      icon: Icons.devices_rounded,
                      label: "即时生效",
                      color: AppColors.online,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  modeDescription,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                body,
                const SizedBox(width: 16),
                preview,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              body,
              const SizedBox(height: 16),
              preview,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSurfaceCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.subtitle.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required BuildContext context,
    required ThemePreferences prefs,
    required AppThemeMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    final selected = prefs.mode == mode;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _updatePreferences(prefs.copyWith(mode: mode)),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.08)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? accentColor : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: selected
                      ? [accentColor, Color.lerp(accentColor, Colors.white, 0.25) ?? accentColor]
                      : [scheme.primaryContainer, scheme.secondaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: selected ? Colors.white : scheme.primary, size: 22),
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
                          title,
                          style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle_rounded, size: 18, color: accentColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentOption(BuildContext context, AppThemeAccent accent, ThemePreferences prefs) {
    final selected = accent.color.value == prefs.accentColor;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _updatePreferences(prefs.copyWith(accentColor: accent.color.value)),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.gradient.first.withValues(alpha: 0.08) : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? accent.color : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: accent.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                      : null,
                ),
                const Spacer(),
                if (selected)
                  Icon(Icons.star_rounded, size: 16, color: accent.color),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              accent.label,
              style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              "强调色",
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, ThemePreferences prefs) {
    final accent = _resolveAccent(prefs);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            accent.gradient.first.withValues(alpha: 0.12),
            scheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: accent.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.palette_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "界面预览",
                  style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  "当前色调：${accent.label}",
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accent.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.widgets_rounded, color: accent.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "按钮、卡片、输入框",
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "都会跟着主题更新",
                              style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _prefs == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final prefs = _prefs!;
    final accent = _resolveAccent(prefs);

    return Scaffold(
      appBar: AppBar(
        title: Text("个人设置", style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.gradient.first.withValues(alpha: 0.08),
              AppColors.background,
              const Color(0xFFFDFDFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                sliver: SliverToBoxAdapter(
                  child: _buildHeroSection(context, prefs),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _buildPreviewCard(context, prefs),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            "外观模式",
                            "决定整个界面的明暗与层次感。",
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth > 620;
                              final tiles = [
                                _buildModeOption(
                                  context: context,
                                  prefs: prefs,
                                  mode: AppThemeMode.system,
                                  icon: Icons.auto_awesome_rounded,
                                  title: "跟随系统",
                                  subtitle: "自动适配浅色或深色设置。",
                                  accentColor: accent.color,
                                ),
                                _buildModeOption(
                                  context: context,
                                  prefs: prefs,
                                  mode: AppThemeMode.light,
                                  icon: Icons.wb_sunny_outlined,
                                  title: "浅色模式",
                                  subtitle: "界面更明亮，适合白天使用。",
                                  accentColor: accent.color,
                                ),
                                _buildModeOption(
                                  context: context,
                                  prefs: prefs,
                                  mode: AppThemeMode.dark,
                                  icon: Icons.nightlight_round,
                                  title: "深色模式",
                                  subtitle: "降低亮度，适合夜间使用。",
                                  accentColor: accent.color,
                                ),
                              ];

                              if (wide) {
                                return Row(
                                  children: [
                                    Expanded(child: tiles[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: tiles[1]),
                                    const SizedBox(width: 12),
                                    Expanded(child: tiles[2]),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  tiles[0],
                                  const SizedBox(height: 12),
                                  tiles[1],
                                  const SizedBox(height: 12),
                                  tiles[2],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            "主题色调",
                            "选择一个主色，按钮、标题和高亮会跟着变化。",
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth > 760
                                  ? 4
                                  : constraints.maxWidth > 520
                                      ? 3
                                      : 2;
                              final tileWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final entry in AppTheme.accents)
                                    SizedBox(
                                      width: tileWidth,
                                      child: _buildAccentOption(context, entry, prefs),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.76),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tips_and_updates_rounded, color: accent.color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "提示：这些设置是全局保存的。主题模式会切换 Material 组件风格，色调会影响强调色和预览样式；如果某个页面仍然使用了固定颜色，后续可以继续把它改成跟随主题。",
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
