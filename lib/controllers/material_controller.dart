import 'package:flutter/foundation.dart';
import '../models/material_model.dart';
import '../services/material_service.dart';

/// Reads: pass-through Stream getters — the View wires these straight into
/// a StreamBuilder, no local list caching needed.
/// Writes: own isSaving/errorMessage so forms can show progress + failures.
class MaterialController extends ChangeNotifier {
  final MaterialService _service;

  MaterialController({MaterialService? service}) : _service = service ?? MaterialService();

  bool _isSaving = false;
  String? _errorMessage;

  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  // ---------- READS ----------
  Stream<List<MaterialModel>> myMaterials(String ownerId) => _service.streamMyMaterials(ownerId);

  Stream<List<MaterialModel>> publicMaterials({String? course, String? university}) =>
      _service.streamPublicMaterials(course: course, university: university);

  Stream<MaterialModel?> material(String materialId) => _service.streamMaterial(materialId);

  // ---------- WRITES ----------
  Future<bool> createMaterial({
    required String ownerId,
    required String title,
    String? description,
    required String content,
    required String university,
    required String college,
    required String course,
    required String semester,
    required String schoolYear,
    String? professor,
    required String visibility,
    double? price,
  }) async {
    _startSaving();
    try {
      await _service.createMaterial(
        ownerId: ownerId,
        title: title,
        description: description,
        content: content,
        university: university,
        college: college,
        course: course,
        semester: semester,
        schoolYear: schoolYear,
        professor: professor,
        visibility: visibility,
        price: price,
      );
      _finishSaving();
      return true;
    } catch (_) {
      _failSaving('Could not save your material. Please try again.');
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

  /// Fire-and-forget — a view count bump shouldn't block the UI or show
  /// a loading spinner.
  void registerView(String materialId) {
    _service.incrementViewCount(materialId);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
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