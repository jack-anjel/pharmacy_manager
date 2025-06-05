// lib/services/medicine_store.dart

import 'package:flutter/material.dart';
import '../models/medicine.dart';

class MedicineStore extends ChangeNotifier {
  final List<Medicine> _medicines = [];

  List<Medicine> get medicines => _medicines;

  // إضافة دواء جديد
  void addMedicine(Medicine m) {
    _medicines.add(m);
    notifyListeners();
  }

  Future<void> _checkAndFireImmediateAlerts() async {
    final now = DateTime.now();
    for (var m in medicines) {
      if (m.isMuted) continue;
      // 1) فحص الكمية
      if (m.totalQuantity <= 60) {
        final key = 'quantity-${m.id}';
        if (!notificationsSentForQuantity.contains(key)) {
          // أرسل إشعارًا فوريًا
          await LocalNotificationsService.showImmediateAlert(
            title: 'كمية منخفضة',
            body: 'كمية الدواء "${m.name}" وصلت إلى ${m.totalQuantity}',
            id: Random().nextInt(100000), // أي معرف فريد
          );
          notificationsSentForQuantity.add(key);
        }
      }
      // 2) فحص الصلاحية
      for (var e in m.expiries) {
        if (e.expiryDate == null) continue;
        final d = e.expiryDate!;
        final diff = d.difference(now).inDays;
        if (d.isBefore(now) || (diff > 0 && diff <= 180)) {
          final key = 'expiry-${m.id}-${d.toIso8601String()}';
          if (!notificationsSentForExpiry.contains(key)) {
            // أرسل إشعارًا فوريًا
            final status = d.isBefore(now) ? 'منتهت صلاحيتها' : 'قريبة من الانتهاء';
            await LocalNotificationsService.showImmediateAlert(
              title: status,
              body: 'الدواء "${m.name}" ${status == 'منتهت صلاحيتها' ? 'منتهت صلاحيتها بالفعل' : 'ستنتهي صلاحيتها في ${diff.abs()} يومًا'}',
              id: Random().nextInt(100000),
            );
            notificationsSentForExpiry.add(key);
          }
        }
      }
    }
    // بعد إرسال كل الإشعارات الجديدة، نحفظ الأعلام
    await saveMedicines();
  }

  // تحديث الدواء عند التعديل (باستقبال الفهرس والدواء المحدث)
  void updateMedicine(int index, Medicine updated) {
    if (index >= 0 && index < _medicines.length) {
      _medicines[index] = updated;
      notifyListeners();
    }
  }

  // حذف الدواء حسب الفهرس
  void deleteMedicine(int index) {
    if (index >= 0 && index < _medicines.length) {
      _medicines.removeAt(index);
      notifyListeners();
    }
  }

  // تبديل حالة الـ muted (كتم/تفعيل الإشعار) عند الفهرس
  void toggleMute(int widgetIndex, {required bool isMuted}) {
    if (widgetIndex >= 0 && widgetIndex < _medicines.length) {
      _medicines[widgetIndex].muted = isMuted;
      notifyListeners();
    }
  }

  // إعادة الدواء الأصلي (مثال لاستعمال إذا لزم الأمر)
  Medicine medicineAt(int index) {
    return _medicines[index];
  }
}
