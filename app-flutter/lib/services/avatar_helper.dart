import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../l10n/app_localizations.dart';

/// Decodes an image file from disk, center-crops it to a square, and encodes
/// a compact PNG payload ready for local caching and P2P profile sync.
Future<Uint8List> compressAvatarImageFile(
  String filePath, {
  int maxBytes = 480 * 1024,
}) async {
  final raw = await File(filePath).readAsBytes();
  if (raw.isEmpty) {
    throw FormatException(AppLocalizations.current.errorEmptyImageFile);
  }

  for (final targetSize in const [224, 144, 96]) {
    final encoded = await _centerCropAndEncodePng(raw, targetSize);
    if (encoded.length <= maxBytes || targetSize == 96) {
      return encoded;
    }
  }
  throw FormatException(AppLocalizations.current.errorCompressAvatarFailed);
}

Future<Uint8List> _centerCropAndEncodePng(Uint8List raw, int size) async {
  final codec = await ui.instantiateImageCodec(raw);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      final side = w < h ? w : h;
      final src = ui.Rect.fromLTWH(
        (w - side) / 2.0,
        (h - side) / 2.0,
        side,
        side,
      );
      final dst = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, dst);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
      canvas.drawImageRect(image, src, dst, paint);
      final picture = recorder.endRecording();
      try {
        final outImage = await picture.toImage(size, size);
        try {
          final byteData =
              await outImage.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) {
            throw FormatException(AppLocalizations.current.errorPngEncodeFailed);
          }
          return byteData.buffer.asUint8List();
        } finally {
          outImage.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
