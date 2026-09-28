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

  /// Cloudinary storage note: changing visibility here does NOT move or
  /// re-flag the underlying Cloudinary asset (it stays under whichever
  /// preset — Public/Restricted — it was originally uploaded with).
  /// Access is actually enforced by MaterialService/StorageService checking
  /// this `visibility` field (plus ownership/purchase records) before ever
  /// handing back a usable file URL. See chat notes on this — it's a
  /// deliberate simplification, not an oversight.
  Future<void> updateVisibility(String materialId, String newVisibility) async {
    await updateMaterial(materialId, {'visibility': newVisibility});
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
  /// Materials are never hard-deleted (transactions may reference them) —
  /// flip status to "removed" instead, which every read query filters out.
  /// This is the OWNER-facing delete. See hardDeleteMaterial for the
  /// admin-facing one.
  Future<void> removeMaterial(String materialId) async {
    await _materials.doc(materialId).update({
      'status': 'removed',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> incrementViewCount(String materialId) async {
    await _materials.doc(materialId).update({'view_count': FieldValue.increment(1)});
  }

  // ---------- ADMIN HARD DELETE ----------
  /// ADMIN ONLY — actually deletes the Firestore document, unlike
  /// removeMaterial() which just flips status to "removed".
  ///
  /// Effects to be aware of:
  /// - Any existing transaction docs that reference this material_id keep
  ///   their own snapshot of price/buyer/seller, so no financial history is
  ///   lost. But streamMaterial(materialId) will return null afterwards, so
  ///   any screen that joins a transaction back to its material (e.g. "My
  ///   Purchases" showing the title/cover) needs to handle a null material
  ///   gracefully (e.g. "This material is no longer available").
  /// - This does NOT delete the Cloudinary cover image or attachments.
  ///   Cloudinary's destroy endpoint requires a signed request using your
  ///   API secret, which must never be shipped inside the Flutter client —
  ///   so without a backend (Cloud Function) those assets are simply
  ///   orphaned. Clean them up manually via the Cloudinary console if
  ///   storage usage matters to you.
  Future<void> hardDeleteMaterial(String materialId) async {
    await _materials.doc(materialId).delete();
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

  /// Public browse/search feed. program/course/university are optional
  /// exact-match filters — add more as your search UI needs them.
  /// NOTE: combining where() + whereIn() + orderBy() needs a Firestore
  /// composite index. Firestore will throw with a console link the first
  /// time you run this — just click it to auto-create the index.
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

  /// ADMIN ONLY — every material regardless of status ("removed" included)
  /// or visibility ("private" included). Pair with a Firestore rule
  /// restricting this query to users whose `users/{uid}.role == "admin"`;
  /// this client-side call has no gating of its own.
  Stream<List<MaterialModel>> streamAllMaterialsAdmin() {
    return _materials
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

  bool canAccessContent(MaterialModel material, String? currentUserId, bool hasPurchased) {
    if (material.visibility == 'public_free') return true;
    if (material.ownerId == currentUserId) return true;
    if (material.visibility == 'public_paid' && hasPurchased) return true;
    return false;
  }
}