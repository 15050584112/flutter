import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 应用配色方案
/// 参考 Best-Flutter-UI-Templates 设计风格
class AppColors {
  AppColors._();

  // 主色
  static const Color primary = Color(0xFF005B99);        // 蓝色
  static const Color primaryLight = Color(0xFF4A90D9);   // 浅蓝
  static const Color primaryDark = Color(0xFF003D66);    // 深蓝

  // 背景
  static const Color background = Color(0xFFF7F8FA);     // 浅灰白
  static const Color surface = Color(0xFFFFFFFF);        // 纯白（卡片）
  static const Color surfaceVariant = Color(0xFFF0F2F5); // 浅灰（助手消息气泡）

  // 文本
  static const Color textPrimary = Color(0xFF253840);    // 主文本
  static const Color textSecondary = Color(0xFF4A6572);  // 次文本
  static const Color textHint = Color(0xFF9E9E9E);       // 提示文本

  // 状态
  static const Color online = Color(0xFF4CAF50);         // 在线绿
  static const Color offline = Color(0xFF9E9E9E);        // 离线灰
  static const Color error = Color(0xFFE53935);          // 错误红
  static const Color warning = Color(0xFFFFA726);        // 警告橙

  // 消息气泡
  static const Color userBubble = Color(0xFF005B99);     // 用户消息背景（蓝色）
  static const Color userBubbleText = Color(0xFFFFFFFF); // 用户消息文字（白色）
  static const Color assistantBubble = Color(0xFFFFFFFF);// 助手消息背景（白色）
  static const Color assistantBubbleText = Color(0xFF253840); // 助手消息文字

  // 分割线和边框
  static const Color divider = Color(0xFFE8EAED);
  static const Color border = Color(0xFFDDE1E5);

  // ---- 助手消息容器 ----
  static const Color assistantCardBg = Color(0xFFF8F9FC);
  static const Color assistantCardBorder = Color(0xFFE8EBF0);

  // ---- 代码块（深色终端风格）----
  static const Color codeBlockBg = Color(0xFF1E1E2E);
  static const Color codeBlockText = Color(0xFFCDD6F4);
  static const Color codeBlockHeaderBg = Color(0xFF313244);
  static const Color codeBlockHeaderText = Color(0xFFA6ADC8);
  static const Color codeBlockBorder = Color(0xFF45475A);

  // ---- 语法高亮色 ----
  static const Color syntaxKeyword = Color(0xFFCBA6F7);
  static const Color syntaxString = Color(0xFFA6E3A1);
  static const Color syntaxComment = Color(0xFF6C7086);
  static const Color syntaxNumber = Color(0xFFFAB387);
  static const Color syntaxFunction = Color(0xFF89B4FA);
  static const Color syntaxType = Color(0xFFF9E2AF);
  static const Color syntaxOperator = Color(0xFF94E2D5);
  static const Color syntaxVariable = Color(0xFFF5C2E7);

  // ---- 行内代码 ----
  static const Color inlineCodeBg = Color(0xFFEEF1F8);
  static const Color inlineCodeText = Color(0xFFD20F39);
  static const Color inlineCodeBorder = Color(0xFFDDE1EC);

  // ---- 工具标记 ----
  static const Color toolBadgeBg = Color(0xFFE8F0FE);
  static const Color toolBadgeText = Color(0xFF1A73E8);
  static const Color toolBadgeIcon = Color(0xFF1A73E8);

  // ---- 引用块 ----
  static const Color blockquoteBg = Color(0xFFF0F4F8);
  static const Color blockquoteBorder = Color(0xFF89B4FA);
  static const Color blockquoteText = Color(0xFF585B70);

  // ---- 时间戳 ----
  static const Color timestampText = Color(0xFFA0A7B8);
}

/// 应用主题数据
class AppTheme {
  AppTheme._();

