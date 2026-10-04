import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../models/material_model.dart';
import '../services/material_service.dart';
import '../services/storage_service.dart';

class MaterialController extends ChangeNotifier {
  final MaterialService _service;
  final StorageService _storage = StorageService();

  MaterialController({MaterialService? service}) : _service = service ?? MaterialService();

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  // ---------- READS ----------
  Stream<List<MaterialModel>> myMaterials(String ownerId) => _service.streamMyMaterials(ownerId);

  Stream<List<MaterialModel>> publicMaterials({String? program, String? course, String? university}) =>
      _service.streamPublicMaterials(program: program, course: course, university: university);

  Stream<MaterialModel?> material(String materialId) => _service.streamMaterial(materialId);

  // ---------- WRITES ----------
  Future<String?> createMaterial({
    required String ownerId,
    required String title,
    String? description,
    required String content,
    required String university,
    required String college,
    required String program,
    required String course,
    required String semester,
    required String schoolYear,
    String? professor,
    required String visibility,
    double? price,
  }) async {
    _startSaving();
    try {
      final newId = await _service.createMaterial(
        ownerId: ownerId,
        title: title,
        description: description,
        content: content,
        university: university,
        college: college,
        program: program,
        course: course,
        semester: semester,
        schoolYear: schoolYear,
        professor: professor,
        visibility: visibility,
        price: price,
      );
      _finishSaving();
      return newId;
    } catch (_) {
      _failSaving('Could not save your material. Please try again.');
      return null;
    }
  }

  Future<bool> uploadCoverImage(String materialId, File file, String originalFilename) async {
    _startSaving();
    try {
      final result = await _storage.uploadFile(
        file: file,
        originalFilename: originalFilename,
        folder: 'materials/covers',
        resourceType: CloudinaryResourceType.Image,
        useRestrictedPreset: false, 
      );
      await _service.setCoverImage(materialId, result);
      _finishSaving();
      return true;
    } catch (_) {
      _failSaving('Could not upload cover image. Please try again.');
      return false;
    }
  }

  Future<bool> uploadAttachment({
    required String materialId,
    required File file,
    required String originalFilename,
    required String visibility,
    required CloudinaryResourceType resourceType,
  }) async {
    _startSaving();
    try {
      final isSensitive = visibility == 'private' || visibility == 'public_paid';
      final result = await _storage.uploadFile(
        file: file,
        originalFilename: originalFilename,
        folder: isSensitive ? 'materials/attachments_restricted' : 'materials/attachments_public',
        resourceType: resourceType,
        useRestrictedPreset: isSensitive,
      );
      await _service.addAttachment(materialId, result);
      _finishSaving();
      return true;
    } catch (_) {
      _failSaving('Could not upload attachment. Please try again.');
      return false;
    }
  }

  Future<bool> updateMaterial(String materialId, Map<String, dynamic> fields) async {
    _startSaving();
    try {
      await _service.updateMaterial(materialId, fields);
      _finishSaving();
      return true;
    } catch (_) {
      _failSaving('Could not update your material. Please try again.');
      return false;
    }
  }

  Future<bool> removeMaterial(String materialId) async {
    _startSaving();
    try {
      await _service.removeMaterial(materialId);
      _finishSaving();
      return true;
    } catch (_) {
      _failSaving('Could not remove this material. Please try again.');
      return false;
    }
  }

  Future<Map<String, List<String>>> courseSuggestions(String university) async {
    try {
      return await _service.fetchCourseSuggestions(university);
    } catch (_) {
      return {};
    }
  }

  void registerView(String materialId) {
    _service.incrementViewCount(materialId);
  }

  // ---------- ADMIN ----------
  Stream<List<MaterialModel>> allMaterialsAdmin() => _service.streamAllMaterialsAdmin();

  Future<bool> deleteMaterialPermanently(String materialId) async {
    _startSaving();
    try {
      await _service.hardDeleteMaterial(materialId);
      _finishSaving();
      return true;
    } catch (_) {
      _failSaving('Could not delete this material. Please try again.');
      return false;
    }
  }

  void _startSaving() {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _finishSaving() {
    _isSaving = false;
    notifyListeners();
  }

  void _failSaving(String message) {
    _isSaving = false;
    _errorMessage = message;
    notifyListeners();
  }
}