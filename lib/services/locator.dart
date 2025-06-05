// lib/services/locator.dart

import 'package:get_it/get_it.dart';
import '../services/storage_service.dart';
import '../stores/medicine_store.dart';
import 'local_notifications_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<StorageService>(() => StorageService());
  locator.registerLazySingleton<MedicineStore>(() => MedicineStore());
  // لدالة تهيئة الإشعارات نُسجّلها كمستقبل (Future<void>) ثم نستدعيها في main()
  locator.registerLazySingleton<Future<void>>(() async {
    // إذا كنا على الهاتف فاستدعِ تهيئة الإشعارات؛ أما على الويب فالنسخة stub فارغة
    return await initNotifications();
  });
}
