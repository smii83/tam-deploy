/// Strongly-typed User Model for TAM Platform
class UserModel {
  final String id;
  final String firebaseUid;
  final String name;
  final String email;
  final int grade;
  final String section;
  final String country;
  final String lang;
  final bool isSubscribed;
  final bool isBlocked;

  const UserModel({
    required this.id,
    required this.firebaseUid,
    required this.name,
    required this.email,
    this.grade = 12,
    this.section = 'scientific',
    this.country = 'kw',
    this.lang = 'ar',
    this.isSubscribed = false,
    this.isBlocked = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return UserModel(
      id: docId ?? (map['id'] as String? ?? ''),
      firebaseUid: (map['firebase_uid'] as String? ?? map['id'] as String? ?? ''),
      name: (map['name'] as String? ?? '').trim(),
      email: (map['email'] as String? ?? '').trim(),
      grade: (map['grade'] as num?)?.toInt() ?? 12,
      section: map['section'] as String? ?? 'scientific',
      country: map['country'] as String? ?? 'kw',
      lang: map['lang'] as String? ?? 'ar',
      isSubscribed: map['is_subscribed'] == true,
      isBlocked: map['is_blocked'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'name': name,
      'email': email,
      'grade': grade,
      'section': section,
      'country': country,
      'lang': lang,
      'is_subscribed': isSubscribed,
      'is_blocked': isBlocked,
    };
  }
}
