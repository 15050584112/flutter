import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:ccviewer_mobile_hub/services/connection_manager.dart';
import 'package:ccviewer_mobile_hub/services/local_network_access.dart';

/// 聊天页面 - 使用 WebView 加载 cc-viewer 移动端页面
class ChatPage extends StatefulWidget {
  final String webviewUrl;  // 从连接信息获取的 WebView URL
  final String? projectName;
  final String? connectionId;
  final ConnectionManager? manager;
  
  const ChatPage({
    super.key,
    required this.webviewUrl,
    this.projectName,
    this.connectionId,
    this.manager,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const Duration _webViewLoadTimeout = Duration(seconds: 12);

  InAppWebViewController? _webViewController;
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  bool _isWebViewLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _loadProgress = 0;
  Timer? _loadTimeoutTimer;
  String? _lastUrl;
  bool _bridgeReady = false;
  bool _isPreparingWebView = true;

  /// 安全转义 JS 字符串，防止注入攻击
  String _escapeForJs(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  @override
  void initState() {
    super.initState();
    _lastUrl = widget.webviewUrl;
    _initSpeech();
    _prepareWebView();
  }

  Future<void> _prepareWebView() async {
    if (!Platform.isIOS) {
      await _runWebViewPreflight();
      return;
    }

    final access = await LocalNetworkAccess.request();
    if (!mounted) return;

    if (access.granted) {
      await _runWebViewPreflight();
      return;
    }

    setState(() {
      _isPreparingWebView = false;
      _hasError = true;
      _isWebViewLoading = false;
      _errorMessage =
          '当前 App 没有本地网络权限，无法访问局域网地址。\n'
          '请到 iPhone 设置 > CCTV > 本地网络 开启后重试。\n'
          '${access.message ?? ''}'.trim();
    });
  }

  Future<void> _runWebViewPreflight() async {
    final uri = Uri.tryParse(widget.webviewUrl);
    if (uri == null) {
      if (!mounted) return;
      setState(() {
        _isPreparingWebView = false;
        _hasError = true;
        _isWebViewLoading = false;
        _errorMessage = "WebView URL 无效:\n${widget.webviewUrl}";
      });
      return;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);

    try {
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      final response = await request.close().timeout(const Duration(seconds: 8));
      await response.drain<void>();

      if (!mounted) return;

      if (response.statusCode >= 400) {
        setState(() {
          _isPreparingWebView = false;
          _hasError = true;
          _isWebViewLoading = false;
          _errorMessage = "App 内网络预检失败: HTTP ${response.statusCode}\n$uri";
        });
        return;
      }

      setState(() {
        _isPreparingWebView = false;
        _hasError = false;
        _errorMessage = "";
        _isWebViewLoading = true;
      });
      _startLoadTimeout();
    } on SocketException catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreparingWebView = false;
        _hasError = true;
        _isWebViewLoading = false;
        _errorMessage = "App 内网络预检失败: ${error.message}\n$uri";
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isPreparingWebView = false;
        _hasError = true;
        _isWebViewLoading = false;
        _errorMessage = "App 内网络预检超时:\n$uri";
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isPreparingWebView = false;
        _hasError = true;
        _isWebViewLoading = false;
        _errorMessage = "App 内网络预检异常: $error\n$uri";
      });
    } finally {
      client.close(force: true);
    }
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_webViewLoadTimeout, () {
      if (!mounted || !_isWebViewLoading) return;
      setState(() {
        _hasError = true;
        _errorMessage = '页面加载超时，请检查手机是否能访问该地址:\n${_lastUrl ?? widget.webviewUrl}';
        _isWebViewLoading = false;
      });
    });
  }

  void _finishLoading({bool clearError = true}) {
    if (!mounted) return;
    _loadTimeoutTimer?.cancel();
    setState(() {
      _isWebViewLoading = false;
      _loadProgress = 100;
      if (clearError) {
        _hasError = false;
        _errorMessage = '';
      }
    });
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speechToText.initialize(
      onError: (error) {
        debugPrint('Speech recognition error: ${error.errorMsg}');
        setState(() {
          _isListening = false;
        });
      },
      onStatus: (status) {
        debugPrint('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          _onSpeechDone();
        }
      },
    );
    debugPrint('Speech recognition available: $_speechAvailable');
  }

  void _onSpeechDone() {
    setState(() {
      _isListening = false;
      _recognizedText = '';
    });
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音识别不可用，请检查麦克风权限')),
      );
      return;
    }
    
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });
        // 实时更新 WebView 输入框（使用安全转义）
        if (_webViewController != null && result.recognizedWords.isNotEmpty) {
          final escaped = _escapeForJs(result.recognizedWords);
          _webViewController!.evaluateJavascript(
            source: "window.ccMobileBridge && window.ccMobileBridge.insertText('$escaped')",
          );
        }
      },
      localeId: 'zh_CN', // 默认中文，可以后续改为自适应
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  Map<String, dynamic>? _extractBridgePayload(List<dynamic> args) {
    if (args.isEmpty) return null;
    final first = args.first;
    if (first is Map) {
      return Map<String, dynamic>.from(first.cast<dynamic, dynamic>());
    }
    return null;
  }

  Future<void> _applyChatSnapshot(Map<String, dynamic> payload) async {
    final connectionId = widget.connectionId;
    final manager = widget.manager;
    if (connectionId == null || manager == null) return;

    final projectName = payload["projectName"]?.toString();
    final workspacePath = payload["workspacePath"]?.toString();
    await manager.updateConnectionMetadata(
      connectionId,
      projectName: projectName,
      workspacePath: workspacePath,
    );
  }

  Future<void> _requestChatSnapshot() async {
    final controller = _webViewController;
    if (controller == null) return;
    await controller.evaluateJavascript(
      source: """
        (() => {
          const state = window.ccMobileBridge?.getConnectionState?.();
          if (state && window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('chatSnapshot', state);
          }
        })();
      """,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 无 AppBar，WebView 全屏（cc-viewer 移动端页面自带状态栏）
      body: SafeArea(
        child: Stack(
          children: [
            // WebView
            if (!_isPreparingWebView && !_hasError)
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(widget.webviewUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  // iOS 特定设置
                  disallowOverScroll: true,
                  // 允许本地网络访问
                  allowUniversalAccessFromFileURLs: true,
                  // 允许混合内容（HTTP 和 HTTPS）
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  // 允许文件访问
                  allowFileAccessFromFileURLs: true,
                  // 用户代理标识移动端
                  userAgent: 'ccviewer-mobile-flutter',
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;

                  // 注册 JS -> Flutter 回调: 启动语音输入
                  controller.addJavaScriptHandler(
                    handlerName: 'startVoiceInput',
                    callback: (args) {
                      debugPrint('JS called startVoiceInput');
                      _startListening();
                      return null;
                    },
                  );

                  // 注册 JS -> Flutter 回调: Bridge 就绪通知
                  controller.addJavaScriptHandler(
                    handlerName: 'bridgeReady',
                    callback: (args) {
                      debugPrint('cc-viewer mobile bridge ready');
                      _bridgeReady = true;
                      _finishLoading();
                      _requestChatSnapshot();
                      return null;
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'chatSnapshot',
                    callback: (args) async {
                      final payload = _extractBridgePayload(args);
                      if (payload != null) {
                        await _applyChatSnapshot(payload);
                      }
                      return null;
                    },
                  );

                  // 注册 JS -> Flutter 回调: 连接状态变化
                  controller.addJavaScriptHandler(
                    handlerName: 'onConnectionStateChanged',
                    callback: (args) async {
                      debugPrint('Connection state changed: $args');
                      final payload = _extractBridgePayload(args);
                      if (payload != null) {
                        await _applyChatSnapshot(payload);
                      }
                      return null;
                    },
                  );

                  // 注册 JS -> Flutter 回调: 返回上一页
                  controller.addJavaScriptHandler(
                    handlerName: 'goBack',
                    callback: (args) {
                      debugPrint('JS called goBack');
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                      return null;
                    },
                  );
                },
                onLoadStart: (controller, url) {
                  debugPrint('WebView loading: $url');
                  setState(() {
                    _isWebViewLoading = true;
                    _hasError = false;
                    _errorMessage = '';
                    _loadProgress = 0;
                    _bridgeReady = false;
                    _lastUrl = url?.toString() ?? widget.webviewUrl;
                  });
                  _startLoadTimeout();
                },
                onLoadStop: (controller, url) {
                  debugPrint('WebView loaded: $url');
                  _lastUrl = url?.toString() ?? _lastUrl;
                  _finishLoading();
                },
                onProgressChanged: (controller, progress) {
                  if (!mounted) return;
                  setState(() {
                    _loadProgress = progress;
                  });
                  if (progress >= 100 || (_bridgeReady && progress >= 70)) {
                    _finishLoading(clearError: !_hasError);
                  }
                },
                onReceivedHttpError: (controller, request, response) {
                  debugPrint('WebView HTTP error: ${response.statusCode} ${request.url}');
                  setState(() {
                    _hasError = true;
                    _errorMessage = '页面请求失败: HTTP ${response.statusCode}\n${request.url}';
                    _isWebViewLoading = false;
                  });
                  _loadTimeoutTimer?.cancel();
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('WebView error: ${error.description} @ ${request.url}');
                  setState(() {
                    _hasError = true;
                    _errorMessage = '加载失败: ${error.description}\n${request.url}';
                    _isWebViewLoading = false;
                  });
                  _loadTimeoutTimer?.cancel();
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('WebView console: ${consoleMessage.message}');
                },
              ),

            if (_isPreparingWebView)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        '正在请求本地网络权限...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            
            // 加载指示器
            if (_isWebViewLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('正在加载... $_loadProgress%', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _lastUrl ?? widget.webviewUrl,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // 错误提示
            if (_hasError)
              Container(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请确保:\n1. cc-team-viewer 服务正在运行\n2. 手机和电脑在同一网络\n3. URL 地址正确',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('返回'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _hasError = false;
                                  _isWebViewLoading = true;
                                  _isPreparingWebView = Platform.isIOS;
                                });
                                if (Platform.isIOS) {
                                  _prepareWebView();
                                } else {
                                  _webViewController?.reload();
                                }
                              },
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // 语音识别浮层
            if (_isListening)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 麦克风动画指示
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic, color: Colors.red, size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _recognizedText.isEmpty ? '正在听...' : _recognizedText,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _stopListening,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          ),
                          child: const Text('完成', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _speechToText.stop();
    super.dispose();
  }
}
