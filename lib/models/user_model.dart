import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String email;
  final String role; // "student" | "admin"

  // These are created when the user account is created.
  // They should always have values.
  final DateTime createdAt;
  final DateTime updatedAt;

  // These are optional profile fields.
  // They may initially be null/absent and are filled in through Edit Profile.
  final DateTime? birthday;
  final String? university;
  final String? college; // department
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

      // These should already exist in the database.
      // The fallback prevents a crash if an older document happens
      // to be missing one of them.
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),

      updatedAt:
          (data['updated_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),

      // Optional profile fields.
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

      // These are existing account timestamps.
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),

      // Optional profile fields are allowed to be null.
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

  /// Creates a copy of this user.
  ///
  /// The clearX parameters allow nullable profile fields
  /// to intentionally be changed to null.
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

      // Name is editable.
      name: name ?? this.name,

      // These account fields remain unchanged.
      email: email,
      role: role,
      createdAt: createdAt,

      // updatedAt can be supplied, otherwise keep the current value.
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