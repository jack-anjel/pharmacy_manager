/// lib/services/workmanager_callback.dart

import 'package:workmanager/workmanager.dart';
import 'local_notifications_service.dart';
import 'medicine_store.dart';
import 'database.dart';

const String taskCheckDaily = "taskCheckDaily";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == taskCheckDaily) {
      // تهيئة قاعدة البيانات والـ MedicineStore
      final db = AppDatabase();
      final store = MedicineStore.instance(db);
      // نحتاج فِلترة لاحقًا إن أردنا تمرير المُشاهد navigatorKey — لكنّنا في الخلفية هنا

      // تهيئة إشعارات
      await LocalNotificationsService.initialize(null);

      // فحص يومي وإرسال إشعارات
      await LocalNotificationsService.checkAndNotifyDaily();
      return Future.value(true);
    }
    return Future.value(false);
  });
}


