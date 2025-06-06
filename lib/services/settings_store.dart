/// lib/services/settings_store.dart
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _darkModeKey = 'dark_mode';
const String _categoriesKey = 'categories_list';

class SettingsStore extends ChangeNotifier {
  bool _isDarkMode = false;
  List<String> _categories = [];

  bool get isDarkMode => _isDarkMode;
  List<String> get categories => List.unmodifiable(_categories);

  SettingsStore() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    _categories = prefs.getStringList(_categoriesKey) ?? <String>[];
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool val) async {
    _isDarkMode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> addCategory(String newCat) async {
    _categories.insert(0, newCat);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoriesKey, _categories);
    notifyListeners();
  }

  Future<void> removeCategory(int index) async {
    _categories.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoriesKey, _categories);
    notifyListeners();
  }
}

