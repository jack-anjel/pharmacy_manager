// lib/services/database.dart

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// جدول الأدوية
class Medicines extends Table {
  IntColumn get id        => integer().autoIncrement()();
  TextColumn get name     => text().withLength(min: 1, max: 100)();
  TextColumn get category => text().withLength(min: 1, max: 50)();
  TextColumn get price    => text().nullable()();
  TextColumn get company  => text().nullable()();
  BoolColumn get isMuted  => boolean().withDefault(const Constant(false))();
}

/// جدول دفعات الصلاحية المرتبطة بكل دواء
class ExpiryBatches extends Table {
  IntColumn get id          => integer().autoIncrement()();
  IntColumn get medicineId  =>
      integer().customConstraint('REFERENCES medicines(id) ON DELETE CASCADE')();
  DateTimeColumn get expiryDate => dateTime()();
  IntColumn get quantity    => integer()();
}

@DriftDatabase(tables: [Medicines, ExpiryBatches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ======== CRUD للأدوية ========

  /// يسترجع قائمة DataClass<Medicine> كاملة
  Future<List<Medicine>> getAllMedicines() => select(medicines).get();

  /// يرصد دواءً واحدًا حسب الـ id ثمّ يعود DataClass<Medicine>
  Future<Medicine> getMedicineById(int id) =>
      (select(medicines)..where((t) => t.id.equals(id))).getSingle();

  /// يدرج دواءً جديدًا (Companion)
  Future<int> insertMedicine(MedicinesCompanion entry) =>
      into(medicines).insert(entry);

  /// يحدّث بيانات دواء (يستقبل DataClass<Medicine>)
  Future<bool> updateMedicineData(Medicine med) =>
      update(medicines).replace(med);

  /// يحذف دواءً حسب الـ id
  Future<int> deleteMedicineById(int id) =>
      (delete(medicines)..where((t) => t.id.equals(id))).go();

  // ======== CRUD لدفعات الصلاحية ========

  /// يسترجع قائمة DataClass<ExpiryBatche> خاصّة بدواء معيّن
  Future<List<ExpiryBatche>> getBatchesForMedicine(int medicineId) {
    return (select(expiryBatches)
          ..where((tbl) => tbl.medicineId.equals(medicineId)))
        .get();
  }

  /// يدرج دفعة جديدة (Companion)
  Future<int> insertBatch(ExpiryBatchesCompanion entry) =>
      into(expiryBatches).insert(entry);

  /// يحدّث دفعة موجودة (يستقبل DataClass<ExpiryBatche>)
  Future<bool> updateBatch(ExpiryBatche batch) =>
      update(expiryBatches).replace(batch);

  /// يحذف دفعة حسب الـ id
  Future<int> deleteBatchById(int id) =>
      (delete(expiryBatches)..where((t) => t.id.equals(id))).go();
}

/// يفتح/ينشئ قاعدة البيانات محليًّا
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pharmacy_manager.sqlite'));
    return NativeDatabase(file, logStatements: true);
  });
}

/// نموذج يجمع بين DataClass<Medicine> و List<DataClass<ExpiryBatche>>
class MedicineWithBatches {
  final Medicine medicine;           // DataClass المولّد للمجدول “Medicines”
  final List<ExpiryBatche> batches;  // قائمة DataClass المولّد للمجدول “ExpiryBatches”

  MedicineWithBatches({
    required this.medicine,
    required this.batches,
  });
}

/// امتداد (extension) يُرجع Stream يقترن فيه كل دواء بدفعاته
extension AppDatabaseStreams on AppDatabase {
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
        final medDrift   = row.readTable(medicines);       // DataClass<Medicine>
        final batchDrift = row.readTableOrNull(expiryBatches); // DataClass<ExpiryBatche>؟

        final key = medDrift.id;
        final entry = data.putIfAbsent(
          key,
          () => MedicineWithBatches(medicine: medDrift, batches: []),
        );
        if (batchDrift != null) {
          entry.batches.add(batchDrift);
        }
      }
      return data.values.toList();
    });
  }
}
