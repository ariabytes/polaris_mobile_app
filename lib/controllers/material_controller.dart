import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../models/material_model.dart';
import '../services/material_service.dart';
import '../services/storage_service.dart';

/// The details collected by MaterialDetailsSheet
class _Details {
  const _Details({
    required this.university,
    required this.college,
    required this.program,
    required this.course,
    required this.semester,
    required this.schoolYear,
    required this.professor,
    required this.visibility,
    required this.price,
  });

  final String university;
  final String college;
  final String program;
  final String course;
  final String semester;
  final String schoolYear;
  final String? professor;
  final String visibility;
  final double? price;
}

// Handles everything about study materials: reading, creating, editing, uploading files, and deleting.
class MaterialController extends ChangeNotifier {
  static const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  static const String _fileMaterialPlaceholder =
      '_This material is an uploaded file — see the attachment below._';

  final MaterialService _service;
  final StorageService _storage = StorageService();

  MaterialController({MaterialService? service}) : _service = service ?? MaterialService();

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  //  READS ----------
  Stream<List<MaterialModel>> myMaterials(String ownerId) => _service.streamMyMaterials(ownerId);

  Stream<List<MaterialModel>> publicMaterials({String? program, String? course, String? university}) =>
      _service.streamPublicMaterials(program: program, course: course, university: university);

  Stream<MaterialModel?> material(String materialId) => _service.streamMaterial(materialId);

  bool canAccess(MaterialModel material, String? currentUserId, bool hasPurchased) =>
      _service.canAccessContent(material, currentUserId, hasPurchased);

  //  CREATE ----------
  /// Creates a text (Markdown) material. 
  Future<String?> createTextMaterial({
    required String ownerId,
    required String title,
    String? description,
    required String content,
    required Map<String, String> details,
    File? cover,
    String? coverFilename,
  }) async {
    _startSaving();
    final d = _parseDetails(details);
    if (d == null) return null;

    try {
      final coverImage = cover == null
          ? null
          : await _uploadCover(cover, coverFilename ?? 'cover.jpg');

      final newId = await _service.createMaterial(
        ownerId: ownerId,
        title: title,
        description: description,
        content: content,
        university: d.university,
        college: d.college,
        program: d.program,
        course: d.course,
        semester: d.semester,
        schoolYear: d.schoolYear,
        professor: d.professor,
        visibility: d.visibility,
        price: d.price,
        coverImage: coverImage,
      );
      _finishSaving();
      return newId;
    } catch (_) {
      _failSaving('Could not save your material. Please try again.');
      return null;
    }
  }

  // Material from uploaded file or attachment. file is uploaded first before creating a material record if its uploaded correctly
  Future<String?> createFileMaterial({
    required String ownerId,
    required String title,
    required File file,
    required String filename,
    required Map<String, String> details,
  }) async {
    _startSaving();
    final d = _parseDetails(details);
    if (d == null) return null;

    try {
      final extension = filename.contains('.')
          ? filename.split('.').last.toLowerCase()
          : '';
      final isSensitive = d.visibility != 'public_free';

      final attachment = await _storage.uploadFile(
        file: file,
        originalFilename: filename,
        folder: isSensitive ? 'materials/attachments_restricted' : 'materials/attachments_public',
        resourceType: _imageExtensions.contains(extension)
            ? CloudinaryResourceType.Image
            : CloudinaryResourceType.Raw,
        useRestrictedPreset: isSensitive,
      );

      final newId = await _service.createMaterial(
        ownerId: ownerId,
        title: title,
        content: _fileMaterialPlaceholder,
        university: d.university,
        college: d.college,
        program: d.program,
        course: d.course,
        semester: d.semester,
        schoolYear: d.schoolYear,
        professor: d.professor,
        visibility: d.visibility,
        price: d.price,
        attachments: [attachment],
      );
      _finishSaving();
      return newId;
    } catch (_) {
      _failSaving('Could not upload your file. Please try again.');
      return null;
    }
  }

  //  UPDATE ----------
  Future<bool> uploadCoverImage(String materialId, File file, String originalFilename) async {
    _startSaving();
    try {
      final result = await _uploadCover(file, originalFilename);
      await _service.setCoverImage(materialId, result);
      _finishSaving();
      return true;
    } catch (_) {
      _failSaving('Could not upload cover image. Please try again.');
      return false;
    }
  }

  /// Updates title / description / content.
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

  /// Updates the school details / visibility / price from MaterialDetailsSheet.
  Future<bool> updateDetails(MaterialModel material, Map<String, String> details) async {
    _startSaving();
    final d = _parseDetails(details, fallbackVisibility: material.visibility);
    if (d == null) return false;

    try {
      await _service.updateMaterial(material.materialId, {
        'university': d.university,
        'college': d.college,
        'program': d.program,
        'course': d.course,
        'semester': d.semester,
        'school_year': d.schoolYear,
        'professor': d.professor,
        'visibility': d.visibility,
        'price': d.price,
      });
      _finishSaving();
      return true;
    } catch (_) {
      _failSaving('Could not update material details. Please try again.');
      return false;
    }
  }

  //  DELETE ----------

  /// Soft delete for students - the material is hidden but past transactions still reference it.
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

  // MISC ----------
  Future<Map<String, List<String>>> courseSuggestions(String university) async {
    try {
      return await _service.fetchCourseSuggestions(university);
    } catch (_) {
      return {};
    }
  }

  /// university -> college -> programs, for the profile form's suggestions.
  Future<Map<String, Map<String, List<String>>>> academicSuggestions() async {
    try {
      return await _service.fetchAcademicSuggestions();
    } catch (_) {
      return {};
    }
  }

  void registerView(String materialId) {
    _service.incrementViewCount(materialId);
  }

  //  ADMIN ----------
  Stream<List<MaterialModel>> allMaterialsAdmin() => _service.streamAllMaterialsAdmin();

  /// Admin only - permanently deletes the material document.
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

  //  PRIVATE HELPERS ----------

  Future<Map<String, dynamic>> _uploadCover(File file, String filename) {
    return _storage.uploadFile(
      file: file,
      originalFilename: filename,
      folder: 'materials/covers',
      resourceType: CloudinaryResourceType.Image,
      useRestrictedPreset: false,
    );
  }

  _Details? _parseDetails(Map<String, String> d, {String fallbackVisibility = 'private'}) {
    final visibility = d['visibility'] ?? fallbackVisibility;

    double? price;
    if (visibility == 'public_paid') {
      price = double.tryParse((d['price'] ?? '').trim());
      if (price == null || price <= 0) {
        _failSaving('Please enter a valid price greater than zero.');
        return null;
      }
    }

    final professor = (d['professor'] ?? '').trim();

    return _Details(
      university: (d['university'] ?? '').trim(),
      college: (d['college'] ?? '').trim(),
      program: (d['program'] ?? '').trim(),
      course: (d['course'] ?? '').trim(),
      semester: d['semester'] ?? '',
      schoolYear: (d['schoolYear'] ?? '').trim(),
      professor: professor.isEmpty ? null : professor,
      visibility: visibility,
      price: price,
    );
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