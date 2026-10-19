import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Mostra uma imagem vinda de um link `http(s)` ou de um data URI `data:image/...;base64,...`
/// (formato usado quando o admin escolhe a foto da galeria; o projeto não tem Firebase Storage).
class AppImage extends StatefulWidget {
  const AppImage(this.src, {super.key, this.fit = BoxFit.cover});
  final String src;
  final BoxFit fit;

  static bool isDataUri(String s) => s.startsWith('data:');

  @override
  State<AppImage> createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(AppImage old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src) _decode();
  }

  void _decode() {
    _bytes = null;
    final s = widget.src;
    if (!AppImage.isDataUri(s)) return;
    final comma = s.indexOf(',');
    if (comma < 0) return;
    try {
      _bytes = base64Decode(s.substring(comma + 1));
    } on FormatException {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const broken = ColoredBox(
      color: Color(0x14000000),
      child: Center(child: Icon(Icons.broken_image_outlined)),
    );
    if (AppImage.isDataUri(widget.src)) {
      return _bytes == null ? broken : Image.memory(_bytes!, fit: widget.fit, gaplessPlayback: true);
    }
    return Image.network(
      widget.src,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => broken,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const ColoredBox(color: Color(0x0F000000), child: Center(child: CircularProgressIndicator())),
    );
  }
}
