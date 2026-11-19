import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Resolved thumbnail file and its display aspect dimensions.
class CachedThumbInfo {
  final String path;
  final int width;
  final int height;

  const CachedThumbInfo({
    required this.path,
    required this.width,
    required this.height,
  });
}

/// Manages lightweight local thumbnail files (`<dataDir>/thumbs/`) and warms
/// Flutter's in-memory [imageCache] so chat images render synchronously on entry.
class ThumbnailCacheService {
  static const int maxThumbWidth = 420;
  static const int maxThumbHeight = 840;
  static const int _maxQueued = 24;

  final Directory _thumbsDir;
  final Map<String, CachedThumbInfo> _memIndex = <String, CachedThumbInfo>{};
  final Set<String> _inFlight = <String>{};
  final Queue<({String msgId, String sourcePath})> _queue =
      Queue<({String msgId, String sourcePath})>();
  final StreamController<String> _readyController =
      StreamController<String>.broadcast();
  bool _draining = false;
  bool _disposed = false;
  bool _diskIndexed = false;
  Future<void>? _indexFuture;
  Timer? _drainTimer;

  ThumbnailCacheService(String dataDir)
      : _thumbsDir = Directory('$dataDir${Platform.pathSeparator}thumbs');

  /// Emits `msgId` when a thumbnail finishes generating in the background.
  Stream<String> get onThumbReady => _readyController.stream;

  /// Scans `<dataDir>/thumbs/` asynchronously once into [_memIndex].
  Future<void> ensureIndexed() {
    if (_disposed || _diskIndexed) return Future<void>.value();
    if (!_thumbsDir.existsSync()) {
      _diskIndexed = true;
      return Future<void>.value();
    }
    return _indexFuture ??= _indexDiskAsync();
  }

