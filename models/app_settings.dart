class AppSettings {
  double hourlyRateNet;
  double hourlyRateGross;
  bool useGross;
  bool isStudent;
  bool isUnder26;
  double averageMonthlyNet;
  String contractType;
  double employmentFte; // 1.0, 0.75, 0.5
  double extraAllowance; // Np. 0.23 na pranie
  bool isDarkMode;
  double holidayBonus;
  List<DateTime> customHolidays;
  String goalName;
  double goalTarget;

  AppSettings({
    this.hourlyRateNet = 25.0,
    this.hourlyRateGross = 29.0,
    this.useGross = false,
    this.isStudent = true,
    this.isUnder26 = true,
    this.averageMonthlyNet = 4500.0,
    this.contractType = 'uop',
    this.employmentFte = 0.75,
    this.extraAllowance = 0.0,
    this.isDarkMode = false,
    this.holidayBonus = 4.0,
    List<DateTime>? customHolidays,
    this.goalName = '',
    this.goalTarget = 0.0,
  }) : this.customHolidays = customHolidays ?? [];

  Map<String, dynamic> toJson() => {
    'hourlyRateNet': hourlyRateNet,
    'hourlyRateGross': hourlyRateGross,
    'useGross': useGross,
    'isStudent': isStudent,
    'isUnder26': isUnder26,
    'averageMonthlyNet': averageMonthlyNet,
    'contractType': contractType,
    'employmentFte': employmentFte,
    'extraAllowance': extraAllowance,
    'isDarkMode': isDarkMode,
    'holidayBonus': holidayBonus,
    'customHolidays': customHolidays.map((e) => e.toIso8601String()).toList(),
    'goalName': goalName,
    'goalTarget': goalTarget,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    hourlyRateNet: (json['hourlyRateNet'] ?? 25.0).toDouble(),
    hourlyRateGross: (json['hourlyRateGross'] ?? 29.0).toDouble(),
    useGross: json['useGross'] ?? false,
    isStudent: json['isStudent'] ?? true,
    isUnder26: json['isUnder26'] ?? true,
    averageMonthlyNet: (json['averageMonthlyNet'] ?? 4500.0).toDouble(),
    contractType: json['contractType'] ?? 'uop',
    employmentFte: (json['employmentFte'] ?? 0.75).toDouble(),
    extraAllowance: (json['extraAllowance'] ?? 0.0).toDouble(),
    isDarkMode: json['isDarkMode'] ?? false,
    holidayBonus: (json['holidayBonus'] ?? 4.0).toDouble(),
    customHolidays:
        (json['customHolidays'] as List?)
            ?.map((e) => DateTime.parse(e))
            .toList() ??
        [],
    goalName: json['goalName'] ?? '',
    goalTarget: (json['goalTarget'] ?? 0.0).toDouble(),
  );
}
