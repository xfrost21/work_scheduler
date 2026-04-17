class AppSettings {
  double hourlyRate;
  double averageMonthlyNet;
  String contractType;
  bool isDarkMode; // NOWE

  AppSettings({
    this.hourlyRate = 29.0,
    this.averageMonthlyNet = 4500.0,
    this.contractType = 'uop',
    this.isDarkMode = false, // Domyślnie jasny
  });

  Map<String, dynamic> toJson() => {
    'hourlyRate': hourlyRate,
    'averageMonthlyNet': averageMonthlyNet,
    'contractType': contractType,
    'isDarkMode': isDarkMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    hourlyRate: json['hourlyRate'] ?? 29.0,
    averageMonthlyNet: json['averageMonthlyNet'] ?? 4500.0,
    contractType: json['contractType'] ?? 'uop',
    isDarkMode: json['isDarkMode'] ?? false,
  );
}
