// lib/services/local_notifications_service_mobile.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/medicine.dart';

/// كائن داخلي لإدارة واجهة `flutter_local_notifications`
FlutterLocalNotificationsPlugin? _flutterPlugin;

/// متغيّر يبيّن ما إذا أُفعّلت الإشعارات محليًا (يُستخدم في الشيفرة كبديل للـ Switch).
bool notificationsEnabled = false;

/// تهيئة الإشعارات على الهاتف (Android/iOS). يستدعى من main().
Future<void> initNotifications() async {
  _flutterPlugin = FlutterLocalNotificationsPlugin();

  final androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final initSettings = InitializationSettings(android: androidInitSettings);

  await _flutterPlugin?.initialize(initSettings);

  // طلب إذن الإشعارات في Android 13+
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

/// عرض إشعار نصي على الهاتف (Android/iOS). يستدعى عندما نريد إرسال رسالة.
Future<void> showPharmacyNotification(String message) async {
  if (!notificationsEnabled || _flutterPlugin == null) return;

  final androidDetails = AndroidNotificationDetails(
    'pharmacy_channel',
    'تنبيهات الصيدلية',
    channelDescription: 'تنبيهات انخفاض الكمية أو انتهاء الصلاحية',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
  );

  final platformDetails = NotificationDetails(android: androidDetails);

  await _flutterPlugin!.show(
    0,
    'تنبيه صيدلي',
    message,
    platformDetails,
    payload: 'pharmacy_alert',
  );
}

/// فحص قائمة الأدوية وإرسال إشعار إذا وُجد دواء منخفض الكمية أو قريب انتهاء الصلاحية.
Future<void> checkAndNotify(List<Medicine> medicines) async {
  if (!notificationsEnabled || _flutterPlugin == null) return;

  final lowStock = medicines.where((m) => !m.muted && m.totalQuantity <= 60);
  final soonExpired = medicines.where((m) =>
      !m.muted &&
      m.expiries.any((e) {
        final diff = e.expiryDate.difference(DateTime.now()).inDays;
        return diff >= 0 && diff <= 180;
      }));

  String message = '';
  if (lowStock.isNotEmpty) {
    message += 'هناك ${lowStock.length} دواء كميته منخفضة.\n';
  }
  if (soonExpired.isNotEmpty) {
    message += 'هناك ${soonExpired.length} دواء قرب انتهاء صلاحيته.';
  }
  if (message.isNotEmpty) {
    await showPharmacyNotification(message);
  }
}
