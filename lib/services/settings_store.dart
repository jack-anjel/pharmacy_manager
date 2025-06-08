// lib/services/settings_store.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  bool _isDarkMode = false;
  List<String> _categories = [];

  bool get isDarkMode => _isDarkMode;
  List<String> get categories => List.unmodifiable(_categories);

  SettingsStore() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _categories = prefs.getStringList('categories') ?? [];
    notifyListeners();
  }

  Future<void> toggleDarkMode([bool? value]) async {
    _isDarkMode = value ?? !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  Future<void> addCategory(String newCat) async {
    _categories.insert(0, newCat);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('categories', _categories);
    notifyListeners();
  }

  Future<void> removeCategory(int index) async {
    _categories.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('categories', _categories);
    notifyListeners();
  }
}

