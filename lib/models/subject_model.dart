import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Strongly-typed Subject Model for TAM Platform
class SubjectModel {
  final String id;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String hexColor;
  final int sortOrder;
  final bool isVisible;

  const SubjectModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.icon = '📘',
    this.hexColor = '7C3AED',
    this.sortOrder = 0,
    this.isVisible = true,
  });

  /// Safely converts the subject hex string into a Flutter [Color]
  Color get color => AppTheme.parseColor(hexColor);

  factory SubjectModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return SubjectModel(
      id: docId ?? (map['id'] as String? ?? ''),
      nameAr: (map['name_ar'] as String? ?? map['ar'] as String? ?? ''),
      nameEn: (map['name_en'] as String? ?? map['en'] as String? ?? ''),
      icon: map['icon'] as String? ?? map['em'] as String? ?? '📘',
      hexColor: (map['color'] as String? ?? '7C3AED').replaceAll('#', ''),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isVisible: map['is_visible'] ?? true,
    );
  }

  Map<String, String> toAppMap() {
    return {
      'id': id,
      'ar': nameAr,
      'en': nameEn,
      'em': icon,
      'color': hexColor,
    };
  }

  Map<String, dynamic> toFirestoreMap(String gradeId) {
    return {
      'grade_id': gradeId,
      'name_ar': nameAr,
      'name_en': nameEn,
      'icon': icon,
      'color': hexColor,
      'sort_order': sortOrder,
      'is_visible': isVisible,
    };
  }
}
