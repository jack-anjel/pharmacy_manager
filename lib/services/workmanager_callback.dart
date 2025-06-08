// lib/services/workmanager_callback.dart

import 'package:workmanager/workmanager.dart';
import 'package:pharmacy_manager/services/local_notifications_service.dart';
import 'package:pharmacy_manager/services/medicine_store.dart';
import 'package:pharmacy_manager/services/database.dart';

const String taskCheckDaily = "taskCheckDaily";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == taskCheckDaily) {
      final db    = AppDatabase();
      final store = MedicineStore.instance(db);

      // تهيئة الإشعارات (في الخلفية)
      await LocalNotificationsService.initialize(null);
      await LocalNotificationsService.checkAndNotifyDaily();
      return Future.value(true);
    }
    return Future.value(false);
  });
}


