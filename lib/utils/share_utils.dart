import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Utility class to capture a widget as an image and share it.
class ShareUtils {
  /// Captures the widget bound to [globalKey] as a PNG image and
  /// invokes the system share sheet.
  static Future<void> captureAndShare(
    GlobalKey globalKey, {
    String shareText = '',
  }) async {
    try {
      final boundary = globalKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      // pixelRatio 3.0 ensures high-resolution text clarity
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/olib_booklist_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      // Invoke system share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText,
      );
    } catch (e) {
      rethrow;
    }
  }
}
