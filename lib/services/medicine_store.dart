/// lib/services/medicine_store.dart

import 'package:flutter/material.dart';
import 'database.dart';

/// MedicineStore يستخدم Drift بدلاً من SharedPreferences لقراءة/كتابة الأدوية ودفعاتها.
class MedicineStore extends ChangeNotifier {
  final AppDatabase _db;

  // قائمة الأدوية مع دفعاتها
  List<MedicineWithBatches> _medicinesWithBatches = [];
  List<MedicineWithBatches> get medicinesWithBatches =>
      List.unmodifiable(_medicinesWithBatches);

  // —— Singleton pattern ——
  static MedicineStore? _instance;
  factory MedicineStore.instance(AppDatabase db) {
    _instance ??= MedicineStore._internal(db);
    return _instance!;
  }
  MedicineStore._internal(this._db) {
    _listenToMedicines();
  }

  // يستمع للتغييرات في الجداول ويُحدّث القائمة
  void _listenToMedicines() {
    _db.watchAllMedicinesWithBatches().listen((rows) {
      _medicinesWithBatches = rows;
      notifyListeners();
    });
  }

  /// إضافة دواء جديد
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

  /// تحديث بيانات دواء
  Future<void> updateMedicine(MedicineData updated) async {
    await _db.updateMedicineData(updated);
    // الـ Stream سيقوم بعمل notifyListeners()
  }

  /// حذف دواء (✅ دفعاته تُحذَف أوتوماتيكيًّا بسبب ON DELETE CASCADE)
  Future<void> deleteMedicine(int id) async {
    await _db.deleteMedicineById(id);
  }

  /// كتم/إلغاء كتم دواء معيّن
  Future<void> toggleMute(int id) async {
    final med = await _db.getMedicineById(id);
    final updated = med.copyWith(isMuted: !med.isMuted);
    await _db.updateMedicineData(updated);
  }

  /// إضافة دفعة صلاحية جديدة
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

  /// تحديث دفعة صلاحية
  Future<void> updateBatch(ExpiryBatchData batch) async {
    await _db.updateBatch(batch);
  }

  /// احتساب عدد التنبيهات التي يجب إظهارها (ينبغي استدعاؤها في الشارة)
  int countNotificationsToShow() {
    final now = DateTime.now();
    int count = 0;
    for (var entry in _medicinesWithBatches) {
      final m = entry.medicine;
      if (m.isMuted) continue;

      // 1. كمية منخفضة ≤ 60
      final totalQty =
          entry.batches.fold<int>(0, (sum, b) => sum + b.quantity);
      if (totalQty <= 60) {
        count++;
        continue;
      }

      // 2. انتهت صلاحية أو قريبة من الانتهاء (≤ 180 يوم)
      for (var e in entry.batches) {
        final diff = e.expiryDate.difference(now).inDays;
        if (e.expiryDate.isBefore(now) || (diff > 0 && diff <= 180)) {
          count++;
          break;
        }
      }
    }
    return count;
  }
}