  Future<void> _indexDiskAsync() async {
    try {
      if (_disposed || !_thumbsDir.existsSync()) {
        _diskIndexed = true;
        return;
      }
      final newlyIndexed = <String>[];
      await for (final entity in _thumbsDir.list(followLinks: false)) {
        if (_disposed) return;
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.endsWith('.png')) continue;
        final sep = name.lastIndexOf('_');
        if (sep <= 0) continue;
        final safeKey = name.substring(0, sep);
        final dims = _parseDimsSuffix(name.substring(sep + 1, name.length - 4));
        if (dims == null) continue;
        if (!_memIndex.containsKey(safeKey)) {
          _memIndex[safeKey] = CachedThumbInfo(
            path: entity.path,
            width: dims.$1,
            height: dims.$2,
          );
          newlyIndexed.add(safeKey);
        }
      }
      _diskIndexed = true;
      if (!_disposed && !_readyController.isClosed) {
        for (final key in newlyIndexed) {
          _readyController.add(key);
        }
      }
    } catch (_) {
      _diskIndexed = true;
    } finally {
      _indexFuture = null;
    }
  }

  /// Returns cached thumbnail info in O(1) from [_memIndex]; kicks off async
  /// disk indexing on first access without blocking the UI thread.
  CachedThumbInfo? lookupSync(String msgId) {
    if (!_diskIndexed && !_disposed) {
      unawaited(ensureIndexed());
    }
    return _memIndex[_safeKey(msgId)];
  }

  /// Ensures a thumbnail exists for `(msgId, sourcePath)` and warms it into
  /// Flutter's [imageCache]. Safe to call repeatedly.
  void warmUp(String msgId, String sourcePath) {
    if (_disposed || msgId.isEmpty || sourcePath.isEmpty) return;
    final key = _safeKey(msgId);
    final existing = lookupSync(msgId);
    if (existing != null) {
      _precacheImageProvider(FileImage(File(existing.path)));
      return;
    }
    if (_inFlight.contains(key) || _queue.length >= _maxQueued) return;
    _inFlight.add(key);
    _queue.add((msgId: msgId, sourcePath: sourcePath));
    if (!_draining && _drainTimer == null) {
      _drainTimer = Timer(Duration.zero, () {
        _drainTimer = null;
        unawaited(_drainQueue());
      });
    }
  }

  Future<void> _drainQueue() async {
    if (_draining || _disposed) return;
    _draining = true;
    try {
      await ensureIndexed();
      while (_queue.isNotEmpty && !_disposed) {
        final task = _queue.removeFirst();
        final key = _safeKey(task.msgId);
        try {
          final existing = _memIndex[key];
          if (existing != null) {
            _precacheImageProvider(FileImage(File(existing.path)));
          } else {
            await _generateAndPrecache(task.msgId, task.sourcePath);
          }
        } catch (_) {
          // Best-effort cache; never crash on unreadable or deleted files.
        } finally {
          _inFlight.remove(key);
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _generateAndPrecache(String msgId, String sourcePath) async {
    if (_disposed) return;
    final srcFile = File(sourcePath);
    if (!srcFile.existsSync()) return;
    final raw = await srcFile.readAsBytes();
    if (_disposed || raw.isEmpty) return;

    final buffer = await ui.ImmutableBuffer.fromUint8List(raw);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final origW = descriptor.width;
      final origH = descriptor.height;
      if (_disposed || origW <= 0 || origH <= 0) return;

      if (origW <= maxThumbWidth && origH <= maxThumbHeight) {
        codec = await descriptor.instantiateCodec(
          targetWidth: origW,
          targetHeight: origH,
        );
      } else {
        final scale = math.min(maxThumbWidth / origW, maxThumbHeight / origH);
        final targetW = (origW * scale).round().clamp(1, maxThumbWidth);
        final targetH = (origH * scale).round().clamp(1, maxThumbHeight);
        codec = await descriptor.instantiateCodec(
          targetWidth: targetW,
          targetHeight: targetH,
        );
      }

      final frame = await codec.getNextFrame();
      final img = frame.image;
      try {
        if (_disposed) return;
        final w = img.width;
        final h = img.height;
        if (w <= 0 || h <= 0) return;

        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        if (_disposed || byteData == null) return;

        if (!_thumbsDir.existsSync()) {
          await _thumbsDir.create(recursive: true);
        }
        if (_disposed) return;
        final safe = _safeKey(msgId);
        final outPath =
            '${_thumbsDir.path}${Platform.pathSeparator}${safe}_${w}x$h.png';
        await File(outPath).writeAsBytes(
          byteData.buffer.asUint8List(),
          flush: false,
        );
        if (_disposed) return;
        final info = CachedThumbInfo(path: outPath, width: w, height: h);
        _memIndex[safe] = info;
        _precacheImageProvider(FileImage(File(outPath)));
        if (!_readyController.isClosed) {
          _readyController.add(msgId);
        }
      } finally {
        img.dispose();
      }
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Clears in-memory index, queued tasks, on-disk thumbnails, and Flutter's [imageCache].
  Future<void> clear() async {
    _drainTimer?.cancel();
    _drainTimer = null;
    _queue.clear();
    _inFlight.clear();
    _memIndex.clear();
    _indexFuture = null;
    _diskIndexed = true;
    try {
      if (_thumbsDir.existsSync()) {
        await for (final entity in _thumbsDir.list(followLinks: false)) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    try {
      PaintingBinding.instance.imageCache.clear();
    } catch (_) {}
  }

  void _precacheImageProvider(ImageProvider provider) {
    try {
      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (image, synchronousCall) {
          stream.removeListener(listener);
        },
        onError: (_, _) {
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    } catch (_) {}
  }

  static String _safeKey(String msgId) =>
      msgId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static (int, int)? _parseDimsSuffix(String stem) {
    final parts = stem.split('x');
    if (parts.length != 2) return null;
    final w = int.tryParse(parts[0]);
    final h = int.tryParse(parts[1]);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return (w, h);
  }

  void dispose() {
    _disposed = true;
    _drainTimer?.cancel();
    _drainTimer = null;
    _queue.clear();
    _inFlight.clear();
    _memIndex.clear();
    unawaited(_readyController.close());
  }
}
