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
  StreamSubscription<BarcodeCapture>? _subscription;
  bool _handled = false;
  bool _permissionDenied = false;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
        _starting = false;
      });
      return;
    }

    final controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
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
    _controller = controller;
    _subscription = controller.barcodes.listen(_onDetect);

    try {
      await controller.start();
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || _permissionDenied) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        unawaited(() async {
          await _subscription?.cancel();
          _subscription = controller.barcodes.listen(_onDetect);
          try {
            await controller.start();
          } catch (_) {
            try {
              await controller.stop();
              await controller.start();
            } catch (_) {}
          }
        }());
      case AppLifecycleState.inactive:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(controller.stop());
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    _handled = true;
    context.pop(value.trim());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final value = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const BarcodeManualEntrySheet(),
              );
              if (value != null && value.trim().isNotEmpty && context.mounted) {
                context.pop(value.trim());
              }
            },
            child: const Text('Type'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_starting) {
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
        onSecondary: () async {
          final value = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const BarcodeManualEntrySheet(),
          );
          if (value != null && value.trim().isNotEmpty && mounted) {
            context.pop(value.trim());
          }
        },
      );
    }
    if (_error != null || _controller == null) {
      return _MessagePanel(
        title: 'Camera unavailable',
        message: _error ?? 'Could not start the camera.',
        actionLabel: 'Retry',
        onAction: () {
          setState(() {
            _starting = true;
            _error = null;
          });
          unawaited(_bootstrap());
        },
        secondaryLabel: 'Enter manually',
        onSecondary: () async {
          final value = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const BarcodeManualEntrySheet(),
          );
          if (value != null && value.trim().isNotEmpty && mounted) {
            context.pop(value.trim());
          }
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller!),
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
  final VoidCallback onSecondary;

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
