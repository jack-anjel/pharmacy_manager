/// lib/services/local_notifications_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'medicine_store.dart';
import 'database.dart';

class LocalNotificationsService {
  static final _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @pragma('vm:entry-point')
  static Future<void> initialize(GlobalKey<NavigatorState>? navigatorKey) async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    tz.initializeTimeZones();

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == 'go_to_notifications' && navigatorKey != null) {
          navigatorKey.currentState?.pushNamed('/notification');
        }
      },
    );
  }

  static Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'daily_channel',
      'تذكير يومي',
      channelDescription: 'تذكير صباحي لفتح التنبيهات',
      importance: Importance.max,
      priority: Priority.high,
    );
    final iosDetails = DarwinNotificationDetails();
    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> checkAndNotifyDaily() async {
    final db = AppDatabase();
    final store = MedicineStore.instance(db);
    final now = DateTime.now();

    for (var entry in store.medicinesWithBatches) {
      final m = entry.medicine;
      if (m.isMuted) continue;

      // 1. فحص انخفاض كمية ≤ 60
      final totalQty =
          entry.batches.fold<int>(0, (sum, b) => sum + b.quantity);
      if (totalQty <= 60) {
        await _showImmediateNotification(
          id: m.id,
          title: 'كمية منخفضة: ${m.name}',
          body: 'الكمية المتبقية <= 60',
        );
        continue;
      }

      // 2. فحص قرب الانتهاء أو انتهاء الصلاحية
      for (var e in entry.batches) {
        final diff = e.expiryDate.difference(now).inDays;
        if (e.expiryDate.isBefore(now)) {
          await _showImmediateNotification(
            id: m.id * 100 + e.id,
            title: 'منتهي الصلاحية: ${m.name}',
            body:
                'الدفعة بتاريخ ${e.expiryDate.toLocal().toString().split(' ')[0]} منتهية.',
          );
          break;
        } else if (diff > 0 && diff <= 180) {
          await _showImmediateNotification(
            id: m.id * 100 + e.id,
            title: 'قريبة الانتهاء: ${m.name}',
            body:
                'الدفعة بتاريخ ${e.expiryDate.toLocal().toString().split(' ')[0]} قريب على الانتهاء.',
          );
          break;
        }
      }
    }
  }

  static Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'immediate_channel',
      'الإشعارات الفورية',
      channelDescription: 'إشعارات عند انتهاء/قرب انتهاء أو انخفاض كمية',
      importance: Importance.max,
      priority: Priority.high,
    );
    final iosDetails = DarwinNotificationDetails();
    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: 'go_to_notifications',
    );
  }
}
