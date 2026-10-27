/// Giá trị enum khớp docs/04-business-rules.md §3.1, §3.3.
enum Sex {
  male('MALE', 'Nam'),
  female('FEMALE', 'Nữ');

  const Sex(this.api, this.label);

  final String api;
  final String label;
}

enum ActivityLevel {
  sedentary('SEDENTARY', 'Ít vận động'),
  light('LIGHT', 'Nhẹ (1–3 buổi/tuần)'),
  moderate('MODERATE', 'Vừa (3–5 buổi/tuần)'),
  active('ACTIVE', 'Nhiều (6–7 buổi/tuần)'),
  veryActive('VERY_ACTIVE', 'Rất nhiều (lao động nặng/tập 2 lần/ngày)');

  const ActivityLevel(this.api, this.label);

  final String api;
  final String label;
}

enum Goal {
  loseWeight('LOSE_WEIGHT', 'Giảm cân'),
  maintain('MAINTAIN', 'Giữ cân'),
  gainMuscle('GAIN_MUSCLE', 'Tăng cơ');

  const Goal(this.api, this.label);

  final String api;
  final String label;
}

T _fromApi<T extends Enum>(List<T> values, String api, String Function(T) apiOf) =>
    values.firstWhere((v) => apiOf(v) == api,
        orElse: () => throw FormatException('Giá trị không hỗ trợ: $api'));

/// JSON có thể trả 170 hoặc 170.0; không ép kiểu thẳng sang double.
double _num(Object? value) => (value as num).toDouble();

String formatApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Dữ liệu người dùng nhập; không có BMI/kcal vì backend tính.
class HealthProfileInput {
  const HealthProfileInput({
    required this.sex,
    required this.dateOfBirth,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
  });

  final Sex sex;
  final DateTime dateOfBirth;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activityLevel;
  final Goal goal;

  Map<String, Object> toJson() => {
        'sex': sex.api,
        'dateOfBirth': formatApiDate(dateOfBirth),
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel.api,
        'goal': goal.api,
      };
}

/// Kết quả chính thức do backend tính; app chỉ hiển thị.
class HealthTargets {
  const HealthTargets({
    required this.bmi,
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.targetKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.kcalFloorApplied,
    required this.formulaVersion,
  });

  factory HealthTargets.fromJson(Map<String, dynamic> json) => HealthTargets(
        bmi: _num(json['bmi']),
        bmrKcal: _num(json['bmrKcal']),
        tdeeKcal: _num(json['tdeeKcal']),
        targetKcal: _num(json['targetKcal']),
        proteinG: _num(json['proteinG']),
        carbsG: _num(json['carbsG']),
        fatG: _num(json['fatG']),
        kcalFloorApplied: json['kcalFloorApplied'] as bool? ?? false,
        formulaVersion: json['formulaVersion'] as String,
      );

  final double bmi;
  final double bmrKcal;
  final double tdeeKcal;
  final double targetKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final bool kcalFloorApplied;
  final String formulaVersion;
}

class HealthProfileData {
  const HealthProfileData({
    required this.profile,
    required this.age,
    required this.targets,
  });

  factory HealthProfileData.fromJson(Map<String, dynamic> json) {
    final p = json['profile'] as Map<String, dynamic>;
    return HealthProfileData(
      profile: HealthProfileInput(
        sex: _fromApi(Sex.values, p['sex'] as String, (v) => v.api),
        dateOfBirth: DateTime.parse(p['dateOfBirth'] as String),
        heightCm: _num(p['heightCm']),
        weightKg: _num(p['weightKg']),
        activityLevel: _fromApi(
            ActivityLevel.values, p['activityLevel'] as String, (v) => v.api),
        goal: _fromApi(Goal.values, p['goal'] as String, (v) => v.api),
      ),
      age: p['age'] as int,
      targets: HealthTargets.fromJson(json['targets'] as Map<String, dynamic>),
    );
  }

  final HealthProfileInput profile;
  final int age;
  final HealthTargets targets;
}
