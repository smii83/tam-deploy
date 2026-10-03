/// Strongly-typed PDF Model for TAM Platform
class PdfModel {
  final String id;
  final String subjectId;
  final String titleAr;
  final String titleEn;
  final String pdfType; // 'summary' | 'exam_answer' | 'worksheet'
  final String fileUrl;
  final bool isActive;

  const PdfModel({
    required this.id,
    required this.subjectId,
    required this.titleAr,
    this.titleEn = '',
    this.pdfType = 'summary',
    this.fileUrl = '',
    this.isActive = true,
  });

  factory PdfModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return PdfModel(
      id: docId ?? (map['id'] as String? ?? ''),
      subjectId: map['subject_id'] as String? ?? '',
      titleAr: (map['title_ar'] as String? ?? map['name'] as String? ?? ''),
      titleEn: map['title_en'] as String? ?? '',
      pdfType: map['pdf_type'] as String? ?? 'summary',
      fileUrl: (map['file_url'] ?? map['file_data'] ?? map['file'] ?? '').toString(),
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
      'pdf_type': pdfType,
      'file_url': fileUrl,
      'is_active': isActive,
    };
  }
}
