// lib/services/local_notifications_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;

class LocalNotificationsService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// يجب استدعاء tzData.initializeTimeZones() قبل أي جدولة زمنية
  static Future<void> initialize(GlobalKey<NavigatorState>? navKey) async {
    // 1. إعداد معلومات الصلاحيات لكل منصة
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload == 'go_to_notifications' && navKey != null) {
          navKey.currentState?.pushNamed('/notifications');
        }
      },
    );

    // 2. تهيئة المنطقة الزمنية المحلية
    tzData.initializeTimeZones();
    final String localName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localName));
  }

  /// جدولة تذكير يومي ثابت
  static Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    final time = Time(hour, minute, 0); // صيغة 24‐ساعي: hh:mm:ss

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'تذكير يومي',
          channelDescription: 'تذكير صباحي بمراقبة الأدوية',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
      matchDateTimeComponents: DateTimeComponents.time, // يوميًا في نفس الوقت
      payload: payload,
    );
  }

  /// حساب أول موعد مقبل للتذكير اليومي
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// تحقق يومي في الـ background (من WorkManager)
  static Future<void> checkAndNotifyDaily() async {
    // استدعِ هنا MedicineStore.instance() لكن بِدون NotifyListeners
    final store = MedicineStore.instance();

    final meds = store.medicinesWithBatches;
    final now = DateTime.now();

    for (var entry in meds) {
      final med = entry.medicine;
      if (med.isMuted) continue;

      // 1. إذا الكمية المنخفضة
      final totalQty = entry.batches.fold<int>(0, (sum, b) => sum + b.quantity);
      if (totalQty <= 60) {
        await _sendImmediateNotification(
          id: med.id,
          title: 'كمية منخفضة لدواء: ${med.name}',
          body: 'الكمية المتبقية $totalQty ≤ 60',
        );
        continue;
      }

      // 2. إذا قرب انتهاء الصلاحية أو انتهت
      for (var b in entry.batches) {
        final expiry = b.expiryDate!;
        final diffDays = expiry.difference(now).inDays;
        if (expiry.isBefore(now)) {
          await _sendImmediateNotification(
            id: med.id + 1000, // استخدم معرّف مختلف
            title: 'انتهت صلاحية دواء: ${med.name}',
            body: 'الصلاحية انتهت منذ ${-diffDays} يوم',
          );
          break;
        } else if (diffDays <= 180) {
          await _sendImmediateNotification(
            id: med.id + 2000,
            title: 'قرب انتهاء صلاحية دواء: ${med.name}',
            body: 'يتبقى $diffDays يومًا على انتهاء الصلاحية',
          );
          break;
        }
      }
    }
  }

  /// إرسال إشعار فوري واحد
  static Future<void> _sendImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'immediate_channel',
          'التنبيهات الفورية',
          channelDescription: 'قناتك للإشعارات الفورية من الصيدلية',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
