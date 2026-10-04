import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';

class StorageService {
  static const String _cloudName = 'kjpa6th0';

  final CloudinaryPublic _publicUploader = CloudinaryPublic(
    _cloudName,
    'Polaris Materials Public',
    cache: false,
  );

  final CloudinaryPublic _restrictedUploader = CloudinaryPublic(
    _cloudName,
    'Polaris Materials Restricted',
    cache: false,
  );

  Future<Map<String, dynamic>> uploadFile({
    required File file,
    required String originalFilename,
    required String folder,
    required CloudinaryResourceType resourceType,
    bool useRestrictedPreset = false,
  }) async {
    if (!await file.exists()) {
      throw Exception(
        'Selected file does not exist: ${file.path}',
      );
    }

    final uploader = useRestrictedPreset
        ? _restrictedUploader
        : _publicUploader;

    try {
      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        resourceType: resourceType,
        folder: folder,
      );

      final response = await uploader.uploadFile(cloudinaryFile);

      final rawData = response.data;

      final sizeValue = rawData['bytes'];

      final int sizeBytes;
      if (sizeValue is num) {
        sizeBytes = sizeValue.toInt();
      } else {
        sizeBytes = await file.length();
      }

      final String resourceTypeValue =
          resourceType == CloudinaryResourceType.Image
              ? 'image'
              : 'raw';

      final String url =
          (rawData['secure_url'] as String?) ??
          response.secureUrl;

      if (url.isEmpty) {
        throw Exception(
          'Cloudinary upload succeeded but returned an empty URL.',
        );
      }

      // Cloudinary's response often omits `format` for resource_type: raw
      // uploads (the common case for pdf/docx/pptx) — it mainly extracts
      // that metadata for images/video. Fall back to the original
      // filename's extension so downstream code (the document viewer,
      // file-type icons, etc.) always has something to key off of.
      String format = (rawData['format'] as String?)?.trim() ?? '';
      if (format.isEmpty) {
        final dotIndex = originalFilename.lastIndexOf('.');
        if (dotIndex != -1 && dotIndex < originalFilename.length - 1) {
          format = originalFilename.substring(dotIndex + 1).toLowerCase();
        }
      }

      return {
        'public_id': response.publicId,
        'format': format,
        'resource_type': resourceTypeValue,
        'original_filename': originalFilename,
        'size_bytes': sizeBytes,
        'url': url,
      };
    } catch (e) {
      throw Exception(
        'Cloudinary upload failed: $e',
      );
    }
  }
}