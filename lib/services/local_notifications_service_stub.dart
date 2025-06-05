// lib/services/local_notifications_stub.dart

/// هذا ملف "stub" للإشعارات عند التشغيل على الويب.
/// جميع الدوال هنا فارغة (لا تفعل شيئًا)، ولكنها تمنع أخطاء الاستيراد
/// عند بناء التطبيق للويب.
library;


class LocalNotificationsService {
  /// تهيئة خدمة الإشعارات (لا تفعل شيئًا على الويب)
  static Future<void> initialize() async {
    // لا شيء على الويب
  }

  /// جدولة تذكير يومي (لا تفعل شيئًا على الويب)
  /// المعاملات هنا تطابق واجهة دالة scheduleDailyReminder الأصلية
  static Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    // لا شيء على الويب
  }

  /// عرض إشعار فوري (لا تفعل شيئًا على الويب)
  /// المعاملات هنا تطابق واجهة دالة showImmediateAlert الأصلية
  static Future<void> showImmediateAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // لا شيء على الويب
  }
}
