import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _QrLoginScannerPageState extends State<QrLoginScannerPage>
    with WidgetsBindingObserver {
  final _controller =
      MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _handling = false;
  bool _settingsOpened = false;
  bool _restarting = false;
  late final ScannerZoom _zoom;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_cameraStateChanged);
    _zoom.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _settingsOpened) {
      _settingsOpened = false;
      _restartCamera();
    }
  }

  Future<void> _restartCamera() async {
    if (_handling || _restarting || !mounted) return;
    _restarting = true;
    try {
      await _controller.stop();
      if (mounted) await _controller.start();
    } catch (_) {
      /* The scanner displays the current permission/device error. */
    } finally {
      _restarting = false;
    }
  }

  Future<void> _openCameraSettings() async {
    _settingsOpened = true;
    try {
      final opened = Platform.isIOS
          ? await launchUrl(Uri.parse('app-settings:'),
              mode: LaunchMode.externalApplication)
          : Platform.isAndroid
              ? await const MethodChannel('app')
                      .invokeMethod<bool>('openAppSettings') ??
                  false
              : false;
      if (!opened) throw StateError('Settings unavailable');
    } catch (_) {
      _settingsOpened = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_l10n.xboardCameraSettingsUnavailable)));
      }
    }
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
        body: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, camera, _) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _zoom.endGesture(),
            onScaleUpdate: (details) =>
                _zoom.update(details.scale, details.pointerCount),
            onScaleEnd: (_) => _zoom.endGesture(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: Center(
                        child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.no_photography_outlined, size: 40),
                        const SizedBox(height: 16),
                        Text(
                            error.errorCode ==
                                    MobileScannerErrorCode.permissionDenied
                                ? _l10n.xboardCameraPermissionDenied
                                : _l10n.xboardCameraUnavailable,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: error.errorCode ==
                                    MobileScannerErrorCode.permissionDenied
                                ? _openCameraSettings
                                : _restartCamera,
                            child: Text(error.errorCode ==
                                    MobileScannerErrorCode.permissionDenied
                                ? _l10n.xboardOpenCameraSettings
                                : _l10n.xboardRetry)),
                      ]),
                    )),
                  ),
                ),
                if (camera.error == null)
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                if (camera.error == null)
                  Positioned(
                      bottom: 64,
                      left: 24,
                      right: 24,
                      child: Text(_l10n.xboardQrScannerHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16))),
              ],
            ),
          ),
        ),
      );
}
