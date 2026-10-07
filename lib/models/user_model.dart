import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String role; // "student" | "admin"
  final DateTime createdAt;
  final DateTime updatedAt;

  final DateTime? birthday;
  final String? university;
  final String? college; // department like CCE
  final String? program;
  final String? yearLevel;
  final String? bio;
  final Map<String, dynamic>? profilePhoto;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    this.role = 'student',
    required this.createdAt,
    required this.updatedAt,
    this.birthday,
    this.university,
    this.college,
    this.program,
    this.yearLevel,
    this.bio,
    this.profilePhoto,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromMap(
    String docId,
    Map<String, dynamic> data,
  ) {
    return UserModel(
      userId: docId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',

      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),

      updatedAt:
          (data['updated_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),

      birthday:
          (data['birthday'] as Timestamp?)?.toDate(),

      university: data['university'] as String?,
      college: data['college'] as String?,
      program: data['program'] as String?,
      yearLevel: data['year_level'] as String?,
      bio: data['bio'] as String?,

      profilePhoto: data['profile_photo'] != null
          ? Map<String, dynamic>.from(
              data['profile_photo'] as Map,
            )
          : null,
    );
  }
}