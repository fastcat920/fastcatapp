import 'package:fl_clash/xboard/features/auth/services/qr_login_service.dart';
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
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handling = true;
    await _controller.stop();
    try {
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
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_l10n.xboardQrScannerTitle)),
        body: Stack(
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
                    style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
      );
}
