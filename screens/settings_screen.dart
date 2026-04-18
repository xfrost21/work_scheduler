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
  final _extraAllowanceController = TextEditingController();
  final _averageController = TextEditingController();
  final _bonusController = TextEditingController();
  final _goalNameController = TextEditingController();
  final _goalTargetController = TextEditingController();

  String _contractType = 'uop';
  double _employmentFte = 0.75;
  bool _isDarkMode = false;
  bool _isStudent = true;
  bool _isUnder26 = true;

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
        _extraAllowanceController.text = s.extraAllowance.toString();
        _averageController.text = s.averageMonthlyNet.toString();
        _bonusController.text = s.holidayBonus.toString();
        _goalNameController.text = s.goalName;
        _goalTargetController.text = s.goalTarget.toString();
        _contractType = s.contractType;
        _employmentFte = s.employmentFte;
        _isDarkMode = s.isDarkMode;
        _isStudent = s.isStudent;
        _isUnder26 = s.isUnder26;
      });
    }
  }

  // Funkcja czyszcząca tekst z przecinków na kropki przed parmowaniem
  double _parseInput(String val) =>
      double.tryParse(val.replaceAll(',', '.')) ?? 0.0;

  double _calculateDynamicNet(
    double gross,
    double extra,
    String type,
    bool young,
    bool student,
  ) {
    if (type == 'uz' && student && young) return gross + extra;
    double zus = gross * 0.1371;
    double health = (gross - zus) * 0.09;
    double pit = young ? 0 : (gross - zus) * 0.12;
    return double.parse(
      (gross - zus - health - pit + extra).toStringAsFixed(2),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    double gross = _parseInput(_grossController.text);
    double extra = _parseInput(_extraAllowanceController.text);
    double net = _calculateDynamicNet(
      gross,
      extra,
      _contractType,
      _isUnder26,
      _isStudent,
    );

    final settings = AppSettings(
      hourlyRateGross: gross,
      hourlyRateNet: net,
      extraAllowance: extra,
      contractType: _contractType,
      employmentFte: _employmentFte,
      isUnder26: _isUnder26,
      isStudent: _isStudent,
      isDarkMode: _isDarkMode,
      goalName: _goalNameController.text,
      goalTarget: _parseInput(_goalTargetController.text),
      holidayBonus: _parseInput(_bonusController.text),
    );

    await prefs.setString('app_settings', jsonEncode(settings.toJson()));
    await _recalculateAllShifts(settings);
    themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;

    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zaktualizowano! Nowa stawka: $net zł'),
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
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text('Wymiar Etatu'),
            trailing: DropdownButton<double>(
              value: _employmentFte,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 1.0, child: Text('Pełny (1/1)')),
                DropdownMenuItem(value: 0.75, child: Text('3/4 etatu')),
                DropdownMenuItem(value: 0.5, child: Text('1/2 etatu')),
              ],
              onChanged: (v) => setState(() => _employmentFte = v!),
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
            'Dodatki (np. pranie zł/h)',
            _extraAllowanceController,
            Icons.wash,
          ),
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
          _buildField(
            'Nazwa celu',
            _goalNameController,
            Icons.flag,
            kType: TextInputType.text,
          ),
          const Divider(height: 1, indent: 55),
          _buildField('Kwota celu', _goalTargetController, Icons.savings),
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
    TextInputType kType = const TextInputType.numberWithOptions(decimal: true),
  }) => ListTile(
    leading: Icon(i, color: color),
    title: TextField(
      controller: c,
      decoration: InputDecoration(labelText: l, border: InputBorder.none),
      keyboardType: kType,
    ),
  );
}
