import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../services/medicine_store.dart';
import '../services/settings_store.dart';
import '../models/medicine.dart';
import '../theme/design_system.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
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
    // نقرأ قائمة الفئات من SettingsStore
    final categories = context.watch<SettingsStore>().categories;

    final meds = store.medicines;

    // إحصائيات أساسية
    final totalMeds = meds.length;
    final totalBatches = meds.fold<int>(0, (sum, m) => sum + m.expiries.length);
    final lowStockCount = meds.where((m) => m.totalQuantity <= 60).length;
    final expiredCount = meds.where((m) {
      return m.expiries.any((e) {
        if (e.expiryDate == null) return false;
        return e.expiryDate!.isBefore(now);
      });
    }).length;

    // بيانات المخطط الدائري حسب المجموعات
    final groupCounts = <String, int>{
      for (var c in categories) c: meds.where((m) => m.category == c).length
    };
    final pieSections = <PieChartSectionData>[];
    final colors = [
      Colors.teal.shade300,
      Colors.teal.shade500,
      Colors.orange.shade300,
      Colors.orange.shade500,
      Colors.purple.shade300,
      Colors.purple.shade500,
      Colors.blueGrey.shade300,
      Colors.blueGrey.shade500,
      // أضف المزيد إذا زادت الفئات
    ];
    int colorIndex = 0;
    groupCounts.forEach((category, count) {
      if (count > 0) {
        pieSections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: count.toDouble(),
            title: count.toString(),
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
      colorIndex++;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير الإحصائية'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقات الإحصائيات الأساسية
              _buildStatCard(
                icon: Icons.medical_services,
                label: 'إجمالي عدد الأدوية',
                value: totalMeds.toString(),
                color: AppColors.primary,
              ),
              _buildStatCard(
                icon: Icons.inventory_2,
                label: 'إجمالي عدد الدفعات',
                value: totalBatches.toString(),
                color: AppColors.primaryVariant,
              ),
              _buildStatCard(
                icon: Icons.remove_circle_outline,
                label: 'أدوية منخفضة الكمية (≤ 60)',
                value: lowStockCount.toString(),
                color: AppColors.warning,
              ),
              _buildStatCard(
                icon: Icons.cancel,
                label: 'أدوية منتهية الصلاحية',
                value: expiredCount.toString(),
                color: AppColors.danger,
              ),

              const Divider(height: 32),

              // المخطط الدائري
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'نسبة الأدوية حسب المجموعات:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (pieSections.isEmpty)
                const Center(child: Text('لا توجد بيانات لعرض المخطط.'))
              else
                Center(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.width * 0.6,
                    child: PieChart(
                      PieChartData(
                        sections: pieSections,
                        sectionsSpace: 2,
                        centerSpaceRadius:
                            MediaQuery.of(context).size.width * 0.15,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              const Divider(height: 32),

              // التفاصيل حسب المجموعات
              const Text(
                'تفاصيل حسب المجموعات:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...categories.map((c) {
                final count = groupCounts[c] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.category,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$c: $count دواء',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),
              const Divider(height: 32),

              // قائمة الأدوية “الحرجة”
              const Text(
                'الأدوية التي تحتاج انتباهًا خاصًا:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildSpecialList(meds, categories),
            ],
          ),
        ),
      ),
    );
  }

  /// بطاقة إحصائية بسيطة
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.margin / 2),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.padding),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: AppSpacing.padding),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.cardSubtitle.copyWith(color: Colors.black87),
              ),
            ),
            Text(
              value,
              style: AppTextStyles.cardTitle.copyWith(color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  /// تبني قائمة الأدوية “الحرجة”
  Widget _buildSpecialList(List<Medicine> meds, List<String> categories) {
    final now = DateTime.now();
    final List<Medicine> qtyZero = [];
    final List<Medicine> qtyLow = [];
    final List<Medicine> expired = [];

    for (var m in meds) {
      if (m.isMuted) continue;
      final q = m.totalQuantity;
      if (q == 0) {
        qtyZero.add(m);
      } else if (q > 0 && q <= 60) {
        qtyLow.add(m);
      }

      for (var e in m.expiries) {
        if (e.expiryDate == null) continue;
        if (e.expiryDate!.isBefore(now) && !expired.contains(m)) {
          expired.add(m);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (qtyZero.isNotEmpty) ...[
          Text(
            'الكمية منتهية (${qtyZero.length})',
            style: TextStyle(
                color: AppColors.danger,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...qtyZero.map(
            (m) => _buildSpecialTile(m, 'الكمية: 0', AppColors.danger),
          ),
          const SizedBox(height: 12),
        ],
        if (qtyLow.isNotEmpty) ...[
          Text(
            'الكمية منخفضة (≤ 60) (${qtyLow.length})',
            style: TextStyle(
                color: AppColors.warning,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...qtyLow
              .map((m) => _buildSpecialTile(
                    m,
                    'الكمية: ${m.totalQuantity}',
                    AppColors.warning,
                  ))
              ,
          const SizedBox(height: 12),
        ],
        if (expired.isNotEmpty) ...[
          Text(
            'منتهية الصلاحية (${expired.length})',
            style: TextStyle(
                color: AppColors.danger,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...expired.map((m) {
            final dates = m.expiries
                .where((e) =>
                    e.expiryDate != null && e.expiryDate!.isBefore(now))
                .map((e) => DateFormat('yyyy-MM-dd').format(e.expiryDate!))
                .toList();
            final subtitle = 'منتهت صلاحية دفعات: ${dates.join(', ')}';
            return _buildSpecialTile(m, subtitle, AppColors.danger);
          }),
        ],
        if (qtyZero.isEmpty && qtyLow.isEmpty && expired.isEmpty)
          const Text(
            'لا توجد أدوية خاصة لعرضها.',
            style: TextStyle(fontSize: 14),
          ),
      ],
    );
  }

  /// بطاقة دواء “حرج”
  Widget _buildSpecialTile(Medicine m, String subtitle, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      ),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.margin / 2),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.padding),
        leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.medical_services, color: Colors.white),
        ),
        title: Text(
          m.name,
          style: AppTextStyles.cardTitle.copyWith(color: color),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.cardSubtitle.copyWith(color: color),
        ),
        trailing: IconButton(
          icon: Icon(
            m.isMuted ? Icons.volume_off : Icons.notifications_active,
            color: m.isMuted ? Colors.grey : color,
          ),
          onPressed: () => store.toggleMute(m.id),
          tooltip: m.isMuted ? 'إلغاء كتم التنبيه' : 'كتم التنبيه',
        ),
        onTap: () {
          // يمكن فتح شاشة التفاصيل هنا إذا رغبنا
        },
      ),
    );
  }
}
