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

  // Wczytywanie danych z pamięci telefonu
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Wczytywanie zmian
    final String? data = prefs.getString('my_work_shifts');
    if (data != null) {
      setState(() {
        shifts = (jsonDecode(data) as List)
            .map((i) => WorkShift.fromJson(i))
            .toList();
        shifts.sort((a, b) => a.date.compareTo(b.date));
      });
    }

    // Wczytywanie ustawień (stawki, etat, cel)
    final String? sData = prefs.getString('app_settings');
    if (sData != null) {
      setState(() => _settings = AppSettings.fromJson(jsonDecode(sData)));
    }
  }

  // Zapisywanie zmian do pamięci
  Future<void> _saveShifts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'my_work_shifts',
      jsonEncode(shifts.map((s) => s.toJson()).toList()),
    );
  }

  // Otwieranie formularza dodawania/edycji
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
        shifts.sort((a, b) => a.date.compareTo(b.date));
      });
      _saveShifts();
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
        onTap: (i) {
          setState(() => _selectedIndex = i);
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

  // KARTA: LISTA ZMIAN (GRAFIK)
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
          // Logika kolorów i ikonek
          Color color = s.type == 'sick'
              ? Colors.redAccent
              : (s.isCompleted ? Colors.green : Colors.orange);
          if (s.type == 'off') color = Colors.grey;

          return Dismissible(
            key: Key(s.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              setState(() => shifts.removeWhere((item) => item.id == s.id));
              _saveShifts();
            },
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                onTap: () => _openShiftForm(s),
                leading: Icon(
                  s.type == 'work'
                      ? (s.isCompleted ? Icons.check_circle : Icons.work)
                      : (s.type == 'sick'
                            ? Icons.medical_services
                            : Icons.home), // Ikonka medyczna dla L4
                  color: color,
                ),
                title: Text(
                  DateFormat('dd.MM, EEEE', 'pl_PL').format(s.date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  s.type == 'work'
                      ? '${s.startTime.format(context)} - ${s.endTime.format(context)}'
                      : (s.type == 'sick' ? 'Chorobowe (L4)' : 'Wolne'),
                ),
                trailing: Text(
                  '${s.estimatedPay.toStringAsFixed(2)} zł',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
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

  // KARTA: ANALIZA (PODSUMOWANIE)
  Widget _buildSummaryTab() {
    final filtered = shifts
        .where(
          (s) =>
              s.date.month == _focusedMonth.month &&
              s.date.year == _focusedMonth.year,
        )
        .toList();
    double earned = 0;
    Map<int, double> daily = {};
    double currentHours = 0;

    for (var s in filtered) {
      if (s.isCompleted || s.type == 'sick') {
        earned += s.estimatedPay;
        currentHours += s.totalHours; // Tu wpadają godziny z pracy oraz 8h z L4
        daily[s.date.day] = (daily[s.date.day] ?? 0) + s.estimatedPay;
      }
    }

    // Obliczanie nominału (średnio 168h * etat)
    double nominal = 168.0 * _settings.employmentFte;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'STATYSTYKI DZIENNE',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildIosCard(
          child: Container(
            height: 180,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: _buildBarChart(daily),
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'REALIZACJA ETATU',
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
                      'Wymiar: ${(_settings.employmentFte * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${currentHours.toStringAsFixed(1)} / ${nominal.toInt()} h',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentHours / nominal).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    color: Colors.blue,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentHours >= nominal
                      ? 'Wymiar wypracowany!'
                      : 'Do wymiaru: ${(nominal - currentHours).toStringAsFixed(1)} h',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
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
                    'Zostało do celu: ${(_settings.goalTarget - earned).clamp(0, double.infinity).toStringAsFixed(2)} zł',
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

  // Budowanie wykresu słupkowego zarobków
  Widget _buildBarChart(Map<int, double> data) {
    if (data.isEmpty) return const Center(child: Text('Brak danych'));
    double maxVal = data.values.fold(0, (max, v) => v > max ? v : max);
    int days = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(days, (i) {
        int d = i + 1;
        double v = data[d] ?? 0;
        double h = maxVal > 0 ? (v / maxVal) : 0;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: (h * 120).clamp(0, 120),
                decoration: BoxDecoration(
                  color: v > 0
                      ? Colors.green.withOpacity(0.8)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              if (d % 5 == 0 || d == 1 || d == days)
                Text(
                  '$d',
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                )
              else
                const SizedBox(height: 10),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMonthPicker() => Row(
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

  Widget _buildIosCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}
