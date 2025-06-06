// lib/services/medicine_store.dart

import 'package:flutter/material.dart';
import 'package:drift/drift.dart'; // لأجل استخدام `Value<...>`
import 'database.dart';

/// MedicineStore يستخدم قاعدة البيانات عبر Drift بدلاً من SharedPreferences
class MedicineStore extends ChangeNotifier {
  final AppDatabase _db;

  // قائمة الأدوية مع دفعاتها (Stream-based)
  List<MedicineWithBatches> _medicinesWithBatches = [];
  List<MedicineWithBatches> get medicinesWithBatches =>
      List.unmodifiable(_medicinesWithBatches);

  // Singleton pattern
  static MedicineStore? _instance;
  factory MedicineStore.instance(AppDatabase db) {
    _instance ??= MedicineStore._internal(db);
    return _instance!;
  }
  MedicineStore._internal(this._db) {
    _listenToMedicines();
  }

  /// يستمع للتغييرات في الجداول ويُحدث القائمة أوتوماتيكيًا
  void _listenToMedicines() {
    _db.watchAllMedicinesWithBatches().listen((rows) {
      _medicinesWithBatches = rows;
      notifyListeners();
    });
  }

  /// جلب تفاصيل دواء واحد (بشكل مباشر، عند الحاجة)
  Future<MedicineWithBatches?> getMedicineDetail(int id) async {
    try {
      final med = await _db.getMedicineById(id);
      final batches = await _db.getBatchesForMedicine(id);
      return MedicineWithBatches(medicine: med, batches: batches);
    } catch (_) {
      return null;
    }
  }

  /// إضافة دواء جديد، يعيد الـ ID الجديد
  Future<int> addMedicine({
    required String name,
    required String category,
    String? price,
    String? company,
  }) async {
    final companion = MedicinesCompanion(
      name: Value(name),
      category: Value(category),
      price: Value(price),
      company: Value(company),
      isMuted: const Value(false),
    );
    return await _db.insertMedicine(companion);
  }

  /// تحديث بيانات دواء موجود (تحتاج أن تمرر الـ DataClass `Medicine`)
  Future<void> updateMedicine(Medicine updated) async {
    await _db.updateMedicineData(updated);
    // لاحظ أن الـ Stream سيتعامل مع notifyListeners()
  }

  /// حذف دواء (ستُحذف دفعاته بسبب ON DELETE CASCADE)
  Future<void> deleteMedicine(int id) async {
    await _db.deleteMedicineById(id);
  }

  /// كتم/إلغاء كتم الإشعار لدواء معين
  Future<void> toggleMute(int id) async {
    final med = await _db.getMedicineById(id);
    final updated = med.copyWith(isMuted: !med.isMuted);
    await _db.updateMedicineData(updated);
  }

  /// إضافة دفعة صلاحية جديدة لأي دواء
  Future<int> addBatch({
    required int medicineId,
    required DateTime expiryDate,
    required int quantity,
  }) async {
    final companion = ExpiryBatchesCompanion(
      medicineId: Value(medicineId),
      expiryDate: Value(expiryDate),
      quantity: Value(quantity),
    );
    return await _db.insertBatch(companion);
  }

  /// حذف دفعة صلاحية
  Future<void> deleteBatch(int batchId) async {
    await _db.deleteBatchById(batchId);
  }

  /// تحديث دفعة صلاحية (تغيير التاريخ أو الكمية)
  Future<void> updateBatch(ExpiryBatche batch) async {
    await _db.updateBatch(batch);
  }

  /// إعادة فحص الإشعارات صباحًا (مثال على وظيفة حساب التنبيهات)
  int countNotificationsToShow() {
    final now = DateTime.now();
    int count = 0;
    for (var entry in _medicinesWithBatches) {
      final m = entry.medicine;
      if (m.isMuted) continue;

      // فحص الانخفاض في الكمية
      final totalQty =
          entry.batches.fold<int>(0, (sum, b) => sum + b.quantity);
      if (totalQty <= 60) {
        count++;
        continue;
      }

      // فحص قرب الانتهاء أو انتهاء الصلاحية
      for (var e in entry.batches) {
        final d = e.expiryDate;
        final diff = d.difference(now).inDays;
        if (d.isBefore(now) || (diff > 0 && diff <= 180)) {
          count++;
          break;
        }
      }
    }
    return count;
  }
}


