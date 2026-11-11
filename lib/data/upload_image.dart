import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

Future<String> prepareUploadImage(
  Uint8List bytes, {
  bool square = false,
  int turns = 0,
  double zoom = 1,
}) => compute(_encodeImage, {
  'bytes': bytes,
  'square': square,
  'turns': turns,
  'zoom': zoom,
});
String _encodeImage(Map<String, Object> input) {
  final bytes = input['bytes'] as Uint8List;
  if (bytes.length > 5 * 1024 * 1024) {
    throw StateError('Choose an image smaller than 5 MB.');
  }
  var decoded = image.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('This image could not be decoded. Choose JPEG or PNG.');
  }
  decoded = image.bakeOrientation(decoded);
  if (input['turns'] != 0) {
    decoded = image.copyRotate(decoded, angle: (input['turns'] as int) * 90);
  }
  if (input['square'] == true) {
    final side =
        (decoded.width < decoded.height ? decoded.width : decoded.height) /
        (input['zoom'] as double);
    decoded = image.copyCrop(
      decoded,
      x: ((decoded.width - side) / 2).round(),
      y: ((decoded.height - side) / 2).round(),
      width: side.round(),
      height: side.round(),
    );
  }
  if (decoded.width > 1024 || decoded.height > 1024) {
    decoded = image.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? 1024 : null,
      height: decoded.height > decoded.width ? 1024 : null,
    );
  }
  for (final quality in [85, 70, 55, 40]) {
    final encoded = image.encodeJpg(decoded, quality: quality);
    if (encoded.length <= 512 * 1024) {
      return 'data:image/jpeg;base64,${base64Encode(encoded)}';
    }
  }
  throw StateError(
    'Image is too large after compression. Choose a smaller photo.',
  );
}
