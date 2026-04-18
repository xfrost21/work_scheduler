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
  final _notesController = TextEditingController(); // NOWE

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
      _notesController.text = widget.existingShift!.notes; // Ładujemy notatkę
    } else {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    }
  }

  @override
  void dispose() {
    _notesController.dispose(); // Czyścimy pamięć
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('app_settings');
    if (data != null)
      setState(() => _settings = AppSettings.fromJson(jsonDecode(data)));
  }

  bool _isHoliday(DateTime day) {
    bool isCompanyHoliday = _settings.customHolidays.any(
      (d) => d.year == day.year && d.month == day.month && d.day == day.day,
    );
    if (isCompanyHoliday) return true;
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
    return false;
  }

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 16, minute: 0)),
    );
    if (pickedTime != null)
      setState(() {
        if (isStartTime)
          _startTime = pickedTime;
        else
          _endTime = pickedTime;
      });
  }

  Map<String, dynamic> _calculateShiftData(
    TimeOfDay start,
    TimeOfDay end,
    bool isHolidayDay,
  ) {
    int startMin = start.hour * 60 + start.minute;
    int endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) endMin += 24 * 60;
    int totalMin = endMin - startMin;
    int nightMin = 0;
    int regMin = 0;

    for (int i = 0; i < totalMin; i++) {
      int currH = ((startMin + i) % (24 * 60)) ~/ 60;
      if (currH >= 22 || currH < 6)
        nightMin++;
      else
        regMin++;
    }

    if (totalMin > 15) {
      if (regMin >= 15)
        regMin -= 15;
      else {
        nightMin -= (15 - regMin);
        regMin = 0;
      }
    }

    double baseRate = isHolidayDay
        ? (_settings.hourlyRate + _settings.holidayBonus)
        : _settings.hourlyRate;
    double nightRate = baseRate * 1.2;

    return {
      'total': (regMin + nightMin) / 60.0,
      'pay': (regMin / 60.0 * baseRate) + (nightMin / 60.0 * nightRate),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szczegóły zmiany'),
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
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _shiftType,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
              thumbColor: isDark ? Colors.grey.shade800 : Colors.white,
              children: {
                'work': _buildSegText('Praca', _shiftType == 'work', textColor),
                'off': _buildSegText('Wolne', _shiftType == 'off', textColor),
                'sick': _buildSegText('L4', _shiftType == 'sick', textColor),
              },
              onValueChanged: (val) => setState(() => _shiftType = val!),
            ),
            const SizedBox(height: 24),
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
                  selectedDecoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: primaryColor,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: primaryColor,
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
            const SizedBox(height: 24),

            // --- NOWA SEKCJA NOTATEK ---
            const Text(
              'NOTATKI',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildIosCard(
              child: TextField(
                controller: _notesController,
                maxLines: 2,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  hintText: 'Np. "Dostawa", "Drive", "Kuchnia"...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
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
              child: const Text(
                'ZAPISZ ZMIANĘ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkSection(Color? txtColor, Color primColor) {
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
        _buildIosCard(
          child: SwitchListTile(
            title: Text(
              'Zrealizowana',
              style: TextStyle(fontWeight: FontWeight.bold, color: txtColor),
            ),
            value: _isCompleted,
            activeColor: primColor,
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
        value: _isL4FullPaid,
        activeColor: Colors.redAccent,
        onChanged: (val) => setState(() => _isL4FullPaid = val),
      ),
    );
  }

  void _handleSave() {
    if (_selectedDay == null) return;
    double fPay = 0;
    double fTotal = 0;
    TimeOfDay fStart = const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay fEnd = const TimeOfDay(hour: 0, minute: 0);

    if (_shiftType == 'work') {
      if (_startTime == null || _endTime == null) return;
      final data = _calculateShiftData(
        _startTime!,
        _endTime!,
        _isHoliday(_selectedDay!),
      );
      fPay = data['pay'];
      fTotal = data['total'];
      fStart = _startTime!;
      fEnd = _endTime!;
    } else if (_shiftType == 'sick') {
      fPay = (_settings.averageMonthlyNet / 30.0) * (_isL4FullPaid ? 1.0 : 0.8);
    }

    Navigator.pop(
      context,
      WorkShift(
        id:
            widget.existingShift?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDay!,
        startTime: fStart,
        endTime: fEnd,
        totalHours: fTotal,
        estimatedPay: fPay,
        isCompleted: _shiftType == 'work' ? _isCompleted : true,
        type: _shiftType,
        notes: _notesController.text, // Zapisujemy notatkę
      ),
    );
  }

  Widget _buildSegText(String l, bool s, Color? c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      l,
      style: TextStyle(
        fontWeight: s ? FontWeight.bold : FontWeight.normal,
        color: s ? c : c?.withOpacity(0.6),
      ),
    ),
  );
  Widget _buildIosCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
    ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              time?.format(context) ?? '--:--',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
