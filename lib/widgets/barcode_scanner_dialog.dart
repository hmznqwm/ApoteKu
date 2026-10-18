import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/sound_helper.dart';
import '../providers/produk_provider.dart';
import '../models/produk_model.dart';

enum ScanMode {
  hybrid, // Scan Barcode + Teks Strip Obat
  barcode, // Scan Barcode Saja
  textOcr, // Scan Teks Strip Obat Saja
}

class BarcodeScannerDialog extends StatefulWidget {
  final bool continuous;
  final String title;
  final Function(String code)? onScanned;

  const BarcodeScannerDialog({
    super.key,
    this.continuous = false,
    this.title = 'Pindai Barcode / Teks Obat',
    this.onScanned,
  });

  /// Open scanner modal for single scan and return scanned string
  static Future<String?> scanSingle(BuildContext context, {String title = 'Pindai Barcode / Teks Obat'}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BarcodeScannerDialog(
        continuous: false,
        title: title,
      ),
    );
  }

  /// Open scanner modal for continuous cashier scanning
  static Future<void> scanContinuous(
    BuildContext context, {
    required Function(String code) onScanned,
    String title = 'Kasir: Pindai Barcode / Teks Strip Obat',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BarcodeScannerDialog(
        continuous: true,
        title: title,
        onScanned: onScanned,
      ),
    );
  }

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  late AnimationController _animController;
  late Animation<double> _laserAnimation;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextEditingController _manualCtrl = TextEditingController();

  ScanMode _selectedMode = ScanMode.hybrid;

  // State Pelacakan Barcode/Teks & Anti-Looping Frame
  String? _lockedInViewCode;
  DateTime? _lastFrameDetectionTime;
  Timer? _absenceMonitorTimer;
  bool _isProcessingScan = false;
  bool _isProcessingOcr = false;
  DateTime? _lastOcrProcessingTime;

  // Realtime OCR Detected Text Chips
  List<String> _detectedTextChips = [];

  String? _lastScannedCode;
  int _scannedCount = 0;
  bool _isTorchOn = false;
  bool _isFlashingSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: true,
      autoStart: true,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.qrCode,
        BarcodeFormat.dataMatrix,
        BarcodeFormat.itf14,
        BarcodeFormat.codabar,
      ],
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Monitor ketidakhadiran barcode/item di kamera (> 750ms unlock)
    _absenceMonitorTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      if (_lockedInViewCode != null && _lastFrameDetectionTime != null) {
        final elapsed = DateTime.now().difference(_lastFrameDetectionTime!).inMilliseconds;
        if (elapsed > 750) {
          if (mounted) {
            setState(() {
              _lockedInViewCode = null;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _absenceMonitorTimer?.cancel();
    _animController.dispose();
    _controller.dispose();
    _textRecognizer.close();
    _manualCtrl.dispose();
    super.dispose();
  }

  /// Menangani deteksi kamera (Barcode + Text OCR)
  void _onBarcodesDetected(BarcodeCapture capture) {
    if (_isProcessingScan) return;

    // 1. PROSES BARCODE SCAN (Fast Path)
    if (_selectedMode != ScanMode.textOcr) {
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw == null) continue;
        final cleanCode = raw.trim();
        if (cleanCode.isEmpty) continue;

        final now = DateTime.now();
        _lastFrameDetectionTime = now;

        if (_lockedInViewCode == cleanCode) {
          return;
        }

        _processSuccessfulScan(cleanCode);
        return;
      }
    }

    // 2. PROSES TEKS OCR SCAN (Fallback Path untuk Strip Obat)
    if (_selectedMode != ScanMode.barcode && !_isProcessingOcr) {
      final now = DateTime.now();
      if (_lastOcrProcessingTime == null ||
          now.difference(_lastOcrProcessingTime!).inMilliseconds > 450) {
        _lastOcrProcessingTime = now;
        _processOcrFromCapture(capture);
      }
    }
  }

  /// Eksekusi Text OCR dari frame kamera
  Future<void> _processOcrFromCapture(BarcodeCapture capture) async {
    final img = capture.image;
    if (img == null || img.isEmpty) return;

    _isProcessingOcr = true;
    try {
      final inputImage = _createInputImageFromCapture(capture);
      if (inputImage == null) {
        _isProcessingOcr = false;
        return;
      }

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final List<String> extractedLines = [];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final cleanText = line.text.trim();
          if (cleanText.length >= 3 &&
              !RegExp(r'^\d+$').hasMatch(cleanText) &&
              !RegExp(r'^[^\w\s]+$').hasMatch(cleanText)) {
            if (!extractedLines.contains(cleanText)) {
              extractedLines.add(cleanText);
            }
          }
        }
      }

      if (mounted && extractedLines.isNotEmpty) {
        setState(() {
          _detectedTextChips = extractedLines.take(5).toList();
        });

        // Auto Match dengan Database Obat di ProdukProvider
        final produkProv = context.read<ProdukProvider>();
        final allProds = produkProv.allProducts;

        for (final textLine in extractedLines) {
          final query = textLine.toLowerCase();
          ProdukModel? match;

          for (final p in allProds) {
            final pNama = p.nama.toLowerCase();
            if (query == pNama || pNama.contains(query) || (query.length >= 4 && query.contains(pNama))) {
              match = p;
              break;
            }
          }

          if (match != null && _lockedInViewCode != match.nama) {
            _lastFrameDetectionTime = DateTime.now();
            _processSuccessfulScan(match.nama);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('OCR Exception: $e');
    } finally {
      _isProcessingOcr = false;
    }
  }

  InputImage? _createInputImageFromCapture(BarcodeCapture capture) {
    try {
      final img = capture.image;
      if (img == null || img.isEmpty) return null;

      final Size imgSize = capture.size;
      final int width = imgSize.width.toInt() > 0 ? imgSize.width.toInt() : 1280;
      final int height = imgSize.height.toInt() > 0 ? imgSize.height.toInt() : 720;

      return InputImage.fromBytes(
        bytes: img,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: width,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Eksekusi scan berhasil: Bunyi "TITT", getar, efek visual, dan kirim hasil
  Future<void> _processSuccessfulScan(String cleanCode) async {
    _isProcessingScan = true;
    _lockedInViewCode = cleanCode;
    _lastScannedCode = cleanCode;
    _scannedCount++;

    // 1. Suara TITT & Haptik
    SoundHelper.playScannerBeep();

    // 2. Efek Visual Flash Hijau
    if (mounted) {
      setState(() {
        _isFlashingSuccess = true;
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() {
            _isFlashingSuccess = false;
          });
        }
      });
    }

    // 3. Callback ke Kasir / Form
    if (widget.continuous) {
      widget.onScanned?.call(cleanCode);
      _isProcessingScan = false;
    } else {
      await Future.delayed(const Duration(milliseconds: 180));
      if (mounted) {
        Navigator.of(context).pop(cleanCode);
      }
    }
  }

  void _submitManualCode() {
    final code = _manualCtrl.text.trim();
    if (code.isNotEmpty) {
      _processSuccessfulScan(code);
      _manualCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktopOrWeb = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: screenHeight * 0.82),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isFlashingSuccess ? const Color(0xFF10B981) : const Color(0xFF334155),
            width: _isFlashingSuccess ? 2.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isFlashingSuccess
                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primaryAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Flashlight toggle
                  if (!isDesktopOrWeb) ...[
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? Colors.amber : Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'Senter',
                      onPressed: () async {
                        try {
                          await _controller.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        } catch (_) {}
                      },
                    ),
                    // Switch camera
                    IconButton(
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white70, size: 20),
                      tooltip: 'Ganti Kamera',
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ],
                  // Close
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Mode Selector Bar (Hybrid vs Barcode vs OCR Teks)
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeSegmentButton(
                      mode: ScanMode.hybrid,
                      label: 'Smart Hybrid',
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildModeSegmentButton(
                      mode: ScanMode.barcode,
                      label: 'Barcode',
                      icon: Icons.barcode_reader,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildModeSegmentButton(
                      mode: ScanMode.textOcr,
                      label: 'Teks Strip Obat',
                      icon: Icons.document_scanner_rounded,
                    ),
                  ),
                ],
              ),
            ),

            // Camera Scanner Viewport or Fallback
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isDesktopOrWeb)
                    _buildFallbackCameraView()
                  else
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onBarcodesDetected,
                      errorBuilder: (context, error) {
                        return _buildFallbackCameraView(
                          errorMessage: 'Kamera tidak dapat diakses (${error.errorCode.name}). Silakan gunakan input manual di bawah.',
                        );
                      },
                    ),

                  // Scanning Overlay
                  if (!isDesktopOrWeb)
                    _buildScannerOverlay(),

                  // Detected OCR Text Chips Overlay (Tinggal Tap untuk Scan)
                  if (_detectedTextChips.isNotEmpty)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.style_rounded, color: AppColors.primaryAccent, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Teks Obat Terdeteksi (Tap untuk Scan):',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _detectedTextChips.map((chipText) {
                                return ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: const Color(0xFF1E293B),
                                  side: const BorderSide(color: Color(0xFF38BDF8)),
                                  label: Text(
                                    chipText,
                                    style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    _processSuccessfulScan(chipText);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Control & Manual Input Panel
            Container(
              padding: const EdgeInsets.all(14),
              color: const Color(0xFF1E293B),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Continuous Scan Feedback Banner
                  if (widget.continuous && _lastScannedCode != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF059669)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hasil: $_lastScannedCode  ($_scannedCount di-scan)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Manual Barcode / Name Input Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF475569)),
                          ),
                          child: TextField(
                            controller: _manualCtrl,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onSubmitted: (_) => _submitManualCode(),
                            decoration: const InputDecoration(
                              hintText: 'Ketik kode barcode atau nama obat...',
                              hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              prefixIcon: Icon(Icons.keyboard_alt_outlined, color: Color(0xFF94A3B8), size: 18),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _submitManualCode,
                        child: const Text('Input', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  if (widget.continuous) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                        label: Text('Selesai Scan (${_scannedCount > 0 ? "$_scannedCount Barang" : "Kembali"})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSegmentButton({
    required ScanMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _detectedTextChips.clear();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryAccent : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.5,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = (constraints.maxWidth * 0.82).clamp(230.0, 340.0);
        final isLocked = _lockedInViewCode != null;

        return Stack(
          children: [
            // Darkened background with transparent center cutout
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.65),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Reticle Border Frame
            Center(
              child: SizedBox(
                width: scanAreaSize,
                height: scanAreaSize,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ScannerReticlePainter(
                          color: _isFlashingSuccess
                              ? const Color(0xFF10B981)
                              : (isLocked ? const Color(0xFF10B981) : AppColors.primaryAccent),
                          strokeWidth: _isFlashingSuccess ? 5.0 : 4.0,
                          cornerLength: 28.0,
                        ),
                      ),
                    ),

                    if (!isLocked)
                      AnimatedBuilder(
                        animation: _laserAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: scanAreaSize * _laserAnimation.value,
                            left: 12,
                            right: 12,
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34D399),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF34D399).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    if (isLocked)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF34D399),
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Hint Text Status
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isLocked ? const Color(0xFF064E3B) : Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isLocked ? const Color(0xFF059669) : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLocked ? Icons.check_circle_outline_rounded : Icons.center_focus_strong_rounded,
                        color: isLocked ? const Color(0xFF34D399) : Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isLocked
                            ? 'Terscan! Jauhkan barang untuk scan lagi'
                            : (_selectedMode == ScanMode.textOcr
                                ? 'Posisikan teks strip obat di dalam kotak'
                                : 'Posisikan barcode atau teks obat di dalam kotak'),
                        style: TextStyle(
                          color: isLocked ? const Color(0xFFD1FAE5) : Colors.white,
                          fontSize: 11.5,
                          fontWeight: isLocked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFallbackCameraView({String? errorMessage}) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(
                Icons.barcode_reader,
                color: AppColors.primaryAccent,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Smart Scanner Kamera',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage ?? 'Masukkan kode barcode / nama obat secara manual atau buka kamera:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Buka Kamera PC/Laptop'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      // ignore: deprecated_member_use
                      return const SimpleBarcodeScannerPage();
                    },
                  ),
                );
                if (result != null && result is String && result != '-1') {
                  _processSuccessfulScan(result);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerReticlePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;

  _ScannerReticlePainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const r = 16.0;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLength)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(cornerLength, 0),
      paint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(w - cornerLength, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, cornerLength),
      paint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - cornerLength)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(cornerLength, h),
      paint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(w - cornerLength, h)
        ..lineTo(w - r, h)
        ..quadraticBezierTo(w, h, w, h - r)
        ..lineTo(w, h - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerReticlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerLength != cornerLength;
  }
}
