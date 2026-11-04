/// docs/05 §9. Mọi số dinh dưỡng là của MỘT khẩu phần [FoodSummary.servingDescription];
/// không phải /100 g (nguồn không ghi khối lượng phần → [FoodSummary.servingSize] null).
class FoodOption {
  const FoodOption({required this.code, required this.name});

  factory FoodOption.fromJson(Map<String, dynamic> json) =>
      FoodOption(code: json['code'] as String, name: json['name'] as String);

  final String code;
  final String name;
}

double _num(Object? v) => (v as num).toDouble();
double? _numOrNull(Object? v) => v == null ? null : (v as num).toDouble();

class FoodSummary {
  const FoodSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    this.region,
    required this.servingDescription,
    this.servingSize,
    this.servingUnit,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.dataQuality,
    this.imageUrl,
  });

  factory FoodSummary.fromJson(Map<String, dynamic> json) => FoodSummary(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    category: FoodOption.fromJson(json['category'] as Map<String, dynamic>),
    region: json['region'] == null
        ? null
        : FoodOption.fromJson(json['region'] as Map<String, dynamic>),
    servingDescription: json['servingDescription'] as String,
    servingSize: _numOrNull(json['servingSize']),
    servingUnit: json['servingUnit'] as String?,
    kcal: _num(json['kcalPerServing']),
    protein: _num(json['proteinPerServing']),
    carbs: _num(json['carbsPerServing']),
    fat: _num(json['fatPerServing']),
    dataQuality: json['dataQuality'] as String,
    imageUrl: json['imageUrl'] as String?,
  );

  final String id;

  /// Mã nguồn (vd. VPF-000272), giúp phân biệt các món trùng tên.
  final String code;
  final String name;
  final FoodOption category;

  /// Vùng đo của nguồn; cùng tên ở vùng khác là phần ăn khác.
  final FoodOption? region;
  final String servingDescription;
  final double? servingSize;
  final String? servingUnit;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// SOURCED / ESTIMATED / DEMO.
  final String dataQuality;
  final String? imageUrl;
}

class FoodDetail {
  const FoodDetail({
    required this.summary,
    this.nameEn,
    required this.source,
    this.sourceUrl,
    required this.revision,
  });

  factory FoodDetail.fromJson(Map<String, dynamic> json) => FoodDetail(
    summary: FoodSummary.fromJson(json),
    nameEn: json['nameEn'] as String?,
    source: json['source'] as String,
    sourceUrl: json['sourceUrl'] as String?,
    revision: json['revision'] as int,
  );

  final FoodSummary summary;
  final String? nameEn;
  final String source;
  final String? sourceUrl;
  final int revision;
}

class FoodPage {
  const FoodPage({
    required this.items,
    required this.totalItems,
    required this.hasNext,
  });

  factory FoodPage.fromJson(Map<String, dynamic> json) => FoodPage(
    items: (json['items'] as List)
        .map((e) => FoodSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalItems: json['totalItems'] as int,
    hasNext: json['hasNext'] as bool,
  );

  final List<FoodSummary> items;
  final int totalItems;
  final bool hasNext;
}

class FoodFilters {
  const FoodFilters({required this.categories, required this.regions});

  factory FoodFilters.fromJson(Map<String, dynamic> json) => FoodFilters(
    categories: (json['categories'] as List)
        .map((e) => FoodOption.fromJson(e as Map<String, dynamic>))
        .toList(),
    regions: (json['regions'] as List)
        .map((e) => FoodOption.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final List<FoodOption> categories;
  final List<FoodOption> regions;

  String categoryLabel(String code) =>
      categories.where((c) => c.code == code).firstOrNull?.name ?? code;

  String regionLabel(String code) =>
      regions.where((r) => r.code == code).firstOrNull?.name ?? code;
}

class FoodQuery {
  const FoodQuery({this.keyword = '', this.category, this.region});

  final String keyword;
  final String? category;
  final String? region;

  int get filterCount => [category, region].where((v) => v != null).length;

  bool get isEmpty => keyword.trim().isEmpty && filterCount == 0;

  FoodQuery withKeyword(String value) =>
      FoodQuery(keyword: value, category: category, region: region);

  FoodQuery withFilters({String? category, String? region}) =>
      FoodQuery(keyword: keyword, category: category, region: region);

  Map<String, String> toQueryParameters({
    required int page,
    required int size,
  }) => {
    if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    'category': ?category,
    'region': ?region,
    'page': '$page',
    'size': '$size',
  };

  @override
  bool operator ==(Object other) =>
      other is FoodQuery &&
      other.keyword.trim() == keyword.trim() &&
      other.category == category &&
      other.region == region;

  @override
  int get hashCode => Object.hash(keyword.trim(), category, region);
}

/// Nhãn chất lượng dữ liệu cho người dùng.
String dataQualityLabel(String code) => switch (code) {
  'SOURCED' => 'Theo nguồn công bố',
  'ESTIMATED' => 'Ước tính',
  'DEMO' => 'Dữ liệu minh họa',
  _ => code,
};
