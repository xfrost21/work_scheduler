import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Dla przełącznika iOS
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';
import '../main.dart'; // Importujemy themeNotifier

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hourlyController = TextEditingController();
  final _averageController = TextEditingController();
  String _contractType = 'uop';
  bool _isDarkMode = false;

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
        _contractType = settings.contractType;
        _isDarkMode = settings.isDarkMode;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(
      hourlyRate: double.tryParse(_hourlyController.text) ?? 29.0,
      averageMonthlyNet: double.tryParse(_averageController.text) ?? 4500.0,
      contractType: _contractType,
      isDarkMode: _isDarkMode,
    );
    await prefs.setString('app_settings', jsonEncode(settings.toJson()));

    // NOWE: Aktualizujemy motyw w całej aplikacji natychmiast!
    themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ustawienia zapisane!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _saveSettings(); // Zapisujemy od razu po przełączeniu
              },
            ),
          ),
        ]),
        const SizedBox(height: 24),
        const Text(
          'STAWKI (NETTO)',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingsCard([
          _buildTextField('Godzinówka', _hourlyController, Icons.payments),
          const Divider(height: 1, indent: 55),
          _buildTextField(
            'Średnia do L4',
            _averageController,
            Icons.account_balance,
          ),
        ]),
        const SizedBox(height: 24),
        const Text(
          'UMOWA',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingsCard([
          ListTile(
            leading: const Icon(Icons.description, color: Colors.blue),
            title: const Text('Typ'),
            trailing: DropdownButton<String>(
              value: _contractType,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'uop', child: Text('O Pracę')),
                DropdownMenuItem(value: 'uz', child: Text('Zlecenie')),
              ],
              onChanged: (val) => setState(() => _contractType = val!),
            ),
          ),
        ]),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
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
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        keyboardType: TextInputType.number,
      ),
    );
  }
}
