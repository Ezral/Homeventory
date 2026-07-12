import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// Returns scanned barcode value via `context.pop(String)`.
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key, this.title = 'Scan barcode'});

  final String title;

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;

  /// True after the camera permission request finishes.
  bool _permissionChecked = false;
  bool _permissionDenied = false;

  /// Prevents processing more than one barcode per screen visit.
  bool _handled = false;

  /// Guards concurrent manual start/stop calls (lifecycle / retry).
  bool _startInFlight = false;
  bool _stopInFlight = false;

  /// Lifecycle / attach retries that are not "camera unavailable".
  String? _initMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_requestPermissionAndAttach());
  }

  Future<void> _requestPermissionAndAttach() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      final previous = _controller;
      _controller = null;
      unawaited(previous?.dispose());
      setState(() {
        _permissionDenied = true;
        _permissionChecked = true;
        _initMessage = null;
      });
      return;
    }

    // Already have a live controller — just clear denied state and ensure start.
    if (_controller != null && !_permissionDenied) {
      setState(() {
        _permissionDenied = false;
        _permissionChecked = true;
        _initMessage = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_safeStart());
      });
      return;
    }

    // Dispose any previous controller before creating a new one.
    final previous = _controller;
    _controller = null;
    unawaited(previous?.dispose());

    // Only create the controller once permission is granted, then mount
    // [MobileScanner] in the same frame. autoStart lets the widget start
    // after it attaches — never call start() before MobileScanner builds.
    final controller = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.qrCode,
      ],
    );

    setState(() {
      _permissionDenied = false;
      _permissionChecked = true;
      _controller = controller;
      _initMessage = null;
    });
  }

  Future<void> _safeStart() async {
    final controller = _controller;
    if (controller == null ||
        !mounted ||
        _permissionDenied ||
        _handled ||
        _startInFlight) {
      return;
    }

    _startInFlight = true;
    try {
      if (controller.value.isRunning || controller.value.isStarting) {
        return;
      }
      await controller.start();
      if (!mounted) return;
      setState(() => _initMessage = null);
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      if (e.errorCode == MobileScannerErrorCode.controllerNotAttached ||
          e.errorCode == MobileScannerErrorCode.controllerInitializing) {
        setState(() {
          _initMessage =
              'Scanner is still starting. Tap Retry once the camera preview is ready.';
        });
        return;
      }
      if (e.errorCode == MobileScannerErrorCode.permissionDenied) {
        setState(() {
          _permissionDenied = true;
          _initMessage = null;
        });
        return;
      }
      // Genuine hardware / unsupported failures surface via errorBuilder.
      setState(() => _initMessage = null);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initMessage = 'Could not restart the scanner. Tap Retry to try again.';
      });
    } finally {
      _startInFlight = false;
    }
  }

  Future<void> _safeStop() async {
    final controller = _controller;
    if (controller == null || _stopInFlight) return;

    _stopInFlight = true;
    try {
      if (!controller.value.isRunning && !controller.value.isStarting) {
        return;
      }
      await controller.stop();
    } catch (_) {
      // Ignore stop races during rapid navigation / lifecycle churn.
    } finally {
      _stopInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs fire lifecycle events before the scanner exists.
    if (!_permissionChecked) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.resumed:
        if (_permissionDenied || _controller == null) {
          // Returning from Settings after a denial — re-check permission.
          unawaited(_requestPermissionAndAttach());
          break;
        }
        // Restart only after the next frame so MobileScanner stays attached.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_safeStart());
        });
      case AppLifecycleState.inactive:
        if (_controller != null && !_permissionDenied) {
          unawaited(_safeStop());
        }
    }
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .map((v) => v.trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;

    _handled = true;
    unawaited(_safeStop());
    if (!mounted) return;
    context.pop(value);
  }

  Future<void> _retryInitialization() async {
    setState(() => _initMessage = null);
    if (_controller == null) {
      await _requestPermissionAndAttach();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_safeStart());
    });
  }

  Future<void> _enterManually() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const BarcodeManualEntrySheet(),
    );
    if (!mounted) return;
    if (value != null && value.trim().isNotEmpty) {
      _handled = true;
      unawaited(_safeStop());
      context.pop(value.trim());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    // Dispose exactly once; MobileScanner does not dispose an injected
    // controller when autoStart stops it on widget teardown.
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            unawaited(_safeStop());
            context.pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: _enterManually,
            child: const Text('Type'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_permissionChecked) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return _MessagePanel(
        title: 'Camera permission needed',
        message:
            'Allow camera access to scan barcodes, or enter the code manually.',
        actionLabel: 'Open settings',
        onAction: openAppSettings,
        secondaryLabel: 'Enter manually',
        onSecondary: _enterManually,
      );
    }

    final controller = _controller;
    if (controller == null) {
      return _MessagePanel(
        title: 'Scanner not ready',
        message: 'Tap Retry to initialize the camera scanner.',
        actionLabel: 'Retry',
        onAction: () => unawaited(_retryInitialization()),
        secondaryLabel: 'Enter manually',
        onSecondary: _enterManually,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: _handleBarcode,
          errorBuilder: (context, error) => _scannerErrorPanel(error),
        ),
        if (_initMessage != null)
          Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.black54,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _initMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => unawaited(_retryInitialization()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.all(20),
            child: const Text(
              'Point the camera at a barcode or QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scannerErrorPanel(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return _MessagePanel(
          title: 'Camera permission needed',
          message:
              'Allow camera access to scan barcodes, or enter the code manually.',
          actionLabel: 'Open settings',
          onAction: openAppSettings,
          secondaryLabel: 'Enter manually',
          onSecondary: _enterManually,
        );
      case MobileScannerErrorCode.unsupported:
        return _MessagePanel(
          title: 'Camera unavailable',
          message: 'No usable camera was found on this device.',
          actionLabel: 'Enter manually',
          onAction: () => unawaited(_enterManually()),
          secondaryLabel: 'Close',
          onSecondary: () async {
            if (mounted) context.pop();
          },
        );
      case MobileScannerErrorCode.controllerNotAttached:
      case MobileScannerErrorCode.controllerInitializing:
      case MobileScannerErrorCode.controllerUninitialized:
        return _MessagePanel(
          title: 'Scanner starting',
          message:
              'The camera preview is still attaching. Tap Retry in a moment.',
          actionLabel: 'Retry',
          onAction: () => unawaited(_retryInitialization()),
          secondaryLabel: 'Enter manually',
          onSecondary: _enterManually,
        );
      case MobileScannerErrorCode.controllerAlreadyInitialized:
      case MobileScannerErrorCode.controllerDisposed:
      case MobileScannerErrorCode.genericError:
        return _MessagePanel(
          title: 'Camera unavailable',
          message: error.errorDetails?.message ??
              'Could not start the camera. You can retry or enter a code manually.',
          actionLabel: 'Retry',
          onAction: () => unawaited(_retryInitialization()),
          secondaryLabel: 'Enter manually',
          onSecondary: _enterManually,
        );
    }
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String secondaryLabel;
  final Future<void> Function() onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
          const SizedBox(height: 12),
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
        ],
      ),
    );
  }
}

/// Manual entry fallback when camera is unavailable.
class BarcodeManualEntrySheet extends StatefulWidget {
  const BarcodeManualEntrySheet({super.key});

  @override
  State<BarcodeManualEntrySheet> createState() =>
      _BarcodeManualEntrySheetState();
}

class _BarcodeManualEntrySheetState extends State<BarcodeManualEntrySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter barcode', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Barcode value'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final v = _controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(context, v);
            },
            child: const Text('Use barcode'),
          ),
        ],
      ),
    );
  }
}
