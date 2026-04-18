import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';
import '../models/work_shift.dart';
import '../utils/shift_calculator.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _grossController = TextEditingController();
  final _averageController = TextEditingController();
  final _bonusController = TextEditingController();
  final _goalNameController = TextEditingController();
  final _goalTargetController = TextEditingController();

  String _contractType = 'uop';
  bool _isDarkMode = false;
  bool _isStudent = true;
  bool _isUnder26 = true;
  List<DateTime> _customHolidays = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('app_settings');
    if (data != null) {
      final s = AppSettings.fromJson(jsonDecode(data));
      setState(() {
        _grossController.text = s.hourlyRateGross.toString();
        _averageController.text = s.averageMonthlyNet.toString();
        _bonusController.text = s.holidayBonus.toString();
        _goalNameController.text = s.goalName;
        _goalTargetController.text = s.goalTarget.toString();
        _contractType = s.contractType;
        _isDarkMode = s.isDarkMode;
        _isStudent = s.isStudent;
        _isUnder26 = s.isUnder26;
        _customHolidays = s.customHolidays;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    double gross = double.tryParse(_grossController.text) ?? 29.0;
    // Mnożnik ustawiony pod Twoje 23 zł netto
    double net = _isUnder26 && _contractType == 'uop'
        ? gross * 0.7931
        : gross * 0.71;
    if (_contractType == 'uz' && _isStudent && _isUnder26) net = gross;

    final settings = AppSettings(
      hourlyRateGross: gross,
      hourlyRateNet: net,
      useGross: true,
      averageMonthlyNet: double.tryParse(_averageController.text) ?? 4500.0,
      holidayBonus: double.tryParse(_bonusController.text) ?? 4.0,
      contractType: _contractType,
      isDarkMode: _isDarkMode,
      isStudent: _isStudent,
      isUnder26: _isUnder26,
      customHolidays: _customHolidays,
      goalName: _goalNameController.text,
      goalTarget: double.tryParse(_goalTargetController.text) ?? 0.0,
    );

    await prefs.setString('app_settings', jsonEncode(settings.toJson()));
    await _recalculateAllShifts(settings); // Automatyczna aktualizacja kwot
    themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;

    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zapisano! Grafik został przeliczony.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _recalculateAllShifts(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('my_work_shifts');
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      List<WorkShift> updated = decoded.map((item) {
        WorkShift s = WorkShift.fromJson(item);
        final res = ShiftCalculator.calculatePay(s, settings);
        return WorkShift(
          id: s.id,
          date: s.date,
          startTime: s.startTime,
          endTime: s.endTime,
          totalHours: res['total'],
          estimatedPay: res['pay'],
          isCompleted: s.isCompleted,
          type: s.type,
          notes: s.notes,
        );
      }).toList();
      await prefs.setString(
        'my_work_shifts',
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'STATUS I UMOWA',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        _buildCard([
          SwitchListTile(
            title: const Text('Status Studenta'),
            value: _isStudent,
            onChanged: (v) => setState(() => _isStudent = v),
          ),
          const Divider(height: 1, indent: 16),
          SwitchListTile(
            title: const Text('Wiek poniżej 26 lat'),
            value: _isUnder26,
            onChanged: (v) => setState(() => _isUnder26 = v),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text('Typ Umowy'),
            trailing: DropdownButton<String>(
              value: _contractType,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'uz', child: Text('Zlecenie')),
                DropdownMenuItem(value: 'uop', child: Text('O Pracę')),
              ],
              onChanged: (v) => setState(() => _contractType = v!),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        const Text(
          'FINANSE',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        _buildCard([
          _buildField('Stawka Brutto', _grossController, Icons.payments),
          const Divider(height: 1, indent: 55),
          _buildField(
            'Dodatek świąteczny',
            _bonusController,
            Icons.star,
            color: Colors.amber,
          ),
        ]),
        const SizedBox(height: 24),
        const Text(
          'CEL FINANSOWY',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        _buildCard([
          _buildField('Nazwa celu', _goalNameController, Icons.flag),
          const Divider(height: 1, indent: 55),
          _buildField('Kwota celu', _goalTargetController, Icons.savings),
        ]),
        const SizedBox(height: 24),
        const Text(
          'WYGLĄD',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        _buildCard([
          ListTile(
            leading: Icon(
              Icons.dark_mode,
              color: _isDarkMode ? Colors.purple : Colors.orange,
            ),
            title: const Text('Tryb Ciemny'),
            trailing: CupertinoSwitch(
              value: _isDarkMode,
              onChanged: (v) {
                setState(() => _isDarkMode = v);
                _saveSettings();
              },
            ),
          ),
        ]),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'ZAPISZ I AKTUALIZUJ GRAFIK',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> c) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: c),
  );
  Widget _buildField(
    String l,
    TextEditingController c,
    IconData i, {
    Color color = Colors.blue,
  }) => ListTile(
    leading: Icon(i, color: color),
    title: TextField(
      controller: c,
      decoration: InputDecoration(labelText: l, border: InputBorder.none),
      keyboardType: TextInputType.number,
    ),
  );
}
