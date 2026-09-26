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
      print('==========================================');
      print('CLOUDINARY UPLOAD');
      print('Cloud name: $_cloudName');
      print(
        'Preset: ${useRestrictedPreset ? "Polaris Material Restricted" : "Polaris Material Public"}',
      );
      print('File: ${file.path}');
      print('Filename: $originalFilename');
      print('Folder: $folder');
      print('Resource type: $resourceType');
      print('==========================================');

      final cloudinaryFile = CloudinaryFile.fromFile(
        file.path,
        resourceType: resourceType,
        folder: folder,
      );

      final response = await uploader.uploadFile(cloudinaryFile);

      final rawData = response.data;

      print('==========================================');
      print('CLOUDINARY SUCCESS');
      print('Public ID: ${response.publicId}');
      print('Secure URL: ${response.secureUrl}');
      print('Response data: $rawData');
      print('==========================================');

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

      return {
        'public_id': response.publicId,
        'format': rawData['format'] as String? ?? '',
        'resource_type': resourceTypeValue,
        'original_filename': originalFilename,
        'size_bytes': sizeBytes,
        'url': url,
      };
    } catch (e, stackTrace) {
      print('==========================================');
      print('CLOUDINARY UPLOAD ERROR');
      print('ERROR TYPE: ${e.runtimeType}');
      print('ERROR: $e');

      if (e is Exception) {
        print('EXCEPTION: $e');
      }

      print('STACK TRACE:');
      print(stackTrace);
      print('==========================================');

      throw Exception(
        'Cloudinary upload failed: $e',
      );
    }
  }
}