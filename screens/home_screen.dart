import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/work_shift.dart';
import 'add_shift_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkShift> shifts = [];
  int _selectedIndex = 0;
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  void _sortShifts() {
    shifts.sort((a, b) {
      int dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return a.startTime.hour.compareTo(b.startTime.hour);
    });
  }

  Future<void> _loadShifts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? shiftsString = prefs.getString('my_work_shifts');
    if (shiftsString != null) {
      final List<dynamic> decodedData = jsonDecode(shiftsString);
      setState(() {
        shifts = decodedData.map((item) => WorkShift.fromJson(item)).toList();
        _sortShifts();
      });
    }
  }

  Future<void> _saveShifts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      shifts.map((shift) => shift.toJson()).toList(),
    );
    await prefs.setString('my_work_shifts', encodedData);
  }

  Future<void> _openShiftForm([WorkShift? shiftToEdit]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddShiftScreen(existingShift: shiftToEdit),
        fullscreenDialog: true,
      ),
    );

    if (result != null && result is WorkShift) {
      setState(() {
        if (shiftToEdit != null) {
          int index = shifts.indexWhere((s) => s.id == result.id);
          if (index != -1) shifts[index] = result;
        } else {
          shifts.add(result);
        }
        _sortShifts();
      });
      _saveShifts();
    }
  }

  List<WorkShift> _getFilteredShifts() {
    return shifts
        .where(
          (shift) =>
              shift.date.month == _focusedMonth.month &&
              shift.date.year == _focusedMonth.year,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_selectedIndex == 0)
      body = _buildScheduleTab();
    else if (_selectedIndex == 1)
      body = _buildSummaryTab();
    else
      body = const SettingsScreen();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Mój Grafik'
              : _selectedIndex == 1
              ? 'Podsumowanie'
              : 'Opcje',
        ),
      ),
      body: Column(
        children: [
          if (_selectedIndex != 2) _buildMonthPicker(),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Grafik',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            activeIcon: Icon(Icons.pie_chart),
            label: 'Analiza',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Opcje',
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    final label = DateFormat('MMMM yyyy', 'pl_PL').format(_focusedMonth);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(
              () => _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month - 1,
              ),
            ),
          ),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(
              () => _focusedMonth = DateTime(
                _focusedMonth.year,
                _focusedMonth.month + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final filtered = _getFilteredShifts();
    if (filtered.isEmpty)
      return Center(
        child: Text('Brak wpisów.', style: TextStyle(color: Colors.grey[500])),
      );

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final shift = filtered[index];
        final dayName = DateFormat('EEEE', 'pl_PL').format(shift.date);

        IconData icon;
        Color color;
        String sub = '';
        Color bg = Theme.of(context).cardTheme.color!;

        if (shift.type == 'off') {
          icon = Icons.coffee_rounded;
          color = Colors.blueGrey;
          sub = 'Wolne';
        } else if (shift.type == 'sick') {
          icon = Icons.medical_services_rounded;
          color = Colors.redAccent;
          sub = 'L4';
          bg = Colors.red.withOpacity(0.05);
        } else {
          icon = shift.isCompleted
              ? Icons.check_circle_rounded
              : Icons.pending_actions_rounded;
          color = shift.isCompleted ? Colors.green : Colors.orange;
          sub =
              '${shift.startTime.format(context)} - ${shift.endTime.format(context)}';
        }

        // DODAJEMY NOTATKĘ DO OPISU
        if (shift.notes.isNotEmpty) sub += '\n📝 ${shift.notes}';

        return Dismissible(
          key: Key(shift.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            setState(() => shifts.removeWhere((s) => s.id == shift.id));
            _saveShifts();
          },
          child: Card(
            color: bg,
            child: ListTile(
              onTap: () => _openShiftForm(shift),
              leading: Icon(icon, color: color),
              title: Text(
                '${DateFormat('dd.MM').format(shift.date)}, ${dayName[0].toUpperCase()}${dayName.substring(1)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(sub, style: const TextStyle(height: 1.4)),
              trailing: Text(
                '${shift.estimatedPay.toStringAsFixed(2)} zł',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    final filtered = _getFilteredShifts();
    double earned = 0;
    double planned = 0;
    int work = 0;
    int off = 0;
    int sick = 0;
    for (var s in filtered) {
      if (s.type == 'off')
        off++;
      else if (s.type == 'sick') {
        sick++;
        earned += s.estimatedPay;
      } else {
        work++;
        if (s.isCompleted)
          earned += s.estimatedPay;
        else
          planned += s.estimatedPay;
      }
    }
    final txt = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildIosCard(
          child: Column(
            children: [
              _buildRow(
                'Zarobione',
                '${earned.toStringAsFixed(2)} zł',
                Colors.green,
              ),
              const Divider(height: 1, indent: 16),
              _buildRow(
                'W planach',
                '${planned.toStringAsFixed(2)} zł',
                Colors.orange,
              ),
              const Divider(height: 1, indent: 16),
              _buildRow(
                'Suma',
                '${(earned + planned).toStringAsFixed(2)} zł',
                txt,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildIosCard(
          child: Column(
            children: [
              _buildRow('Dni pracy', '$work', txt),
              const Divider(height: 1, indent: 16),
              _buildRow('Wolne / L4', '$off / $sick', Colors.blueGrey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIosCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
  Widget _buildRow(String t, String v, Color c, {bool bold = false}) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(t),
        Text(
          v,
          style: TextStyle(
            color: c,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
