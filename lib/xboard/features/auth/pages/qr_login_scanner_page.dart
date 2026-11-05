import 'package:fl_clash/xboard/features/auth/services/qr_login_service.dart';
import 'package:fl_clash/xboard/features/auth/services/scanner_zoom.dart';
import 'package:flutter/material.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrLoginScannerPage extends StatefulWidget {
  const QrLoginScannerPage({super.key});

  @override
  State<QrLoginScannerPage> createState() => _QrLoginScannerPageState();
}

class _QrLoginScannerPageState extends State<QrLoginScannerPage> {
  final _controller =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _handling = false;
  late final ScannerZoom _zoom;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _zoom = ScannerZoom(
      readZoom: () => _controller.value.zoomScale,
      applyZoom: _controller.setZoomScale,
    );
    _controller.addListener(_cameraStateChanged);
  }

  void _cameraStateChanged() {
    final camera = _controller.value;
    _zoom.setActive(!_handling &&
        camera.isInitialized &&
        camera.isRunning &&
        !camera.isStarting &&
        camera.error == null);
  }

  @override
  void dispose() {
    _controller.removeListener(_cameraStateChanged);
    _zoom.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handling = true;
    try {
      await _zoom.pause();
      if (!mounted) return;
      await _controller.stop();
      final challenge = QrLoginService.parse(raw);
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.tv_outlined),
          title: Text(_l10n.xboardQrAuthorizeTitle),
          content: Text(_l10n.xboardQrAuthorizeMessage),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_l10n.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_l10n.xboardQrAuthorizeConfirm)),
          ],
        ),
      );
      if (accepted == true) {
        await QrLoginService.approve(challenge.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_l10n.xboardQrAuthorizeSuccess)));
          Navigator.pop(context, true);
          return;
        }
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_l10n.xboardQrInvalidCode)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_l10n.xboardQrAuthorizeFailed)));
      }
    }
    if (mounted) {
      _handling = false;
      try {
        await _controller.start();
        if (mounted) _cameraStateChanged();
      } catch (_) {
        // MobileScanner presents camera startup/permission errors itself.
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_l10n.xboardQrScannerTitle)),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => _zoom.endGesture(),
          onScaleUpdate: (details) =>
              _zoom.update(details.scale, details.pointerCount),
          onScaleEnd: (_) => _zoom.endGesture(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              Positioned(
                  bottom: 64,
                  left: 24,
                  right: 24,
                  child: Text(_l10n.xboardQrScannerHint,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16))),
            ],
          ),
        ),
      );
}
