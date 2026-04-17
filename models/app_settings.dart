class AppSettings {
  double hourlyRate;
  double averageMonthlyNet;
  String contractType;
  bool isDarkMode;
  double holidayBonus; // NOWE: Kwota dodatku
  List<DateTime> customHolidays; // NOWE: Lista Twoich świąt

  AppSettings({
    this.hourlyRate = 29.0,
    this.averageMonthlyNet = 4500.0,
    this.contractType = 'uop',
    this.isDarkMode = false,
    this.holidayBonus = 4.0, // Domyślnie 4 zł
    List<DateTime>? customHolidays,
  }) : this.customHolidays = customHolidays ?? [];

  Map<String, dynamic> toJson() => {
    'hourlyRate': hourlyRate,
    'averageMonthlyNet': averageMonthlyNet,
    'contractType': contractType,
    'isDarkMode': isDarkMode,
    'holidayBonus': holidayBonus,
    'customHolidays': customHolidays.map((e) => e.toIso8601String()).toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    hourlyRate: json['hourlyRate'] ?? 29.0,
    averageMonthlyNet: json['averageMonthlyNet'] ?? 4500.0,
    contractType: json['contractType'] ?? 'uop',
    isDarkMode: json['isDarkMode'] ?? false,
    holidayBonus: (json['holidayBonus'] ?? 4.0).toDouble(),
    customHolidays:
        (json['customHolidays'] as List?)
            ?.map((e) => DateTime.parse(e))
            .toList() ??
        [],
  );
}
