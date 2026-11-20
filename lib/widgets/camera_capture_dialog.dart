import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/theme/app_theme_tokens.dart';
import '../core/utils/photo_processor.dart';

/// Shows a dialog that allows the user to capture a student photo using their
/// connected webcam (internal or USB), preview it, retake, or confirm and use it.
///
/// Returns the path to the auto-compressed JPEG temp file, or `null` if cancelled.
Future<String?> showCameraCaptureDialog(BuildContext context) {
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const CameraCaptureDialog(),
  );
}

class CameraCaptureDialog extends StatefulWidget {
  const CameraCaptureDialog({super.key});

  @override
  State<CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<CameraCaptureDialog> {
  bool _isLoading = true;
  String? _errorMessage;

  // macOS camera state
  CameraMacOSController? _macController;
  List<CameraMacOSDevice> _macDevices = [];
  String? _selectedMacDeviceId;

  // Windows / Android / iOS camera state
  CameraController? _standardController;
  List<CameraDescription> _standardCameras = [];
  CameraDescription? _selectedStandardCamera;

  // Captured photo preview
  Uint8List? _capturedBytes;
  bool _isProcessingCapture = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    try {
      _macController?.destroy();
    } catch (_) {}
    try {
      _standardController?.dispose();
    } catch (_) {}
    _macController = null;
    _standardController = null;
  }

  Future<void> _initCamera() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (Platform.isMacOS) {
        await _initMacCamera();
      } else {
        await _initStandardCamera();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Camera is not available or permission was denied: $e';
        });
      }
    }
  }

  Future<void> _initMacCamera() async {
    try {
      final devices = await CameraMacOSPlatform.instance.listDevices(
        deviceType: CameraMacOSDeviceType.video,
      );
      if (!mounted) return;
      if (devices.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No camera found on this Mac.';
        });
        return;
      }
      setState(() {
        _macDevices = devices;
        _selectedMacDeviceId = devices.first.deviceId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to access camera on macOS: $e';
      });
    }
  }

  Future<void> _initStandardCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No camera found on this device.';
        });
        return;
      }

      _standardCameras = cameras;
      final cam = _selectedStandardCamera ?? cameras.first;
      _selectedStandardCamera = cam;

      final controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      _standardController?.dispose();
      _standardController = controller;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to initialize camera: $e';
      });
    }
  }

  Future<void> _onMacDeviceChanged(String? newDeviceId) async {
    if (newDeviceId == null || newDeviceId == _selectedMacDeviceId) return;
    try {
      await _macController?.destroy();
    } catch (_) {}
    setState(() {
      _macController = null;
      _selectedMacDeviceId = newDeviceId;
    });
  }

  Future<void> _onStandardCameraChanged(CameraDescription? newCam) async {
    if (newCam == null || newCam == _selectedStandardCamera) return;
    setState(() {
      _isLoading = true;
      _selectedStandardCamera = newCam;
    });
    try {
      await _standardController?.dispose();
      final controller = CameraController(
        newCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      _standardController = controller;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to switch camera: $e';
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_isProcessingCapture) return;
    setState(() {
      _isProcessingCapture = true;
    });

    try {
      Uint8List? rawBytes;
      if (Platform.isMacOS) {
        final macFile = await _macController?.takePicture();
        rawBytes = macFile?.bytes;
      } else if (_standardController != null &&
          _standardController!.value.isInitialized) {
        final xfile = await _standardController!.takePicture();
        rawBytes = await xfile.readAsBytes();
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        throw StateError('Camera capture returned empty image data.');
      }

      if (mounted) {
        setState(() {
          _capturedBytes = rawBytes;
          _isProcessingCapture = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingCapture = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedBytes = null;
    });
  }

  Future<void> _confirmAndUsePhoto() async {
    if (_capturedBytes == null) return;
    setState(() {
      _isProcessingCapture = true;
    });

    try {
      // Auto-compress and square-crop the captured image
      final processedBytes = PhotoProcessor.processPhotoBytes(_capturedBytes!);

      // Save to a temporary file in system cache
      final tempDir = await getTemporaryDirectory();
      final tempFilename = PhotoProcessor.generateFilename();
      final tempFile = File(p.join(tempDir.path, tempFilename));
      await tempFile.writeAsBytes(processedBytes, flush: true);

      if (mounted) {
        Navigator.of(context).pop(tempFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingCapture = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to process photo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      backgroundColor: AppColors.surfaceRaised,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.brandPrimary,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Take Student Photo',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Camera Selector (if > 1 camera available)
              if (_capturedBytes == null &&
                  !_isLoading &&
                  _errorMessage == null)
                _buildCameraSelector(),

              const SizedBox(height: AppSpacing.sm),

              // Viewport / Preview Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: _buildViewportContent(),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSelector() {
    if (Platform.isMacOS) {
      if (_macDevices.length <= 1) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DropdownButtonFormField<String>(
          initialValue: _selectedMacDeviceId,
          isDense: true,
          decoration: const InputDecoration(
            labelText: 'Camera Source',
            prefixIcon: Icon(Icons.videocam_outlined, size: 20),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: _macDevices.map((d) {
            return DropdownMenuItem<String>(
              value: d.deviceId,
              child: Text(
                d.localizedName ?? d.deviceId,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _onMacDeviceChanged,
        ),
      );
    } else {
      if (_standardCameras.length <= 1) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DropdownButtonFormField<CameraDescription>(
          initialValue: _selectedStandardCamera,
          isDense: true,
          decoration: const InputDecoration(
            labelText: 'Camera Source',
            prefixIcon: Icon(Icons.videocam_outlined, size: 20),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: _standardCameras.map((c) {
            return DropdownMenuItem<CameraDescription>(
              value: c,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: _onStandardCameraChanged,
        ),
      );
    }
  }

  Widget _buildViewportContent() {
    if (_capturedBytes != null) {
      // Photo Captured: Preview state
      return Image.memory(
        _capturedBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Camera Unavailable',
                style: AppTypography.h3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Live preview
    if (Platform.isMacOS) {
      return CameraMacOSView(
        key: ValueKey(_selectedMacDeviceId),
        deviceId: _selectedMacDeviceId,
        cameraMode: CameraMacOSMode.photo,
        pictureFormat: PictureFormat.jpg,
        resolution: PictureResolution.medium,
        fit: BoxFit.cover,
        onCameraInizialized: (controller) {
          _macController = controller;
        },
        onCameraLoading: (err) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        onCameraDestroyed: () => const SizedBox.shrink(),
      );
    } else if (_standardController != null &&
        _standardController!.value.isInitialized) {
      return CameraPreview(_standardController!);
    }

    return const Center(
      child: Text(
        'Camera preview not available',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildActions() {
    if (_capturedBytes != null) {
      // Review Captured Photo: Retake or Confirm
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _isProcessingCapture ? null : _retakePhoto,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retake'),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _isProcessingCapture ? null : _confirmAndUsePhoto,
            icon: _isProcessingCapture
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Use Photo'),
          ),
        ],
      );
    }

    // Live Camera Mode: Cancel or Capture
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed:
              (_isLoading || _errorMessage != null || _isProcessingCapture)
              ? null
              : _capturePhoto,
          icon: _isProcessingCapture
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.camera_alt, size: 18),
          label: const Text('Capture Photo'),
        ),
      ],
    );
  }
}
