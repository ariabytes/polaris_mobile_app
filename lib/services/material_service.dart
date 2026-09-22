import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/material_model.dart';

/// Talks to the `materials` collection only. Read methods return Streams
/// for real-time updates; write methods throw on failure so the Controller
/// can show a specific reason instead of a generic "something went wrong".
class MaterialService {
  final CollectionReference<Map<String, dynamic>> _materials =
      FirebaseFirestore.instance.collection('materials');

  // ---------- CREATE ----------
  /// Returns the new material's ID on success.
  Future<String> createMaterial({
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
    final docRef = _materials.doc();
    final material = MaterialModel(
      materialId: docRef.id,
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
      status: 'active',
      price: price,
    );
    await docRef.set(material.toMap());
    return docRef.id;
  }

  // ---------- UPDATE ----------
  Future<void> updateMaterial(String materialId, Map<String, dynamic> fields) async {
    await _materials.doc(materialId).update({
      ...fields,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ---------- SOFT DELETE ----------
  /// Materials are never hard-deleted (transactions may reference them) —
  /// flip status to "removed" instead, which every read query filters out.
  Future<void> removeMaterial(String materialId) async {
    await _materials.doc(materialId).update({
      'status': 'removed',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementViewCount(String materialId) async {
    await _materials.doc(materialId).update({'view_count': FieldValue.increment(1)});
  }

  // ---------- READS (Stream = real-time) ----------

  /// A single owner's own materials (includes private ones) — for "My Materials".
  Stream<List<MaterialModel>> streamMyMaterials(String ownerId) {
    return _materials
        .where('owner_id', isEqualTo: ownerId)
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MaterialModel.fromMap(d.id, d.data())).toList());
  }

  /// Public browse/search feed. course/university are optional exact-match
  /// filters — add more as your search UI needs them.
  /// NOTE: combining where() + whereIn() + orderBy() needs a Firestore
  /// composite index. Firestore will throw with a console link the first
  /// time you run this — just click it to auto-create the index.
  Stream<List<MaterialModel>> streamPublicMaterials({String? course, String? university}) {
    Query<Map<String, dynamic>> query = _materials
        .where('status', isEqualTo: 'active')
        .where('visibility', whereIn: ['public_free', 'public_paid']);

    if (course != null && course.isNotEmpty) {
      query = query.where('course', isEqualTo: course);
    }
    if (university != null && university.isNotEmpty) {
      query = query.where('university', isEqualTo: university);
    }

    return query
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MaterialModel.fromMap(d.id, d.data())).toList());
  }

  /// Single material, real-time — for the detail page (view/purchase counts
  /// update live if someone else is looking at the same material).
  Stream<MaterialModel?> streamMaterial(String materialId) {
    return _materials.doc(materialId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return MaterialModel.fromMap(doc.id, doc.data()!);
    });
  }
}