  static ThemeData themed({
    required Color seed,
    required Brightness brightness,
  }) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: seed,
      secondary: brightness == Brightness.dark
          ? Color.lerp(seed, Colors.white, 0.16) ?? seed
          : Color.lerp(seed, Colors.black, 0.08) ?? seed,
      surface: brightness == Brightness.dark
          ? const Color(0xFF11161D)
          : const Color(0xFFF8FAFC),
      surfaceContainerHighest: brightness == Brightness.dark
          ? const Color(0xFF171D26)
          : const Color(0xFFFFFFFF),
      surfaceContainer: brightness == Brightness.dark
          ? const Color(0xFF141A22)
          : const Color(0xFFF3F6FA),
      outline: brightness == Brightness.dark
          ? const Color(0xFF2A3340)
          : AppColors.border,
      onSurface: brightness == Brightness.dark
          ? const Color(0xFFEAF1F8)
          : AppColors.textPrimary,
      onSurfaceVariant: brightness == Brightness.dark
          ? const Color(0xFFB4C0CE)
          : AppColors.textSecondary,
      primaryContainer: brightness == Brightness.dark
          ? const Color(0xFF0F2738)
          : Color.lerp(seed, Colors.white, 0.84) ?? seed,
      onPrimaryContainer: brightness == Brightness.dark
          ? const Color(0xFFD6ECFF)
          : seed,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    return base.copyWith(
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0B0F14)
          : const Color(0xFFF5F7FA),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF0F141B)
            : Colors.transparent,
        foregroundColor: brightness == Brightness.dark
            ? const Color(0xFFE6EEF7)
            : AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headline.copyWith(
          color: brightness == Brightness.dark
              ? const Color(0xFFE6EEF7)
              : AppColors.textPrimary,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: brightness == Brightness.dark
            ? const Color(0xFF141A22)
            : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: AppTextStyles.labelLarge.copyWith(color: scheme.onSurface),
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          textStyle: WidgetStatePropertyAll(AppTextStyles.labelLarge),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.outlineVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primaryContainer;
          return scheme.surfaceContainerHighest;
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.primary),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: base.dividerTheme.copyWith(
        color: brightness == Brightness.dark
            ? const Color(0xFF2A3340)
            : const Color(0xFFE5E9EF),
        thickness: 0.8,
      ),
    );
  }

  static const List<AppThemeAccent> accents = [
    AppThemeAccent(
      id: "cctv_blue",
      label: "CCTV 蓝",
      color: Color(0xFF005B99),
      gradient: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
    ),
    AppThemeAccent(
      id: "forest",
      label: "森林绿",
      color: Color(0xFF1B5E20),
      gradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    ),
    AppThemeAccent(
      id: "sunset",
      label: "落日橙",
      color: Color(0xFFEF6C00),
      gradient: [Color(0xFFFF8A65), Color(0xFFFFB74D)],
    ),
    AppThemeAccent(
      id: "berry",
      label: "莓果红",
      color: Color(0xFFC62828),
      gradient: [Color(0xFFD32F2F), Color(0xFFF06292)],
    ),
    AppThemeAccent(
      id: "slate",
      label: "岩灰",
      color: Color(0xFF546E7A),
      gradient: [Color(0xFF607D8B), Color(0xFF90A4AE)],
    ),
    AppThemeAccent(
      id: "indigo",
      label: "靛蓝",
      color: Color(0xFF3949AB),
      gradient: [Color(0xFF5C6BC0), Color(0xFF8E66FF)],
    ),
  ];

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    
    // AppBar 主题
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    
    // Card 主题
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    
    // 输入框主题
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: AppColors.textHint),
    ),
    
    // FAB 主题
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    
    // 分割线主题
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
      space: 0,
    ),
    
    // 列表瓦片主题
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: AppColors.surface,
    ),
    
    // 底部导航栏主题
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}

class AppThemeAccent {
  const AppThemeAccent({
    required this.id,
    required this.label,
    required this.color,
    required this.gradient,
  });

