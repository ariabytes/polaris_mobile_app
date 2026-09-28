import 'package:cloud_firestore/cloud_firestore.dart';

class MaterialModel {
  final String materialId;
  final String ownerId;
  final String title;
  final String? description;
  final String content; // markdown
  final String university;
  final String college;
  final String program; // degree program, e.g. "BS Information Technology"
  final String course; // subject/class, e.g. "Data Structures and Algorithms"
  final String semester;
  final String schoolYear;
  final String? professor;
  final String visibility; // "private" | "public_free" | "public_paid"
  final String status; // "active" | "removed"
  final double? price;
  final int viewCount;
  final int purchaseCount;
  final Map<String, dynamic>? coverImage; // {public_id, format}
  final List<Map<String, dynamic>> attachments;
  // each: {public_id, resource_type, format, original_filename, size_bytes, uploaded_at}
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MaterialModel({
    required this.materialId,
    required this.ownerId,
    required this.title,
    this.description,
    required this.content,
    required this.university,
    required this.college,
    required this.program,
    required this.course,
    required this.semester,
    required this.schoolYear,
    this.professor,
    this.visibility = 'private',
    this.status = 'active',
    this.price,
    this.viewCount = 0,
    this.purchaseCount = 0,
    this.coverImage,
    this.attachments = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isPrivate => visibility == 'private';
  bool get isPublicFree => visibility == 'public_free';
  bool get isPublicPaid => visibility == 'public_paid';
  bool get isActive => status == 'active';
  bool get needsRestrictedStorage => visibility == 'private' || visibility == 'public_paid';

  factory MaterialModel.fromMap(String docId, Map<String, dynamic> data) {
    return MaterialModel(
      materialId: docId,
      ownerId: data['owner_id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      content: data['content'] ?? '',
      university: data['university'] ?? '',
      college: data['college'] ?? '',
      program: data['program'] ?? '',
      course: data['course'] ?? '',
      semester: data['semester'] ?? '',
      schoolYear: data['school_year'] ?? '',
      professor: data['professor'],
      visibility: data['visibility'] ?? 'private',
      status: data['status'] ?? 'active',
      price: (data['price'] as num?)?.toDouble(),
      viewCount: (data['view_count'] as num?)?.toInt() ?? 0,
      purchaseCount: (data['purchase_count'] as num?)?.toInt() ?? 0,
      coverImage: data['cover_image'] as Map<String, dynamic>?,
      attachments: (data['attachments'] as List<dynamic>?)
              ?.map((a) => Map<String, dynamic>.from(a as Map))
              .toList() ??
          [],
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'material_id': materialId,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'content': content,
      'university': university,
      'college': college,
      'program': program,
      'course': course,
      'semester': semester,
      'school_year': schoolYear,
      'professor': professor,
      'visibility': visibility,
      'status': status,
      'price': visibility == 'public_paid' ? price : null,
      'view_count': viewCount,
      'purchase_count': purchaseCount,
      'cover_image': coverImage,
      'attachments': attachments,
      'created_at':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}