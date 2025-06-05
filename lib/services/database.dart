/// lib/services/database.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/expiry_batch.dart'; // فقط للتوضيح؛ لم نعد نستخدم ExpiryBatch هنا مباشرة.
import '../models/medicine.dart';     // فقط للتوضيح.

part 'database.g.dart';

/// جدول الأدوية
class Medicines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get category => text().withLength(min: 1, max: 50)();
  TextColumn get price => text().nullable()();
  TextColumn get company => text().nullable()();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
}

/// جدول دفعات الصلاحية المرتبط بكل دواء
class ExpiryBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicineId => integer().customConstraint(
      'REFERENCES medicines(id) ON DELETE CASCADE NOT NULL')();
  DateTimeColumn get expiryDate => dateTime()();
  IntColumn get quantity => integer()();
}

/// قاعدة البيانات
@DriftDatabase(tables: [Medicines, ExpiryBatches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ——— CRUD للأدوية ———

  Future<List<MedicineData>> getAllMedicines() => select(medicines).get();

  Stream<List<MedicineWithBatches>> watchAllMedicinesWithBatches() {
    final query = select(medicines).join([
      leftOuterJoin(expiryBatches,
          expiryBatches.medicineId.equalsExp(medicines.id)),
    ]);

    return query.watch().map((rows) {
      final Map<int, MedicineWithBatches> data = {};
      for (final row in rows) {
        final med = row.readTable(medicines);
        final batch = row.readTableOrNull(expiryBatches);

        final key = med.id;
        final entry = data.putIfAbsent(
          key,
          () => MedicineWithBatches(medicine: med, batches: []),
        );
        if (batch != null) {
          entry.batches.add(batch);
        }
      }
      return data.values.toList();
    });
  }

  Future<MedicineData> getMedicineById(int id) =>
      (select(medicines)..where((t) => t.id.equals(id))).getSingle();

  Future<int> insertMedicine(MedicinesCompanion entry) =>
      into(medicines).insert(entry);

  Future<bool> updateMedicineData(MedicineData med) =>
      update(medicines).replace(med);

  Future<int> deleteMedicineById(int id) =>
      (delete(medicines)..where((t) => t.id.equals(id))).go();

  // ——— CRUD لدفعات الصلاحية ———

  Future<List<ExpiryBatchData>> getBatchesForMedicine(int medicineId) {
    return (select(expiryBatches)
          ..where((tbl) => tbl.medicineId.equals(medicineId)))
        .get();
  }

  Future<int> insertBatch(ExpiryBatchesCompanion entry) =>
      into(expiryBatches).insert(entry);

  Future<bool> updateBatch(ExpiryBatchData batch) =>
      update(expiryBatches).replace(batch);

  Future<int> deleteBatchById(int id) =>
      (delete(expiryBatches)..where((t) => t.id.equals(id))).go();
}

/// فتح اتصال SQLite
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pharmacy_manager.sqlite'));
    return VmDatabase(file);
  });
}

/// هيكل مساعد يجمع دواءً مع دفعاته
class MedicineWithBatches {
  final MedicineData medicine;
  final List<ExpiryBatchData> batches;

  MedicineWithBatches({
    required this.medicine,
    required this.batches,
  });
}
