import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/work_shift.dart';
import '../models/app_settings.dart';
import 'add_shift_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkShift> shifts = [];
  AppSettings _settings = AppSettings();
  int _selectedIndex = 0;
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? shiftsString = prefs.getString('my_work_shifts');
    if (shiftsString != null) {
      final List<dynamic> decodedData = jsonDecode(shiftsString);
      setState(() {
        shifts = decodedData.map((item) => WorkShift.fromJson(item)).toList();
        shifts.sort((a, b) => a.date.compareTo(b.date));
      });
    }
    final String? settingsString = prefs.getString('app_settings');
    if (settingsString != null) {
      setState(
        () => _settings = AppSettings.fromJson(jsonDecode(settingsString)),
      );
    }
  }

  Future<void> _openShiftForm([WorkShift? shiftToEdit]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddShiftScreen(existingShift: shiftToEdit),
        fullscreenDialog: true,
      ),
    );
    if (result != null) {
      _loadData();
    }
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
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.add, size: 28),
              onPressed: () => _openShiftForm(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedIndex != 2) _buildMonthPicker(),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _loadData();
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Grafik',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Analiza',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Opcje',
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final filtered = shifts
        .where(
          (s) =>
              s.date.month == _focusedMonth.month &&
              s.date.year == _focusedMonth.year,
        )
        .toList();
    double earned = 0;
    double planned = 0;
    for (var s in filtered) {
      if (s.isCompleted || s.type == 'sick')
        earned += s.estimatedPay;
      else
        planned += s.estimatedPay;
    }

    return ListView(
      children: [
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildIosCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStat('ZAROBIONE', earned, Colors.green),
                    _buildMiniStat('W PLANACH', planned, Colors.orange),
                    _buildMiniStat(
                      'ŁĄCZNIE',
                      earned + planned,
                      Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ...filtered.map((s) {
          final day = DateFormat('dd.MM, EEEE', 'pl_PL').format(s.date);
          Color color = s.type == 'sick'
              ? Colors.redAccent
              : (s.isCompleted ? Colors.green : Colors.orange);
          if (s.type == 'off') color = Colors.grey;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              onTap: () => _openShiftForm(s),
              leading: Icon(
                s.type == 'work' ? Icons.work : Icons.home,
                color: color,
              ),
              title: Text(
                day,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                s.type == 'work'
                    ? '${s.startTime.format(context)} - ${s.endTime.format(context)}'
                    : 'Wolne',
              ),
              trailing: Text(
                '${s.estimatedPay.toStringAsFixed(2)} zł',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMiniStat(String l, double v, Color c) => Column(
    children: [
      Text(
        l,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        '${v.toStringAsFixed(0)} zł',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c),
      ),
    ],
  );

  Widget _buildSummaryTab() {
    final filtered = shifts
        .where(
          (s) =>
              s.date.month == _focusedMonth.month &&
              s.date.year == _focusedMonth.year,
        )
        .toList();
    double earned = 0;
    for (var s in filtered)
      if (s.isCompleted || s.type == 'sick') earned += s.estimatedPay;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_settings.goalTarget > 0) ...[
          const Text(
            'POSTĘP CELU',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildIosCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _settings.goalName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${((earned / _settings.goalTarget) * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (earned / _settings.goalTarget).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      color: Colors.green,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zostało do zarobienia: ${(_settings.goalTarget - earned).clamp(0, double.infinity).toStringAsFixed(2)} zł',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMonthPicker() {
    return Row(
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
          DateFormat('MMMM yyyy', 'pl_PL').format(_focusedMonth).toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildIosCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}
