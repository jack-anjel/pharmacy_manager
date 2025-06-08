// lib/services/local_notifications_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../services/medicine_store.dart';
import '../services/database.dart';  // لـ AppDatabase

class LocalNotificationsService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// 1. تهيئة الإشعارات والـ Timezone
  static Future<void> initialize(GlobalKey<NavigatorState>? navigatorKey) async {
    // 1.a. تهيئة مكتبة الـ timezone
    tz.initializeTimeZones();

    // 1.b. نطلب إذن الإشعارات على iOS (DARWIN) فقط؛
    //     على Android 13+ كافٍ وضع الـ <uses-permission> في manifest
    await _requestPermissionsIOS();

    // 2. إعدادات التهيئة لكل منصة
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == 'go_to_notifications') {
          if (navigatorKey != null) {
            navigatorKey.currentState?.pushNamed('/');
          }
        }
      },
    );
  }

  /// طلب الأذونات اللازمة على iOS فقط
  static Future<void> _requestPermissionsIOS() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// 2. جدولة تذكير يومي
  static Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'التذكير اليومي',
            channelDescription: 'قناة التذكير اليومي للصيدلية',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e) {
      // تجاهل خطأ "Exact alarms are not permitted" أو أي خطأ آخر
      debugPrint('⚠️ scheduleDailyReminder failed: $e');
    }
  }

  /// 3. تشغيل التحقق وعرض الإشعار الصباحي (إذا كان هناك دواء بحاجة إلى انتباه)
  static Future<void> checkAndNotifyDaily() async {
    final db    = AppDatabase();
    final store = MedicineStore.instance(db);

    // ننتظر قليلًا لتمرير البيانات إن وجدت
    await Future.delayed(const Duration(milliseconds: 500));

    final count = store.countNotificationsToShow();
    if (count > 0) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'expiry_alert_channel',
        'تنبيهات الصلاحية والكمية',
        channelDescription: 'تنبيهات خاصة بانتهاء الصلاحية وانخفاض الكمية',
        importance: Importance.max,
        priority: Priority.high,
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      try {
        await _notificationsPlugin.show(
          1000,
          'تنبيه الأدوية',
          'هناك $count منتج بحاجة إلى انتباهك.',
          NotificationDetails(android: androidDetails, iOS: iosDetails),
          payload: 'go_to_notifications',
        );
      } catch (e) {
        debugPrint('⚠️ Unable to show daily alert notification: $e');
      }
    }
  }
}
