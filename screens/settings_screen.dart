import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/app_settings.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hourlyController = TextEditingController();
  final _averageController = TextEditingController();
  final _bonusController = TextEditingController(); // NOWE
  String _contractType = 'uop';
  bool _isDarkMode = false;
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
      final settings = AppSettings.fromJson(jsonDecode(data));
      setState(() {
        _hourlyController.text = settings.hourlyRate.toString();
        _averageController.text = settings.averageMonthlyNet.toString();
        _bonusController.text = settings.holidayBonus.toString();
        _contractType = settings.contractType;
        _isDarkMode = settings.isDarkMode;
        _customHolidays = settings.customHolidays;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(
      hourlyRate: double.tryParse(_hourlyController.text) ?? 29.0,
      averageMonthlyNet: double.tryParse(_averageController.text) ?? 4500.0,
      holidayBonus: double.tryParse(_bonusController.text) ?? 4.0,
      contractType: _contractType,
      isDarkMode: _isDarkMode,
      customHolidays: _customHolidays,
    );
    await prefs.setString('app_settings', jsonEncode(settings.toJson()));
    themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ustawienia zapisane!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Funkcja do dodawania nowego święta firmowego
  Future<void> _addHoliday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null &&
        !_customHolidays.any(
          (d) =>
              d.year == picked.year &&
              d.month == picked.month &&
              d.day == picked.day,
        )) {
      setState(() {
        _customHolidays.add(picked);
        _customHolidays.sort();
      });
      _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'WYGLĄD',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingsCard([
          ListTile(
            leading: Icon(
              Icons.dark_mode,
              color: _isDarkMode ? Colors.purple : Colors.orange,
            ),
            title: const Text('Tryb Ciemny'),
            trailing: CupertinoSwitch(
              value: _isDarkMode,
              onChanged: (val) {
                setState(() => _isDarkMode = val);
                _saveSettings();
              },
            ),
          ),
        ]),
        const SizedBox(height: 24),
        const Text(
          'FINANSE (NETTO)',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _buildTextField(
            'Stawka godzinowa',
            _hourlyController,
            Icons.payments,
          ),
          const Divider(height: 1, indent: 55),
          _buildTextField(
            'Dodatek świąteczny (zł/h)',
            _bonusController,
            Icons.star,
            color: Colors.amber,
          ),
          const Divider(height: 1, indent: 55),
          _buildTextField(
            'Średnia do L4',
            _averageController,
            Icons.account_balance_wallet,
          ),
        ]),
        const SizedBox(height: 24),
        const Text(
          'ŚWIĘTA FIRMOWE',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingsCard([
          ListTile(
            leading: const Icon(Icons.calendar_month, color: Colors.green),
            title: const Text('Dodaj święto firmy'),
            onTap: _addHoliday,
          ),
          if (_customHolidays.isNotEmpty) const Divider(height: 1, indent: 55),
          ..._customHolidays.map(
            (date) => ListTile(
              leading: const Icon(
                Icons.event_available,
                color: Colors.blue,
                size: 20,
              ),
              title: Text(
                DateFormat('dd.MM.yyyy (EEEE)', 'pl_PL').format(date),
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red,
                ),
                onPressed: () {
                  setState(() => _customHolidays.remove(date));
                  _saveSettings();
                },
              ),
            ),
          ),
        ]),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'ZAPISZ WSZYSTKO',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    Color color = Colors.blue,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        keyboardType: TextInputType.number,
      ),
    );
  }
}
