/// Mã danh mục là chuỗi từ backend (docs/05 §5); nhãn lấy từ GET /exercise-filters
/// để app không giữ một bộ danh mục thứ hai.
class FilterOption {
  const FilterOption(this.code, this.name);

  factory FilterOption.fromJson(Map<String, dynamic> json) =>
      FilterOption(json['code'] as String, json['name'] as String);

  final String code;
  final String name;
}

class ExerciseFilters {
  const ExerciseFilters({
    required this.muscleGroups,
    required this.equipment,
    required this.difficulties,
  });

  factory ExerciseFilters.fromJson(Map<String, dynamic> json) {
    List<FilterOption> options(String key) => (json[key] as List)
        .map((e) => FilterOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return ExerciseFilters(
      muscleGroups: options('muscleGroups'),
      equipment: options('equipment'),
      difficulties: options('difficulties'),
    );
  }

  final List<FilterOption> muscleGroups;
  final List<FilterOption> equipment;
  final List<FilterOption> difficulties;

  static String _label(List<FilterOption> options, String code) =>
      options.where((o) => o.code == code).firstOrNull?.name ?? code;

  String muscleGroupLabel(String code) => _label(muscleGroups, code);
  String equipmentLabel(String code) => _label(equipment, code);
  String difficultyLabel(String code) => _label(difficulties, code);
}

/// Điều kiện tìm hiện tại. So sánh theo giá trị để biết truy vấn có thực sự đổi.
class ExerciseQuery {
  const ExerciseQuery({
    this.keyword = '',
    this.muscleGroup,
    this.equipment,
    this.difficulty,
  });

  final String keyword;
  final String? muscleGroup;
  final String? equipment;
  final String? difficulty;

  int get filterCount =>
      [muscleGroup, equipment, difficulty].where((v) => v != null).length;

  bool get isEmpty => keyword.trim().isEmpty && filterCount == 0;

  ExerciseQuery withKeyword(String value) => ExerciseQuery(
    keyword: value,
    muscleGroup: muscleGroup,
    equipment: equipment,
    difficulty: difficulty,
  );

  ExerciseQuery withFilters({
    String? muscleGroup,
    String? equipment,
    String? difficulty,
  }) => ExerciseQuery(
    keyword: keyword,
    muscleGroup: muscleGroup,
    equipment: equipment,
    difficulty: difficulty,
  );

  /// Bỏ tham số trống; backend tự chuẩn hóa keyword (trim, bỏ dấu).
  Map<String, String> toQueryParameters({
    required int page,
    required int size,
  }) => {
    if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
    'muscleGroup': ?muscleGroup,
    'equipment': ?equipment,
    'difficulty': ?difficulty,
    'page': '$page',
    'size': '$size',
  };

  @override
  bool operator ==(Object other) =>
      other is ExerciseQuery &&
      other.keyword.trim() == keyword.trim() &&
      other.muscleGroup == muscleGroup &&
      other.equipment == equipment &&
      other.difficulty == difficulty;

  @override
  int get hashCode =>
      Object.hash(keyword.trim(), muscleGroup, equipment, difficulty);
}

class ExerciseSummary {
  const ExerciseSummary({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.difficulty,
    this.thumbnailUrl,
  });

  factory ExerciseSummary.fromJson(Map<String, dynamic> json) =>
      ExerciseSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String,
        equipment: json['equipment'] as String,
        difficulty: json['difficulty'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );

  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String difficulty;
  final String? thumbnailUrl;
}

class ExercisePage {
  const ExercisePage({
    required this.items,
    required this.page,
    required this.totalItems,
    required this.hasNext,
  });

  factory ExercisePage.fromJson(Map<String, dynamic> json) => ExercisePage(
    items: (json['items'] as List)
        .map((e) => ExerciseSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    page: json['page'] as int,
    totalItems: json['totalItems'] as int,
    hasNext: json['hasNext'] as bool,
  );

  final List<ExerciseSummary> items;
  final int page;
  final int totalItems;
  final bool hasNext;
}

class ExerciseDetail {
  const ExerciseDetail({
    required this.summary,
    required this.steps,
    required this.commonMistakes,
    this.mediaType,
    this.mediaUrl,
    this.contentSource,
    this.mediaLicense,
  });

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) => ExerciseDetail(
    summary: ExerciseSummary.fromJson(json),
    steps: _lines(json['instructions'] as String),
    commonMistakes: _lines(json['commonMistakes'] as String? ?? ''),
    mediaType: json['mediaType'] as String?,
    mediaUrl: json['mediaUrl'] as String?,
    contentSource: json['contentSource'] as String?,
    mediaLicense: json['mediaLicense'] as String?,
  );

  final ExerciseSummary summary;
  final List<String> steps;
  final List<String> commonMistakes;

  /// IMAGE / GIF / VIDEO; ngày 6 mới hiển thị IMAGE và GIF.
  final String? mediaType;
  final String? mediaUrl;
  final String? contentSource;
  final String? mediaLicense;

  bool get hasImageMedia =>
      (mediaType == 'GIF' || mediaType == 'IMAGE') &&
      (mediaUrl?.isNotEmpty ?? false);

  /// Backend lưu mỗi bước/lỗi một dòng.
  static List<String> _lines(String text) => text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}
