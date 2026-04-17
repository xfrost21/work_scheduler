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
    return shifts.where((shift) {
      return shift.date.month == _focusedMonth.month &&
          shift.date.year == _focusedMonth.year;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Widget currentBody;
    if (_selectedIndex == 0) {
      currentBody = _buildScheduleTab();
    } else if (_selectedIndex == 1) {
      currentBody = _buildSummaryTab();
    } else {
      currentBody = const SettingsScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Mój Grafik'
              : _selectedIndex == 1
              ? 'Podsumowanie'
              : 'Ustawienia',
        ),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              onPressed: () => _openShiftForm(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedIndex != 2) _buildMonthPicker(),
          Expanded(child: currentBody),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
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
      ),
    );
  }

  Widget _buildMonthPicker() {
    final monthLabel = DateFormat('MMMM yyyy', 'pl_PL').format(_focusedMonth);
    return Container(
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
            monthLabel.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              fontSize: 14,
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
    final filteredShifts = _getFilteredShifts();
    if (filteredShifts.isEmpty) {
      return Center(
        child: Text(
          'Brak wpisów w tym miesiącu.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: filteredShifts.length,
      itemBuilder: (context, index) {
        final shift = filteredShifts[index];
        final dateFormat = DateFormat('dd.MM.yyyy');
        final dayName = DateFormat('EEEE', 'pl_PL').format(shift.date);

        String titleText = dateFormat.format(shift.date);
        IconData leadingIcon;
        Color accentColor;
        String subtitleText = '';

        // DYNAMICZNY KOLOR TŁA (Reaguje na Dark Mode)
        Color? bgColor = Theme.of(context).cardTheme.color;

        if (shift.type == 'off') {
          leadingIcon = Icons.coffee_rounded;
          accentColor = Colors.blueGrey;
          subtitleText = 'Dzień wolny';
        } else if (shift.type == 'sick') {
          leadingIcon = Icons.medical_services_rounded;
          accentColor = Colors.redAccent;
          subtitleText = 'Zasiłek chorobowy';
          // Delikatna czerwień, która nie bije po oczach w ciemności
          bgColor = Colors.red.withOpacity(0.1);
        } else {
          leadingIcon = shift.isCompleted
              ? Icons.check_circle_rounded
              : Icons.pending_actions_rounded;
          accentColor = shift.isCompleted ? Colors.green : Colors.orange;
          subtitleText =
              '${shift.startTime.format(context)} - ${shift.endTime.format(context)}';
        }

        return Dismissible(
          key: Key(shift.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            setState(() => shifts.removeWhere((s) => s.id == shift.id));
            _saveShifts();
          },
          child: Card(
            color: bgColor, // Używa koloru z motywu!
            child: ListTile(
              onTap: () => _openShiftForm(shift),
              leading: Icon(leadingIcon, color: accentColor),
              title: Text(
                '$titleText, ${dayName[0].toUpperCase()}${dayName.substring(1)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(subtitleText),
              trailing: Text(
                '${shift.estimatedPay.toStringAsFixed(2)} zł',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab() {
    final filteredShifts = _getFilteredShifts();
    double actualPay = 0;
    double plannedPay = 0;
    int workDays = 0;
    int offDays = 0;
    int sickDays = 0;

    for (var shift in filteredShifts) {
      if (shift.type == 'off')
        offDays++;
      else if (shift.type == 'sick') {
        sickDays++;
        actualPay += shift.estimatedPay;
      } else {
        workDays++;
        if (shift.isCompleted)
          actualPay += shift.estimatedPay;
        else
          plannedPay += shift.estimatedPay;
      }
    }

    // Pobieramy kolor tekstu z motywu (czarny w dzień, biały w nocy)
    Color textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'FINANSE MIESIĄCA',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildIosCard(
          child: Column(
            children: [
              _buildIosRow(
                'Zarobione',
                '${actualPay.toStringAsFixed(2)} zł',
                Colors.green,
              ),
              const Divider(height: 1, indent: 16),
              _buildIosRow(
                'W planach',
                '${plannedPay.toStringAsFixed(2)} zł',
                Colors.orange,
              ),
              const Divider(height: 1, indent: 16),
              _buildIosRow(
                'Łącznie',
                '${(actualPay + plannedPay).toStringAsFixed(2)} zł',
                textColor,
                isBold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            'STATYSTYKI DNI',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildIosCard(
          child: Column(
            children: [
              _buildIosRow('Praca', '$workDays dni', textColor),
              const Divider(height: 1, indent: 16),
              _buildIosRow('Wolne', '$offDays dni', Colors.blueGrey),
              const Divider(height: 1, indent: 16),
              _buildIosRow('L4', '$sickDays dni', Colors.redAccent),
            ],
          ),
        ),
      ],
    );
  }

  // POPRAWIONY WIDGET: Używa koloru karty z aktualnego motywu
  Widget _buildIosCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).cardTheme.color, // Automatyczna zmiana biały/szary
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );

  Widget _buildIosRow(
    String title,
    String value,
    Color color, {
    bool isBold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
