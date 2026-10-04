import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/material_model.dart';

class MaterialService {
  final CollectionReference<Map<String, dynamic>> _materials =
      FirebaseFirestore.instance.collection('materials');

  // ---------- CREATE ----------
  Future<String> createMaterial({
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
    final docRef = _materials.doc();
    final material = MaterialModel(
      materialId: docRef.id,
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

  Future<void> setCoverImage(String materialId, Map<String, dynamic> coverImage) async {
    await updateMaterial(materialId, {'cover_image': coverImage});
  }

  Future<void> addAttachment(String materialId, Map<String, dynamic> attachment) async {
    await _materials.doc(materialId).update({
      'attachments': FieldValue.arrayUnion([
        {...attachment, 'uploaded_at': Timestamp.now()},
      ]),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ---------- SOFT DELETE ----------
  Future<void> removeMaterial(String materialId) async {
    await _materials.doc(materialId).update({
      'status': 'removed',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementViewCount(String materialId) async {
    await _materials.doc(materialId).update({'view_count': FieldValue.increment(1)});
  }

  //  ADMIN DELETE ----------
  Future<void> hardDeleteMaterial(String materialId) async {
    await _materials.doc(materialId).delete();
  }

  //  READS ----------
  Stream<List<MaterialModel>> streamMyMaterials(String ownerId) {
    return _materials
        .where('owner_id', isEqualTo: ownerId)
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MaterialModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<MaterialModel>> streamPublicMaterials({
    String? program,
    String? course,
    String? university,
  }) {
    Query<Map<String, dynamic>> query = _materials
        .where('status', isEqualTo: 'active')
        .where('visibility', whereIn: ['public_free', 'public_paid']);

    if (program != null && program.isNotEmpty) {
      query = query.where('program', isEqualTo: program);
    }
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

  Stream<List<MaterialModel>> streamAllMaterialsAdmin() {
    return _materials
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MaterialModel.fromMap(d.id, d.data())).toList());
  }

  Stream<MaterialModel?> streamMaterial(String materialId) {
    return _materials.doc(materialId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return MaterialModel.fromMap(doc.id, doc.data()!);
    });
  }

  bool canAccessContent(MaterialModel material, String? currentUserId, bool hasPurchased) {
    if (material.visibility == 'public_free') return true;
    if (material.ownerId == currentUserId) return true;
    if (material.visibility == 'public_paid' && hasPurchased) return true;
    return false;
  }

  Future<Map<String, List<String>>> fetchCourseSuggestions(String university) async {
    final snap = await _materials
        .where('university', isEqualTo: university)
        .where('status', isEqualTo: 'active')
        .where('visibility', whereIn: ['public_free', 'public_paid'])
        .limit(300)
        .get();

    final courseNames = <String, String>{};
    final professors = <String, Map<String, String>>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final course = (data['course'] as String? ?? '').trim();
      if (course.isEmpty) continue;

      final key = course.toLowerCase();
      courseNames.putIfAbsent(key, () => course);
      final profs = professors.putIfAbsent(key, () => {});

      final prof = (data['professor'] as String? ?? '').trim();
      if (prof.isNotEmpty) profs.putIfAbsent(prof.toLowerCase(), () => prof);
    }

    return {
      for (final key in courseNames.keys)
        courseNames[key]!: professors[key]!.values.toList(),
    };
  }
}