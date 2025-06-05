import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/medicine_store.dart';
import '../models/medicine.dart';
import '../theme/design_system.dart';
import 'medicine_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late MedicineStore store;
  late DateTime now;

  @override
  void initState() {
    super.initState();
    store = Provider.of<MedicineStore>(context, listen: false);
    now = DateTime.now();
  }

  Future<void> _refreshData() async {
    await store.loadAll();
    setState(() {
      now = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final meds = store.medicines;

    // قوائم الحالة: منتهية، قريبة انتهاء، كمية منتهية، كمية منخفضة، مكتومة
    final List<Medicine> expired = [];
    final List<Medicine> nearExpiry = [];
    final List<Medicine> qtyExpired = [];
    final List<Medicine> qtyLow = [];
    final List<Medicine> mutedMeds = [];

    for (var m in meds) {
      if (m.isMuted) {
        mutedMeds.add(m);
        continue;
      }
      // أولًا: فحص الصلاحية
      DateTime? nearestExpiry;
      for (var e in m.expiries) {
        if (e.expiryDate == null) continue;
        final d = e.expiryDate!;
        if (nearestExpiry == null || d.isBefore(nearestExpiry)) {
          nearestExpiry = d;
        }
      }

      if (nearestExpiry != null) {
        final diff = nearestExpiry.difference(now).inDays;
        if (nearestExpiry.isBefore(now)) {
          expired.add(m);
          continue;
        } else if (diff >= 0 && diff <= 180) {
          nearExpiry.add(m);
          continue;
        }
      }

      // إذا لم تكن الصلاحية قريبة أو منتهية → نفحص الكمية
      final q = m.totalQuantity;
      if (q == 0) {
        qtyExpired.add(m);
      } else if (q <= 60) {
        qtyLow.add(m);
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('التنبيهات'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              DateFormat('EEEE، d MMMM yyyy', 'ar').format(now),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin * 1.5,
            vertical: AppSpacing.margin,
          ),
          children: [
            // قسم "منتهية الصلاحية"
            if (expired.isNotEmpty) ...[
              _buildSectionHeader(
                'منتهية الصلاحية (${expired.length})',
                AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.margin / 2),
              ...expired.map((m) => _buildMedicineCard(m, AppColors.danger)),
              const SizedBox(height: AppSpacing.margin),
            ],

            // قسم "قريبة الانتهاء (≤ 180 يوم)"
            if (nearExpiry.isNotEmpty) ...[
              _buildSectionHeader(
                'قريبة الانتهاء (≤ 180 يوم) (${nearExpiry.length})',
                AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.margin / 2),
              ...nearExpiry.map((m) => _buildMedicineCard(m, AppColors.warning)),
              const SizedBox(height: AppSpacing.margin),
            ],

            // قسم "كمية منتهية"
            if (qtyExpired.isNotEmpty) ...[
              _buildSectionHeader(
                'كمية منتهية (${qtyExpired.length})',
                AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.margin / 2),
              ...qtyExpired.map((m) => _buildMedicineCard(m, AppColors.danger)),
              const SizedBox(height: AppSpacing.margin),
            ],

            // قسم "كمية منخفضة (≤ 60)"
            if (qtyLow.isNotEmpty) ...[
              _buildSectionHeader(
                'كمية منخفضة (≤ 60) (${qtyLow.length})',
                AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.margin / 2),
              ...qtyLow.map((m) => _buildMedicineCard(m, AppColors.warning)),
              const SizedBox(height: AppSpacing.margin),
            ],

            // قسم "الأدوية المكتومة"
            if (mutedMeds.isNotEmpty) ...[
              _buildSectionHeader(
                'الأدوية المكتومة (${mutedMeds.length})',
                AppColors.mutedText,
              ),
              const SizedBox(height: AppSpacing.margin / 2),
              ...mutedMeds.map((m) => _buildMedicineCard(m, AppColors.mutedText, isMuted: true)),
              const SizedBox(height: AppSpacing.margin),
            ],

            // رسالة إذا لم يكن هناك تنبيهات
            if (expired.isEmpty &&
                nearExpiry.isEmpty &&
                qtyExpired.isEmpty &&
                qtyLow.isEmpty &&
                mutedMeds.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.margin * 4),
                  child: Text(
                    'لا توجد تنبيهات في الوقت الحالي.',
                    style: AppTextStyles.body.copyWith(color: Colors.black54),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// تبني عنوان قسم (Section Header) باللون المناسب
  Widget _buildSectionHeader(String text, Color color) {
    return Text(
      text,
      style: AppTextStyles.headline.copyWith(color: color),
    );
  }

  /// تبني بطاقة دواء (Card) مع أيقونة، اسم، حالة، وزر كتم/إلغاء كتم
  /// وينفّذ إعادة تحميل البيانات عند العودة من شاشة التفاصيل.
  Widget _buildMedicineCard(Medicine med, Color statusColor, {bool isMuted = false}) {
    // العثور على أقرب تاريخ صلاحية
    DateTime? nearestExpiry;
    for (var e in med.expiries) {
      if (e.expiryDate == null) continue;
      final d = e.expiryDate!;
      if (nearestExpiry == null || d.isBefore(nearestExpiry)) {
        nearestExpiry = d;
      }
    }

    // بناء نص الوصف (subtitle) وفق الأولويات
    String subtitle;
    if (isMuted) {
      subtitle = 'تم كتم التنبيهات';
    } else if (nearestExpiry != null) {
      final diff = nearestExpiry.difference(now).inDays;
      if (nearestExpiry.isBefore(now)) {
        subtitle = 'منتهية الصلاحية منذ ${-diff} يوم';
      } else if (diff <= 180) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(nearestExpiry);
        subtitle = 'قريبة الانتهاء بتاريخ $formattedDate';
      } else {
        // صلاحية بعيدة (>180 يوم) → تفحص الكمية
        if (med.totalQuantity == 0) {
          subtitle = 'الكمية: منتهية';
        } else {
          subtitle = 'كمية متبقية: ${med.totalQuantity}';
        }
      }
    } else {
      // لا تاريخ صلاحية → تفحص الكمية
      if (med.totalQuantity == 0) {
        subtitle = 'الكمية: منتهية';
      } else {
        subtitle = 'كمية متبقية: ${med.totalQuantity}';
      }
    }

    // تحديد أيقونة الحالة بناءً على نفس الأولويات
    IconData iconData;
    if (isMuted) {
      iconData = Icons.volume_off;
    } else if (nearestExpiry != null) {
      final diff = nearestExpiry.difference(now).inDays;
      if (nearestExpiry.isBefore(now)) {
        iconData = Icons.calendar_today; // منتهية
      } else if (diff <= 180) {
        iconData = Icons.schedule; // قريبة الانتهاء
      } else if (med.totalQuantity == 0) {
        iconData = Icons.warning;
      } else if (med.totalQuantity <= 60) {
        iconData = Icons.error_outline;
      } else {
        iconData = Icons.medical_services;
      }
    } else {
      // لا تاريخ صلاحية
      if (med.totalQuantity == 0) {
        iconData = Icons.warning;
      } else if (med.totalQuantity <= 60) {
        iconData = Icons.error_outline;
      } else {
        iconData = Icons.medical_services;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.margin / 2),
      child: Card(
        color: isMuted
            ? AppColors.cardBackground
            : statusColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        ),
        elevation: 2,
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.padding),
          leading: Icon(iconData, size: 28, color: statusColor),
          title: Text(
            med.name,
            style: AppTextStyles.cardTitle.copyWith(color: Colors.black87),
          ),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.cardSubtitle.copyWith(color: Colors.black54),
          ),
          trailing: IconButton(
            icon: Icon(
              isMuted ? Icons.volume_up : Icons.volume_off,
              color: isMuted ? AppColors.primary : statusColor,
            ),
            onPressed: () {
              store.toggleMute(med.id);
              setState(() {});
            },
            tooltip: isMuted ? 'إلغاء كتم التنبيه' : 'كتم التنبيه',
          ),
          onTap: () async {
            // ننتقل إلى شاشة التفاصيل ثم نُحدّث عند العودة
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MedicineDetailScreen(
                  medicine: med,
                  onUpdate: () => store.updateMedicine(),
                  onDelete: () {
                    store.deleteMedicine(med.id);
                  },
                ),
              ),
            );
            _refreshData();
          },
        ),
      ),
    );
  }
}


