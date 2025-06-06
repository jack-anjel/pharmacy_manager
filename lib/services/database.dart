// lib/services/database.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

/// جدول دفعات الصلاحية المرتبطة بكل دواء
class ExpiryBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicineId =>
      integer().customConstraint('REFERENCES medicines(id) ON DELETE CASCADE')();
  DateTimeColumn get expiryDate => dateTime()();
  IntColumn get quantity => integer()();
}

/// قاعدة البيانات التي تجمع الجدولين أعلاه
@DriftDatabase(tables: [Medicines, ExpiryBatches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ===== دوال CRUD للأدوية =====

  /// تُعيد قائمة كل الأدوية (كل صف في جدول Medicines يُمثَّل بواسطة DataClass اسمه `Medicine`)
  Future<List<Medicine>> getAllMedicines() => select(medicines).get();

  /// تستمع إلى جدول الأدوية ودفعاتها معًا في Stream واحد
  Stream<List<MedicineWithBatches>> watchAllMedicinesWithBatches() {
    final query = select(medicines).join([
      leftOuterJoin(
        expiryBatches,
        expiryBatches.medicineId.equalsExp(medicines.id),
      ),
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

  /// جلب بيانات دواء واحد بحسَب الـ ID (يعيد `Medicine`)
  Future<Medicine> getMedicineById(int id) =>
      (select(medicines)..where((t) => t.id.equals(id))).getSingle();

  /// إضافة دواء جديد (يعيد ID السطر المضاف)
  Future<int> insertMedicine(MedicinesCompanion entry) =>
      into(medicines).insert(entry);

  /// تحديث صف دواء موجود (تأخذ الـ DataClass `Medicine`)
  Future<bool> updateMedicineData(Medicine med) =>
      update(medicines).replace(med);

  /// حذف دواء بالـ ID
  Future<int> deleteMedicineById(int id) =>
      (delete(medicines)..where((t) => t.id.equals(id))).go();

  // ===== دوال CRUD لدفعات الصلاحية =====

  /// تُعيد قائمة دفعات الصلاحية لـ `medicineId` معطى (يعيد `List<ExpiryBatche>`)
  Future<List<ExpiryBatche>> getBatchesForMedicine(int medicineId) {
    return (select(expiryBatches)
          ..where((tbl) => tbl.medicineId.equals(medicineId)))
        .get();
  }

  /// إدخال دفعة جديدة (تأخذ Companion)
  Future<int> insertBatch(ExpiryBatchesCompanion entry) =>
      into(expiryBatches).insert(entry);

  /// تحديث دفعة (تأخذ الـ DataClass `ExpiryBatche`)
  Future<bool> updateBatch(ExpiryBatche batch) =>
      update(expiryBatches).replace(batch);

  /// حذف دفعة بالـ ID
  Future<int> deleteBatchById(int id) =>
      (delete(expiryBatches)..where((t) => t.id.equals(id))).go();
}

/// فتح اتصال بقاعدة بيانات محلية داخل مجلد التطبيق
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pharmacy_manager.sqlite'));
    return VmDatabase(file);
  });
}

/// هيكل مساعد يجمع دواءً مع دفعاته (One-to-Many)
class MedicineWithBatches {
  final Medicine medicine;
  final List<ExpiryBatche> batches;

  MedicineWithBatches({
    required this.medicine,
    required this.batches,
  });
}
