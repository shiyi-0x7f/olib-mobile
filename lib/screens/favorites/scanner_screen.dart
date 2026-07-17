import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  /// 底部提示浮层文案（如「对准电脑上的无线传书二维码」）；null 则不显示。
  final String? hint;

  const ScannerScreen({super.key, this.hint});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // MobileScannerController controller = MobileScannerController();

  /// onDetect 每帧都会触发，二维码在视野里时连续多帧都识别成功。
  /// 没有守卫会多次 Navigator.pop：第一次关扫码页（对），后续几次把
  /// 接下来打开的页面/对话框也一并 pop 掉（"扫完一闪就没了"）。
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  _handled = true; // 只处理首个有效结果，后续帧忽略
                  Navigator.pop(context, barcode.rawValue);
                  return;
                }
              }
            },
          ),
          if (widget.hint != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 56,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.hint!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
