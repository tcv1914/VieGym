import '../../../../core/format/date_format.dart';

/// docs/05 §10. Số liệu do server tính từ snapshot lúc thêm món (NUT-BR04/05); app chỉ hiển thị
/// và xem trước, không tự cộng tổng để lưu.
enum MealType {
  breakfast('BREAKFAST', 'Bữa sáng'),
  lunch('LUNCH', 'Bữa trưa'),
  dinner('DINNER', 'Bữa tối'),
  snack('SNACK', 'Bữa phụ');

  const MealType(this.code, this.label);

  final String code;
  final String label;

  static MealType fromCode(String code) =>
      values.firstWhere((t) => t.code == code);
}

double _num(Object? v) => (v as num).toDouble();
double? _numOrNull(Object? v) => v == null ? null : (v as num).toDouble();

class Nutrients {
  const Nutrients({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  static const zero = Nutrients(kcal: 0, protein: 0, carbs: 0, fat: 0);

  factory Nutrients.fromJson(Map<String, dynamic> json) => Nutrients(
    kcal: _num(json['kcal']),
    protein: _num(json['proteinG']),
    carbs: _num(json['carbsG']),
    fat: _num(json['fatG']),
  );

  static Nutrients? fromJsonOrNull(Object? json) =>
      json == null ? null : Nutrients.fromJson(json as Map<String, dynamic>);

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.mealType,
    required this.servingDescription,
    this.servingSize,
    this.servingUnit,
    required this.servings,
    required this.perServing,
    required this.total,
    required this.dataQuality,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
    id: json['id'] as String,
    foodId: json['foodId'] as String,
    foodName: json['foodName'] as String,
    mealType: MealType.fromCode(json['mealType'] as String),
    servingDescription: json['servingDescription'] as String,
    servingSize: _numOrNull(json['servingSize']),
    servingUnit: json['servingUnit'] as String?,
    servings: _num(json['servings']),
    perServing: Nutrients(
      kcal: _num(json['kcalPerServing']),
      protein: _num(json['proteinPerServingG']),
      carbs: _num(json['carbsPerServingG']),
      fat: _num(json['fatPerServingG']),
    ),
    total: Nutrients(
      kcal: _num(json['kcal']),
      protein: _num(json['proteinG']),
      carbs: _num(json['carbsG']),
      fat: _num(json['fatG']),
    ),
    dataQuality: json['dataQuality'] as String,
  );

  final String id;
  final String foodId;

  /// Tên lúc thêm; món bị đổi tên/ẩn sau đó vẫn hiện tên này (NUT-BR06).
  final String foodName;
  final MealType mealType;
  final String servingDescription;
  final double? servingSize;
  final String? servingUnit;
  final double servings;

  /// Snapshot một khẩu phần lúc thêm.
  final Nutrients perServing;

  /// servings × [perServing], server đã làm tròn.
  final Nutrients total;
  final String dataQuality;
}

class MealPlan {
  const MealPlan({
    required this.date,
    required this.entryCount,
    required this.meals,
    required this.mealTotals,
    required this.totals,
    this.targets,
    this.remaining,
    this.targetsCalculatedAt,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final meals = json['meals'] as Map<String, dynamic>;
    final mealTotals = json['mealTotals'] as Map<String, dynamic>;
    return MealPlan(
      date: parseIsoDate(json['date'] as String),
      entryCount: json['entryCount'] as int,
      meals: {
        for (final t in MealType.values)
          t: ((meals[t.code] as List?) ?? const [])
              .map((e) => MealEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
      },
      mealTotals: {
        for (final t in MealType.values)
          t: Nutrients.fromJsonOrNull(mealTotals[t.code]) ?? Nutrients.zero,
      },
      totals: Nutrients.fromJson(json['totals'] as Map<String, dynamic>),
      targets: Nutrients.fromJsonOrNull(json['targets']),
      remaining: Nutrients.fromJsonOrNull(json['remaining']),
      targetsCalculatedAt: json['targetsCalculatedAt'] == null
          ? null
          : DateTime.parse(json['targetsCalculatedAt'] as String).toLocal(),
    );
  }

  final DateTime date;
  final int entryCount;
  final Map<MealType, List<MealEntry>> meals;
  final Map<MealType, Nutrients> mealTotals;
  final Nutrients totals;

  /// null khi chưa có hồ sơ sức khỏe (UC07-A8): không có cơ sở so sánh, KHÔNG phải 0 kcal.
  final Nutrients? targets;

  /// Âm = vượt mục tiêu (A7).
  final Nutrients? remaining;

  /// Mục tiêu là mục tiêu hiện tại, tính lúc này (NUT-BR09), kể cả khi xem ngày cũ.
  final DateTime? targetsCalculatedAt;
}

/// BR-N02: > 0, ≤ 20, tối đa 2 chữ số lẻ. Nhận "1,5" hoặc "1.5". Sai → null.
double? parseServings(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,2}(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final value = double.parse(normalized);
  if (value <= 0 || value > 20) return null;
  return value;
}

/// Xem trước trên app trước khi lưu; số chính thức là của server sau khi lưu.
double previewKcal(double servings, double kcalPerServing) =>
    (servings * kcalPerServing * 100).roundToDouble() / 100;
