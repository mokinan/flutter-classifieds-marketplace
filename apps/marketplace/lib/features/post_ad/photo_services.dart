import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Where listing photos come from. Behind an interface so tests and the
/// screenshot run can supply photos without the system picker.
abstract interface class PhotoSource {
  Future<List<Uint8List>> pick({required int max});
}

class GalleryPhotoSource implements PhotoSource {
  GalleryPhotoSource([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<Uint8List>> pick({required int max}) async {
    final files = await _picker.pickMultiImage(limit: max);
    return [for (final f in files.take(max)) await f.readAsBytes()];
  }
}

/// Shrinks photos before upload — phone cameras produce 4–12 MB images,
/// which would make uploads slow and expensive on mobile data.
abstract interface class ImageCompressor {
  Future<Uint8List> compress(Uint8List bytes);
}

class JpegCompressor implements ImageCompressor {
  const JpegCompressor({this.maxDimension = 1600, this.quality = 80});

  final int maxDimension;
  final int quality;

  @override
  Future<Uint8List> compress(Uint8List bytes) => FlutterImageCompress.compressWithList(
    bytes,
    minWidth: maxDimension,
    minHeight: maxDimension,
    quality: quality,
  );
}

final photoSourceProvider = Provider<PhotoSource>((ref) => GalleryPhotoSource());
final imageCompressorProvider = Provider<ImageCompressor>((ref) => const JpegCompressor());