  final String id;
  final String label;
  final Color color;
  final List<Color> gradient;
}

/// 装饰工具类
class AppDecorations {
  AppDecorations._();

  // 卡片阴影
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      blurRadius: 8,
      offset: const Offset(0, 2),
      color: Colors.black.withValues(alpha: 0.06),
    ),
  ];

  // 用户消息气泡装饰
  static BoxDecoration get userBubble => BoxDecoration(
    color: AppColors.userBubble,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(4),
    ),
  );

  // 助手消息气泡装饰
  static BoxDecoration get assistantBubble => BoxDecoration(
    color: AppColors.assistantBubble,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    ),
    boxShadow: [
      BoxShadow(
        blurRadius: 4,
        offset: const Offset(0, 1),
        color: Colors.black.withValues(alpha: 0.04),
      ),
    ],
  );

  // 圆角卡片装饰
  static BoxDecoration get card => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: cardShadow,
  );

  // 状态指示器装饰
  static BoxDecoration onlineIndicator = const BoxDecoration(
    color: AppColors.online,
    shape: BoxShape.circle,
  );

  static BoxDecoration offlineIndicator = const BoxDecoration(
    color: AppColors.offline,
    shape: BoxShape.circle,
  );
}

/// 文本样式常量
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  static const TextStyle userMessage = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.userBubbleText,
  );

  static const TextStyle assistantMessage = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.assistantBubbleText,
  );

  // 附加样式
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ---- Markdown 字体样式 ----

  static TextStyle get codeBlockTextStyle => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    height: 1.5,
    color: AppColors.codeBlockText,
  );

  static TextStyle get inlineCodeTextStyle => GoogleFonts.jetBrainsMono(
    fontSize: 13.5,
    color: AppColors.inlineCodeText,
  );

  static const TextStyle assistantBodyText = TextStyle(
    fontSize: 15,
    height: 1.6,
    color: Color(0xFF1E293B),
    fontWeight: FontWeight.w400,
  );

  static const TextStyle assistantH1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Color(0xFF0F172A),
    height: 1.4,
  );

  static const TextStyle assistantH2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF1E293B),
    height: 1.4,
  );

  static const TextStyle assistantH3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF334155),
    height: 1.4,
  );

  static const TextStyle timestampStyle = TextStyle(
    fontSize: 11,
    color: AppColors.timestampText,
  );
}

/// 间距常量
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// 圆角常量
class AppRadius {
  AppRadius._();

  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xlarge = 24.0;
  static const double circular = 100.0;
}

/// 尺寸常量
class AppDimensions {
  AppDimensions._();

  // ---- 消息间距 ----
  static const double messageVerticalGap = 12.0;
  static const double messageHorizontalPadding = 12.0;

  // ---- 助手消息卡片 ----
  static const double assistantCardMaxWidthRatio = 0.92;
  static const double assistantCardPaddingH = 14.0;
  static const double assistantCardPaddingV = 12.0;
  static const double assistantCardRadius = 12.0;
  static const double assistantAvatarSize = 28.0;
  static const double assistantAvatarGap = 8.0;

  // ---- 用户消息气泡 ----
  static const double userBubbleMaxWidthRatio = 0.75;
  static const double userBubblePaddingH = 14.0;
  static const double userBubblePaddingV = 10.0;

  // ---- 代码块 ----
  static const double codeBlockRadius = 8.0;
  static const double codeBlockPaddingH = 16.0;
  static const double codeBlockPaddingV = 14.0;
  static const double codeBlockHeaderHeight = 36.0;
  static const double codeBlockMarginV = 8.0;
  static const double codeBlockMaxHeight = 400.0;

  // ---- 工具标记 ----
  static const double toolBadgeHeight = 24.0;
  static const double toolBadgePaddingH = 8.0;
  static const double toolBadgeRadius = 4.0;
  static const double toolBadgeIconSize = 14.0;
  static const double toolBadgeGap = 4.0;
}
