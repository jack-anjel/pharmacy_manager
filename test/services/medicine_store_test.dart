// test/services/medicine_store_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_manager/services/database.dart';
import 'package:pharmacy_manager/services/medicine_store.dart';

void main() {
  late AppDatabase db;
  late MedicineStore store;

  setUp(() {
    // ستستخدم قاعدة البيانات الافتراضية (تخزّن في ملف)،
    // أو إذا أضفتَ مُنشئًا يقبل QueryExecutor—تستطيع هنا حقن NativeDatabase.memory().
    db = AppDatabase();
    store = MedicineStore.instance(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('الـ store يبدأ فارغًا', () {
    expect(store.medicines, isEmpty);
  });

  test('إضافة وحذف دواء', () async {
    // 1) أضف دواءً جديدًا
    await store.addMedicine(
      name: 'TestMed',
      category: 'TestCat',
      price: null,
      company: null,
    );
    // انتظر قليلًا حتى يستقبل الـ stream التحديث
    await Future.delayed(const Duration(milliseconds: 50));

    expect(store.medicines.length, 1);
    final added = store.medicines.first;
    expect(added.name, equals('TestMed'));

    // 2) احذف الدواء
    await store.deleteMedicine(added.id!);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(store.medicines, isEmpty);
  });

  test('تبديل كتم التنبيه (mute)', () async {
    await store.addMedicine(
      name: 'MuteMed',
      category: 'SomeCat',
      price: null,
      company: null,
    );
    await Future.delayed(const Duration(milliseconds: 50));

    final m = store.medicines.first;
    // افتراضيًا غير مكتوم
    expect(m.isMuted, isFalse);

    // كتم
    store.toggleMute(m.id!);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.medicines.first.isMuted, isTrue);

    // إلغاء الكتم
    store.toggleMute(m.id!);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.medicines.first.isMuted, isFalse);
  });
}
