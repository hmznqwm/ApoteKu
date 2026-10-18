import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HardwareBarcodeListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  /// Batas waktu maksimal antar ketikan agar dianggap sebagai hasil scan barcode.
  /// Scanner biasanya mengirim input setiap < 50ms.
  final Duration bufferDuration;

  const HardwareBarcodeListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.bufferDuration = const Duration(milliseconds: 300),
  });

  @override
  State<HardwareBarcodeListener> createState() => _HardwareBarcodeListenerState();
}

class _HardwareBarcodeListenerState extends State<HardwareBarcodeListener> {
  String _buffer = '';
  DateTime? _lastKeyPress;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      
      // Reset buffer jika jeda antar tombol terlalu lama (berarti bukan dari scanner melainkan diketik manual oleh manusia)
      if (_lastKeyPress != null && now.difference(_lastKeyPress!) > widget.bufferDuration) {
        _buffer = '';
      }
      
      _lastKeyPress = now;

      // Enter menandakan akhir dari barcode
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_buffer.isNotEmpty) {
          widget.onBarcodeScanned(_buffer);
          _buffer = '';
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        // Hanya tambahkan karakter yang bisa dicetak
        // Jangan hapus spasi jika memang barcodenya ada spasi, meskipun jarang
        _buffer += event.character!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        // Biarkan event diteruskan jika ada widget lain (seperti TextField) yang membutuhkan
        return KeyEventResult.ignored; 
      },
      child: widget.child,
    );
  }
}
