import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/work_shift.dart';
import '../models/app_settings.dart';

class AddShiftScreen extends StatefulWidget {
  final WorkShift? existingShift;
  const AddShiftScreen({super.key, this.existingShift});

  @override
  State<AddShiftScreen> createState() => _AddShiftScreenState();
}

class _AddShiftScreenState extends State<AddShiftScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isCompleted = false;
  String _shiftType = 'work';
  bool _isL4FullPaid = false;

  AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();

    if (widget.existingShift != null) {
      _focusedDay = widget.existingShift!.date;
      _selectedDay = widget.existingShift!.date;
      _startTime = widget.existingShift!.startTime;
      _endTime = widget.existingShift!.endTime;
      _isCompleted = widget.existingShift!.isCompleted;
      _shiftType = widget.existingShift!.type;
    } else {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('app_settings');
    if (data != null) {
      setState(() {
        _settings = AppSettings.fromJson(jsonDecode(data));
      });
    }
  }

  // ULEPSZONE: Sprawdzanie świąt państwowych + firmowych
  bool _isHoliday(DateTime day) {
    // 1. Sprawdzamy święta zdefiniowane przez Ciebie w Opcjach
    bool isCompanyHoliday = _settings.customHolidays.any(
      (d) => d.year == day.year && d.month == day.month && d.day == day.day,
    );

    if (isCompanyHoliday) return true;

    // 2. Stałe święta państwowe
    final fixedHolidays = [
      [1, 1],
      [6, 1],
      [1, 5],
      [3, 5],
      [15, 8],
      [1, 11],
      [11, 11],
      [25, 12],
      [26, 12],
    ];
    for (var h in fixedHolidays) {
      if (day.day == h[0] && day.month == h[1]) return true;
    }

    // 3. Ruchome święta (Wielkanoc i okolice)
    int y = day.year;
    int a = y % 19;
    int b = y ~/ 100;
    int c = y % 100;
    int d = b ~/ 4;
    int e = b % 4;
    int f = (b + 8) ~/ 25;
    int g = (b - f + 1) ~/ 3;
    int h = (19 * a + b - d - g + 15) % 30;
    int i = c ~/ 4;
    int k = c % 4;
    int l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * l) ~/ 451;
    int month = (h + l - 7 * m + 114) ~/ 31;
    int dDay = ((h + l - 7 * m + 114) % 31) + 1;
    DateTime easter = DateTime(y, month, dDay);

    if (isSameDay(day, easter) || // Wielkanoc
        isSameDay(
          day,
          easter.add(const Duration(days: 1)),
        ) || // Poniedziałek Wielkanocny
        isSameDay(
          day,
          easter.add(const Duration(days: 49)),
        ) || // Zielone Świątki
        isSameDay(day, easter.add(const Duration(days: 60)))) {
      // Boże Ciało
      return true;
    }
    return false;
  }

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 16, minute: 0)),
    );
    if (pickedTime != null) {
      setState(() {
        if (isStartTime)
          _startTime = pickedTime;
        else
          _endTime = pickedTime;
      });
    }
  }

  Map<String, dynamic> _calculateShiftData(
    TimeOfDay start,
    TimeOfDay end,
    bool isHolidayDay,
  ) {
    int startMinutes = start.hour * 60 + start.minute;
    int endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) endMinutes += 24 * 60;

    int totalMinutes = endMinutes - startMinutes;
    int nightMinutes = 0;
    int regularMinutes = 0;

    for (int i = 0; i < totalMinutes; i++) {
      int currentHour = ((startMinutes + i) % (24 * 60)) ~/ 60;
      if (currentHour >= 22 || currentHour < 6)
        nightMinutes++;
      else
        regularMinutes++;
    }

    int unpaidBreakMinutes = 15;
    if (totalMinutes > unpaidBreakMinutes) {
      if (regularMinutes >= unpaidBreakMinutes)
        regularMinutes -= unpaidBreakMinutes;
      else {
        int remaining = unpaidBreakMinutes - regularMinutes;
        regularMinutes = 0;
        nightMinutes -= remaining;
      }
    }

    // ULEPSZONE: Pobieranie bonusu świątecznego z ustawień
    double baseRate = isHolidayDay
        ? (_settings.hourlyRate + _settings.holidayBonus)
        : _settings.hourlyRate;

    double nightRate = baseRate * 1.2;
    double payForRegular = (regularMinutes / 60.0) * baseRate;
    double payForNight = (nightMinutes / 60.0) * nightRate;

    return {
      'total': (regularMinutes + nightMinutes) / 60.0,
      'pay': payForRegular + payForNight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingShift != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardTheme.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edytuj wpis' : 'Nowy wpis',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- POPRAWIONY PRZEŁĄCZNIK TYPÓW (iOS) ---
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _shiftType,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
              thumbColor: isDark ? Colors.grey.shade800 : Colors.white,
              children: {
                'work': _buildSegmentText(
                  'Praca',
                  _shiftType == 'work',
                  textColor,
                ),
                'off': _buildSegmentText(
                  'Wolne',
                  _shiftType == 'off',
                  textColor,
                ),
                'sick': _buildSegmentText(
                  'L4',
                  _shiftType == 'sick',
                  textColor,
                ),
              },
              onValueChanged: (val) => setState(() => _shiftType = val!),
            ),

            const SizedBox(height: 24),

            // --- KALENDARZ ---
            _buildIosCard(
              child: TableCalendar(
                locale: 'pl_PL',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (s, f) => setState(() {
                  _selectedDay = s;
                  _focusedDay = f;
                }),
                holidayPredicate: _isHoliday,
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(color: textColor),
                  weekendTextStyle: const TextStyle(color: Colors.redAccent),
                  holidayTextStyle: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    border: Border.all(color: primaryColor),
                    shape: BoxShape.circle,
                  ),
                  outsideTextStyle: const TextStyle(color: Colors.grey),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: primaryColor,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: primaryColor,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  weekendStyle: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                startingDayOfWeek: StartingDayOfWeek.monday,
              ),
            ),

            const SizedBox(height: 24),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _shiftType == 'work'
                  ? _buildWorkSection(textColor, primaryColor)
                  : _shiftType == 'sick'
                  ? _buildSickSection()
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isEditing ? 'ZAPISZ ZMIANY' : 'DODAJ DO GRAFIKU',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentText(String label, bool isSelected, Color? textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? textColor : textColor?.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildWorkSection(Color? textColor, Color primaryColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: 'Początek',
                time: _startTime,
                icon: Icons.login_rounded,
                onTap: () => _pickTime(context, true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TimeButton(
                label: 'Koniec',
                time: _endTime,
                icon: Icons.logout_rounded,
                onTap: () => _pickTime(context, false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            title: Text(
              'Zrealizowana',
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            value: _isCompleted,
            activeColor: primaryColor,
            onChanged: (val) => setState(() => _isCompleted = val),
          ),
        ),
      ],
    );
  }

  Widget _buildSickSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: SwitchListTile(
        title: const Text(
          'L4 Płatne 100%',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        subtitle: Text(
          'Ciąża, wypadek lub dawstwo',
          style: TextStyle(color: Colors.redAccent.withOpacity(0.7)),
        ),
        value: _isL4FullPaid,
        activeColor: Colors.redAccent,
        onChanged: (val) => setState(() => _isL4FullPaid = val),
      ),
    );
  }

  void _handleSave() {
    if (_selectedDay == null) return;
    double finalPay = 0;
    double finalTotalHours = 0;
    TimeOfDay finalStart = const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay finalEnd = const TimeOfDay(hour: 0, minute: 0);

    if (_shiftType == 'work') {
      if (_startTime == null || _endTime == null) return;
      final shiftData = _calculateShiftData(
        _startTime!,
        _endTime!,
        _isHoliday(_selectedDay!),
      );
      finalPay = shiftData['pay'];
      finalTotalHours = shiftData['total'];
      finalStart = _startTime!;
      finalEnd = _endTime!;
    } else if (_shiftType == 'sick') {
      double base = _settings.averageMonthlyNet;
      double multiplier = _isL4FullPaid ? 1.0 : 0.8;
      finalPay = (base / 30.0) * multiplier;
      finalTotalHours = 0;
    }

    final newShift = WorkShift(
      id:
          widget.existingShift?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDay!,
      startTime: finalStart,
      endTime: finalEnd,
      totalHours: finalTotalHours,
      regularHours: 0,
      nightHours: 0,
      estimatedPay: finalPay,
      isCompleted: _shiftType == 'work' ? _isCompleted : true,
      type: _shiftType,
    );
    Navigator.pop(context, newShift);
  }

  Widget _buildIosCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(8),
    child: child,
  );
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final IconData icon;
  final VoidCallback onTap;
  const _TimeButton({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final iconColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              time?.format(context) ?? '--:--',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
