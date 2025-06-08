import 'package:flutter/material.dart';
import 'package:drift/drift.dart';    // لـ Value و Companions
import 'database.dart' as dr;         // لاستيراد AppDatabase و DataClasses المولَّدة

import '../models/medicine.dart'      as model;
import '../models/expiry_batch.dart'  as batch_model;

/// هذا المخزّن يتواصل مع Drift ويُحافظ على قائمة من كلاسّاتنا الشخصية (model.Medicine)
class MedicineStore extends ChangeNotifier {
  final dr.AppDatabase _db;

  /// قائمة الأدوية (كلاسّاتنا الشخصية في lib/models/medicine.dart)
  List<model.Medicine> _medicines = [];
  List<model.Medicine> get medicines => List.unmodifiable(_medicines);

  static MedicineStore? _instance;
  factory MedicineStore.instance(dr.AppDatabase db) {
    _instance ??= MedicineStore._internal(db);
    return _instance!;
  }
  MedicineStore._internal(this._db) {
    _listenToMedicines();
  }

  /// يُراقب جدولَي Medicines و ExpiryBatches في قاعدة البيانات,
  /// ثم يحوّل كل صفّ (دواء + دفعات) إلى model.Medicine
  void _listenToMedicines() {
    _db.watchAllMedicinesWithBatches().listen((rowsDrift) {
      // rowsDrift هو List<MedicineWithBatches> من Drift
      final List<model.Medicine> temp = [];
      for (final entry in rowsDrift) {
        final dr.Medicine driftMed   = entry.medicine;      // DataClass “Medicine” من Drift
        final List<dr.ExpiryBatche> driftBatches = entry.batches;   // List<DataClass ExpiryBatche> من Drift

        // نحول كل دفعة إلى الكلاس الشخصيّ batch_model.ExpiryBatch
        final List<batch_model.ExpiryBatch> convertedBatches = driftBatches
            .map((b) => batch_model.ExpiryBatch.fromDrift(b))
            .toList();

        // ننشئ model.Medicine من الداتا مولَّدة + الدفعات المحولة
        final model.Medicine modelMed = model.Medicine.fromDrift(
          driftMed,
          convertedBatches,
        );
        temp.add(modelMed);
      }
      _medicines = temp;
      notifyListeners();
    });
  }

  /// يُعيد تفاصيل دواء وحيد (model.Medicine) حسب id
  Future<model.Medicine?> getMedicineDetail(int id) async {
    try {
      final dr.Medicine driftMed     = await _db.getMedicineById(id);
      final List<dr.ExpiryBatche> driftBatches = await _db.getBatchesForMedicine(id);
      final convertedBatches = driftBatches
          .map((b) => batch_model.ExpiryBatch.fromDrift(b))
          .toList();
      return model.Medicine.fromDrift(driftMed, convertedBatches);
    } catch (_) {
      return null;
    }
  }

  /// يضيف دواء جديد في قاعدة البيانات عن طريق Companion
  Future<int> addMedicine({
    required String name,
    required String category,
    String? price,
    String? company,
  }) async {
    final companion = dr.MedicinesCompanion(
      name: Value(name),
      category: Value(category),
      price: Value(price),
      company: Value(company),
      isMuted: const Value(false),
    );
    return await _db.insertMedicine(companion);
  }

  Future<void> updateMedicine(model.Medicine updated) async {
    /// هنا نحتاج نحوّل model.Medicine إلى DataClass Drift قبل التحديث.
    final dr.Medicine driftMed = dr.Medicine(
      id: updated.id!,
      name: updated.name,
      category: updated.category,
      price: updated.price,
      company: updated.company,
      isMuted: updated.isMuted,
    );
    await _db.updateMedicineData(driftMed);
  }

  Future<void> deleteMedicine(int id) async {
    await _db.deleteMedicineById(id);
  }

  Future<void> toggleMute(int id) async {
    final dr.Medicine driftMed = await _db.getMedicineById(id);
    final toggled = driftMed.copyWith(isMuted: !driftMed.isMuted);
    await _db.updateMedicineData(toggled);
  }

  Future<int> addBatch({
    required int medicineId,
    required DateTime expiryDate,
    required int quantity,
  }) async {
    final companion = dr.ExpiryBatchesCompanion(
      medicineId: Value(medicineId),
      expiryDate: Value(expiryDate),
      quantity: Value(quantity),
    );
    return await _db.insertBatch(companion);
  }

  Future<void> deleteBatch(int batchId) async {
    await _db.deleteBatchById(batchId);
  }

  Future<void> updateBatch(batch_model.ExpiryBatch batch) async {
    // نحوّل كلاسنا الشخصي إلى DataClass Drift قبل التحديث
    final dr.ExpiryBatche driftBatch = dr.ExpiryBatche(
      id: batch.id!,
      medicineId: batch.medicineId,
      expiryDate: batch.expiryDate,
      quantity: batch.quantity,
    );
    await _db.updateBatch(driftBatch);
  }

  /// يحسب عدد الأدوية التي تستوفي شرط التنبيه (انخفاض الكمية أو قرب انتهاء الصلاحية)
  int countNotificationsToShow() {
    final now = DateTime.now();
    int count = 0;
    for (var m in _medicines) {
      if (m.isMuted) continue;

      // 1. فحص انخفاض الكمية
      final totalQty = m.totalQuantity;
      if (totalQty <= 60) {
        count++;
        continue;
      }

      // 2. فحص قرب انتهاء الصلاحية (≤ 180 يوم)
      for (var e in m.expiries) {
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
