/// Strongly-typed Lesson Model for TAM Platform
class LessonModel {
  final String id;
  final String subjectId;
  final String titleAr;
  final String titleEn;
  final String videoUrl;
  final int durationMin;
  final int sortOrder;
  final bool isActive;

  const LessonModel({
    required this.id,
    required this.subjectId,
    required this.titleAr,
    this.titleEn = '',
    this.videoUrl = '',
    this.durationMin = 0,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory LessonModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return LessonModel(
      id: docId ?? (map['id'] as String? ?? ''),
      subjectId: map['subject_id'] as String? ?? '',
      titleAr: (map['title_ar'] as String? ?? map['name'] as String? ?? ''),
      titleEn: map['title_en'] as String? ?? '',
      videoUrl: map['video_url'] as String? ?? '',
      durationMin: (map['duration_min'] as num?)?.toInt() ?? 0,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'title_ar': titleAr,
      'name': titleAr,
      'title_en': titleEn,
      'video_url': videoUrl,
      'duration_min': durationMin,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}
