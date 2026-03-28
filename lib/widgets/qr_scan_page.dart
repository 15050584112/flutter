import "package:flutter/material.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:ccviewer_mobile_hub/theme/app_theme.dart";

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,  // 持续检测，无限制
    detectionTimeoutMs: 150,                       // 快速反馈
    formats: [BarcodeFormat.qrCode],               // 仅识别 QR 码，减少计算量
    autoStart: true,
  );
  bool _scanned = false;
  bool _torchOn = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;
      
      // 验证 QR 码格式 - 必须是 ccviewer:// 协议
      if (!raw.startsWith('ccviewer://mobile-connect') || !raw.contains('payload=')) {
        continue;  // 格式不对，继续扫描
      }
      
      _scanned = true;
      Navigator.pop(context, raw);
      return;
    }
  }

  void _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() {
      _torchOn = !_torchOn;
    });
  }

  void _showManualInput() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动输入连接链接'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: '粘贴 ccviewer:// 链接',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final text = textController.text.trim();
              Navigator.pop(ctx); // 关闭 dialog
              if (text.isNotEmpty) {
                Navigator.pop(context, text); // 返回结果
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '扫描二维码',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 摄像头预览
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // 扫码框覆盖层
          _buildScanOverlay(),
          // 底部手动输入按钮
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: Center(
              child: TextButton(
                onPressed: _showManualInput,
                child: const Text(
                  '手动输入连接链接',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        // 响应式扫描框尺寸：屏幕宽度的 75%，限制在 280-340 之间
        final scanBoxSize = (screenWidth * 0.75).clamp(280.0, 340.0);
        final left = (screenWidth - scanBoxSize) / 2;
        final top = (screenHeight - scanBoxSize) / 2 - 40; // 稍微偏上

        return Stack(
          children: [
            // 半透明黑色遮罩 - 上部
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top,
              child: Container(color: Colors.black54),
            ),
            // 半透明黑色遮罩 - 下部
            Positioned(
              top: top + scanBoxSize,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(color: Colors.black54),
            ),
            // 半透明黑色遮罩 - 左侧
            Positioned(
              top: top,
              left: 0,
              width: left,
              height: scanBoxSize,
              child: Container(color: Colors.black54),
            ),
            // 半透明黑色遮罩 - 右侧
            Positioned(
              top: top,
              right: 0,
              width: left,
              height: scanBoxSize,
              child: Container(color: Colors.black54),
            ),
            // 扫码框四角装饰线
            Positioned(
              top: top,
              left: left,
              child: CustomPaint(
                size: Size(scanBoxSize, scanBoxSize),
                painter: _ScanFramePainter(color: AppColors.primary),
              ),
            ),
            // 提示文字
            Positioned(
              top: top + scanBoxSize + 24,
              left: 0,
              right: 0,
              child: const Text(
                '将二维码放入框内扫描',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 扫码框四角装饰线绘制器
class _ScanFramePainter extends CustomPainter {
  final Color color;
  static const double cornerLength = 24;
  static const double strokeWidth = 4;

  _ScanFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 左上角
    canvas.drawLine(
      const Offset(0, 0),
      Offset(cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, cornerLength),
      paint,
    );

    // 右上角
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // 左下角
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );

    // 右下角
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
