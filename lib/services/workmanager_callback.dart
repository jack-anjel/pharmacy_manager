// lib/services/workmanager_callback.dart

import 'package:workmanager/workmanager.dart';
import 'local_notifications_service.dart';
import 'medicine_store.dart';
import 'database.dart';

/// اسم المهمة الذي يستخدمه WorkManager لاستدعاء دالة الفحص اليومية.
const String taskCheckDaily = "taskCheckDaily";

/// هذه الدالة تُنفَّذ في الخلفية بواسطة WorkManager عندما يحين موعد المهمة.
/// من الضروري إضافة @pragma('vm:entry-point') حتى يستطيع AOT تجميعها.
/// بدون هذا التعليق، لن يجد WorkManager النقطة الأساسية `callbackDispatcher`.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == taskCheckDaily) {
      // ١. إنشاء/تهيئة قاعدة البيانات
      final db = AppDatabase();
      // ٢. تحميل بيانات الأدوية ودفعاتها
      final store = MedicineStore.instance(db);
      // ليس هناك داعٍ لاستدعاء loadAll لأننا نستمع للـ Stream تلقائيًا

      // ٣. تهيئة الإشعارات (من دون navigatorKey لأنّنا في الخلفية)
      await LocalNotificationsService.initialize(null);

      // ٤. استدعاء الفحص اليومي وإرسال إشعارات فورية إن وجدت أدوية تحتاج تنبيه
      await LocalNotificationsService.checkAndNotifyDaily();

      return Future.value(true);
    }
    return Future.value(false);
  });
}


