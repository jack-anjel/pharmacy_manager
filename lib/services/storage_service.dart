// lib/services/storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';

class StorageService {
  static const String _medicinesKey = 'medicines';

  /// يقرأ قائمة الأدوية من SharedPreferences ويعيدها.
  Future<List<Medicine>> loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_medicinesKey);
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => Medicine.fromJson(e)).toList();
  }

  /// يحفظ قائمة الأدوية في SharedPreferences.
  Future<void> saveMedicines(List<Medicine> list) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(list.map((m) => m.toJson()).toList());
    await prefs.setString(_medicinesKey, data);
  }
}
