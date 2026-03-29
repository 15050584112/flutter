import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:ccviewer_mobile_hub/models/theme_preferences.dart';
import 'package:ccviewer_mobile_hub/theme/app_theme.dart';
import 'package:ccviewer_mobile_hub/services/connection_manager.dart';
import 'package:ccviewer_mobile_hub/services/storage_service.dart';
import 'package:ccviewer_mobile_hub/services/theme_preferences_service.dart';
import 'package:ccviewer_mobile_hub/widgets/connection_list_page.dart';
import 'package:ccviewer_mobile_hub/widgets/chat_page.dart';
import 'package:ccviewer_mobile_hub/widgets/profile_settings_page.dart';
import 'package:ccviewer_mobile_hub/widgets/schedule_page.dart';
import 'package:ccviewer_mobile_hub/widgets/qr_scan_page.dart';

/// ChatPage 路由参数
class ChatRouteArgs {
  final String webviewUrl;
  final String? projectName;
  final String? connectionId;

  const ChatRouteArgs({
    required this.webviewUrl,
    this.projectName,
    this.connectionId,
  });
}

class HubRouteArgs {
  final String connectionId;

  const HubRouteArgs({
    required this.connectionId,
  });
}

Future<void> main() async {
  // 必须在 runApp 之前初始化，否则插件可能无法正常工作
  WidgetsFlutterBinding.ensureInitialized();

  // Android WebView 调试模式（可选，方便开发）
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const CcViewerMobileApp());
}

class CcViewerMobileApp extends StatefulWidget {
  const CcViewerMobileApp({super.key});

  @override
  State<CcViewerMobileApp> createState() => _CcViewerMobileAppState();
}

class _CcViewerMobileAppState extends State<CcViewerMobileApp> {
  late final ConnectionManager _manager;
  late final ThemePreferencesService _themeService;
  ThemePreferences _themePreferences = const ThemePreferences();

  @override
  void initState() {
    super.initState();
    _manager = ConnectionManager(
      storage: StorageService(),
    );
    _themeService = ThemePreferencesService.instance;
    _themeService.addListener(_onThemePreferencesChanged);
    _loadThemePreferences();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemePreferencesChanged);
    _manager.dispose();
    super.dispose();
  }

  Future<void> _loadThemePreferences() async {
    final prefs = await _themeService.loadPreferences();
    if (!mounted) return;
    setState(() {
      _themePreferences = prefs;
    });
  }

  void _onThemePreferencesChanged() {
    _loadThemePreferences();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accents.firstWhere(
      (item) => item.color.value == _themePreferences.accentColor,
      orElse: () => AppTheme.accents.first,
    );

    return MaterialApp(
      title: 'CCTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themed(
        seed: accent.color,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.themed(
        seed: accent.color,
        brightness: Brightness.dark,
      ),
      themeMode: _themePreferences.toThemeMode(),
      // 首页是连接列表
      home: ConnectionListPage(manager: _manager),
      // 命名路由
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/chat':
            // arguments 是 ChatRouteArgs
            final args = settings.arguments as ChatRouteArgs?;
            if (args == null) {
              // 没有参数，返回连接列表页
              return MaterialPageRoute(
                builder: (_) => ConnectionListPage(manager: _manager),
              );
            }
            return MaterialPageRoute(
              builder: (_) => ChatPage(
                webviewUrl: args.webviewUrl,
                projectName: args.projectName,
                connectionId: args.connectionId,
                manager: _manager,
              ),
            );
          case '/scan':
            return MaterialPageRoute(
              builder: (_) => const QrScanPage(),
            );
          case '/schedule':
            return MaterialPageRoute(
              builder: (_) => const SchedulePage(),
            );
          case '/hub':
            final args = settings.arguments as HubRouteArgs?;
            if (args == null) {
              return MaterialPageRoute(
                builder: (_) => ConnectionListPage(manager: _manager),
              );
            }
            // Hub 模式也走 WebView，加载 Hub 服务器的前端界面
            // 与 LAN mobile page 保持一致的体验
            final connection = _manager.getConnectionById(args.connectionId);
            final hubWebviewUrl = (connection?.lastWebviewUrl ?? "").trim();
            if (connection != null && hubWebviewUrl.isNotEmpty) {
              return MaterialPageRoute(
                builder: (_) => ChatPage(
                  webviewUrl: hubWebviewUrl,
                  projectName: connection.projectName,
                  connectionId: connection.id,
                  manager: _manager,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Hub')),
                body: const Center(child: Text('WebView URL 未就绪，请重新扫码')),
              ),
            );
          case '/profile':
            return MaterialPageRoute(
              builder: (_) => const ProfileSettingsPage(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => ConnectionListPage(manager: _manager),
            );
        }
      },
    );
  }
}
