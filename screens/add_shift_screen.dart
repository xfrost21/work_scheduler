import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/work_shift.dart';
import '../models/app_settings.dart';
import '../utils/shift_calculator.dart';

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
  final _notesController = TextEditingController();
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
      _notesController.text = widget.existingShift!.notes;
    } else {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('app_settings');
    if (data != null)
      setState(() => _settings = AppSettings.fromJson(jsonDecode(data)));
  }

  void _handleSave() {
    if (_selectedDay == null || _startTime == null || _endTime == null) return;

    final temp = WorkShift(
      id:
          widget.existingShift?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDay!,
      startTime: _startTime!,
      endTime: _endTime!,
      totalHours: 0,
      estimatedPay: 0,
      isCompleted: _isCompleted,
      type: _shiftType,
      notes: _notesController.text,
    );

    final res = ShiftCalculator.calculatePay(temp, _settings);

    Navigator.pop(
      context,
      WorkShift(
        id: temp.id,
        date: temp.date,
        startTime: temp.startTime,
        endTime: temp.endTime,
        totalHours: res['total'],
        estimatedPay: res['pay'],
        isCompleted: _isCompleted,
        type: _shiftType,
        notes: _notesController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Szczegóły zmiany')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _shiftType,
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
              children: {
                'work': _buildSegText('Praca', _shiftType == 'work'),
                'off': _buildSegText('Wolne', _shiftType == 'off'),
                'sick': _buildSegText('L4', _shiftType == 'sick'),
              },
              onValueChanged: (v) => setState(() => _shiftType = v!),
            ),
            const SizedBox(height: 24),
            _buildCard(
              child: TableCalendar(
                locale: 'pl_PL',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                onDaySelected: (s, f) => setState(() {
                  _selectedDay = s;
                  _focusedDay = f;
                }),
                holidayPredicate: (d) =>
                    ShiftCalculator.isHoliday(d, _settings),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  holidayTextStyle: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                startingDayOfWeek: StartingDayOfWeek.monday,
              ),
            ),
            const SizedBox(height: 24),
            if (_shiftType == 'work')
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: 'Start',
                      time: _startTime,
                      icon: Icons.login,
                      onTap: () async {
                        var t = await showTimePicker(
                          context: context,
                          initialTime:
                              _startTime ??
                              const TimeOfDay(hour: 8, minute: 0), // POPRAWIONE
                        );
                        if (t != null) setState(() => _startTime = t);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _TimeButton(
                      label: 'Koniec',
                      time: _endTime,
                      icon: Icons.logout,
                      onTap: () async {
                        var t = await showTimePicker(
                          context: context,
                          initialTime:
                              _endTime ??
                              const TimeOfDay(
                                hour: 16,
                                minute: 0,
                              ), // POPRAWIONE
                        );
                        if (t != null) setState(() => _endTime = t);
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            _buildCard(
              child: TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Notatki (np. sekcja, manager)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'ZAPISZ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegText(String l, bool s) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(
      l,
      style: TextStyle(fontWeight: s ? FontWeight.bold : FontWeight.normal),
    ),
  );
  Widget _buildCard({required Widget child}) => Container(
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
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
