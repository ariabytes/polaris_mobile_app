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

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'role': role,

      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),

      'birthday': birthday != null
          ? Timestamp.fromDate(birthday!)
          : null,

      'university': university,
      'college': college,
      'program': program,
      'year_level': yearLevel,
      'bio': bio,
      'profile_photo': profilePhoto,
    };
  }

  UserModel copyWith({
    String? name,

    DateTime? birthday,
    bool clearBirthday = false,

    String? university,
    bool clearUniversity = false,

    String? college,
    bool clearCollege = false,

    String? program,
    bool clearProgram = false,

    String? yearLevel,
    bool clearYearLevel = false,

    String? bio,
    bool clearBio = false,

    Map<String, dynamic>? profilePhoto,
    bool clearProfilePhoto = false,

    DateTime? updatedAt,
  }) {
    return UserModel(
      userId: userId,

      name: name ?? this.name,

      email: email,
      role: role,
      createdAt: createdAt,

      updatedAt: updatedAt ?? this.updatedAt,

      birthday: clearBirthday
          ? null
          : birthday ?? this.birthday,

      university: clearUniversity
          ? null
          : university ?? this.university,

      college: clearCollege
          ? null
          : college ?? this.college,

      program: clearProgram
          ? null
          : program ?? this.program,

      yearLevel: clearYearLevel
          ? null
          : yearLevel ?? this.yearLevel,

      bio: clearBio
          ? null
          : bio ?? this.bio,

      profilePhoto: clearProfilePhoto
          ? null
          : profilePhoto ?? this.profilePhoto,
    );
  }
}