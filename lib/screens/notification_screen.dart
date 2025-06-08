// lib/screens/notification_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/medicine_store.dart';
import '../models/medicine.dart';
import '../models/expiry_batch.dart';
import '../theme/design_system.dart';
import 'medicine_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late MedicineStore _store;
  late DateTime _now;
  String _searchQuery = '';
  final _expandedSections = <String, bool>{
    'الصلاحية': false,
    'الكمية': false,
    'الأدوية المكتومة': false,
  };

  @override
  void initState() {
    super.initState();
    _store = Provider.of<MedicineStore>(context, listen: false);
    _now = DateTime.now();
  }

  void _toggleSection(String section) {
    setState(() => _expandedSections[section] = !_expandedSections[section]!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF232323) : Colors.white;
    final cardColor = isDark ? const Color(0xFF303030) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    // فلترة الأدوية حسب البحث
    final medicines = _store.medicines
        .where((m) => m.name.contains(_searchQuery))
        .toList();

    // التصنيفات
    final expired = medicines.where((m) =>
        m.expiries.any((e) => e.expiryDate.isBefore(_now))).toList();
    final nearExpiry = medicines.where((m) =>
        m.expiries.any((e) =>
            e.expiryDate.isAfter(_now) &&
            e.expiryDate.difference(_now).inDays <= 180)).toList();
    final qtyExpired = medicines.where((m) => m.totalQuantity == 0).toList();
    final qtyLow = medicines.where((m) => m.totalQuantity > 0 && m.totalQuantity <= 60).toList();
    final muted = medicines.where((m) => m.isMuted).toList();

    // ----- قائمة البلاطات الإحصائية بالترتيب المطلوب -----
    final List<_StatTile> tiles = [
      _StatTile(
        icon: Icons.volume_off,
        color: Colors.grey,
        count: muted.length,
        label: 'المكتومة',
        onTap: () => _openSectionMedicines(context, 'الأدوية المكتومة', muted, showMuted: true),
      ),
      _StatTile(
        icon: Icons.warning_rounded,
        color: Colors.red[400]!,
        count: qtyExpired.length,
        label: 'منتهية ك.',
        onTap: () => _openSectionMedicines(context, 'منتهية الكمية', qtyExpired, showQty: true),
      ),
      _StatTile(
        icon: Icons.error_outline_rounded,
        color: Colors.orange,
        count: qtyLow.length,
        label: 'منخفضة',
        onTap: () => _openSectionMedicines(context, 'كمية منخفضة', qtyLow, showQty: true),
      ),
      _StatTile(
        icon: Icons.access_time_rounded,
        color: Colors.amber[700]!,
        count: nearExpiry.length,
        label: 'قريبة',
        onTap: () => _openSectionMedicines(context, 'قريبة الانتهاء', nearExpiry, showDate: true),
      ),
      _StatTile(
        icon: Icons.event_busy_rounded,
        color: Colors.red,
        count: expired.length,
        label: 'منتهية',
        onTap: () => _openSectionMedicines(context, 'منتهية الصلاحية', expired, showDate: true),
      ),
      _StatTile(
        icon: Icons.medical_services_rounded,
        color: AppColors.primary,
        count: medicines.length,
        label: 'الكل',
        onTap: () => _openSectionMedicines(context, 'كل الأدوية', medicines),
      ),
    ].reversed.toList(); // حتى يظهر "الكل" أول أيقونة من اليمين

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        centerTitle: true,
        title: const Text(
          'التنبيهات',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              DateFormat('EEEE، d MMMM yyyy', 'ar').format(_now),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث...',
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white : Colors.grey[700]),
                filled: true,
                fillColor: isDark ? const Color(0xFF2d2d2d) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              style: TextStyle(color: textColor),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          // --- اللوحة الإحصائية ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: tiles,
            ),
          ),
          // --- باقي الصفحة ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(() => _now = DateTime.now()),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.margin),
                children: [
                  _buildExpandableSection(
                    context,
                    'الصلاحية (${expired.length + nearExpiry.length})',
                    {
                      'منتهية (${expired.length})': expired,
                      'قريبة الانتهاء (${nearExpiry.length})': nearExpiry,
                    },
                    showDate: true,
                    cardColor: cardColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildExpandableSection(
                    context,
                    'الكمية (${qtyExpired.length + qtyLow.length})',
                    {
                      'منتهية (${qtyExpired.length})': qtyExpired,
                      'منخفضة (${qtyLow.length})': qtyLow,
                    },
                    showQty: true,
                    cardColor: cardColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  _buildSimpleSection(
                    context,
                    'الأدوية المكتومة (${muted.length})',
                    muted,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSectionMedicines(
    BuildContext context,
    String title,
    List<Medicine> list, {
    bool showDate = false,
    bool showQty = false,
    bool showMuted = false,
  }) async {
    if (list.isEmpty) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _MedicinesListScreen(
        title: title,
        medicines: List<Medicine>.from(list),
        showDate: showDate,
        showQty: showQty,
        showMuted: showMuted,
        cardColor: Theme.of(context).cardColor,
        textColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
        subTextColor: Colors.grey,
        store: _store,
      ),
    ));
    setState(() {});
  }

  Widget _buildExpandableSection(
    BuildContext context,
    String title,
    Map<String, List<Medicine>> data, {
      bool showDate = false,
      bool showQty = false,
      required Color cardColor,
      required Color textColor,
      Color? subTextColor,
    }
  ) {
    final baseTitle = title.replaceAll(RegExp(r'\s*\(\d+\)'), '');
    final isExpanded = _expandedSections[baseTitle]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: ExpansionTile(
        collapsedIconColor: textColor,
        iconColor: textColor,
        textColor: textColor,
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
            ),
          ],
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (_) => _toggleSection(baseTitle),
        children: data.entries.map((entry) {
          return ListTile(
            title: Text(entry.key, style: TextStyle(fontSize: 16, color: textColor)),
            trailing: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text('${entry.value.length}', style: const TextStyle(color: Colors.white)),
            ),
            onTap: entry.value.isEmpty ? null : () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => _MedicinesListScreen(
                  title: entry.key,
                  medicines: List<Medicine>.from(entry.value),
                  showDate: showDate,
                  showQty: showQty,
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor ?? Colors.black54,
                  store: _store,
                ),
              ));
              setState(() {});
            },
            enabled: entry.value.isNotEmpty,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSimpleSection(
    BuildContext context,
    String title,
    List<Medicine> medicines, {
      required Color cardColor,
      required Color textColor,
    }
  ) {
    final baseTitle = 'الأدوية المكتومة';
    final isExpanded = _expandedSections[baseTitle]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
        trailing: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text('${medicines.length}', style: const TextStyle(color: Colors.white)),
        ),
        onTap: medicines.isEmpty ? null : () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => _MedicinesListScreen(
              title: title,
              medicines: List<Medicine>.from(medicines),
              showMuted: true,
              cardColor: cardColor,
              textColor: textColor,
              subTextColor: Colors.grey,
              store: _store,
            ),
          ));
          setState(() {});
        },
        enabled: medicines.isNotEmpty,
      ),
    );
  }
}

// عنصر البلاطة الإحصائية
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;
  final void Function()? onTap;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text('$count',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// شاشة عرض قائمة الأدوية لكل تصنيف فرعي
class _MedicinesListScreen extends StatefulWidget {
  final String title;
  final List<Medicine> medicines;
  final bool showDate;
  final bool showQty;
  final bool showMuted;
  final Color cardColor;
  final Color textColor;
  final Color subTextColor;
  final MedicineStore store;

  const _MedicinesListScreen({
    required this.title,
    required this.medicines,
    this.showDate = false,
    this.showQty = false,
    this.showMuted = false,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
    required this.store,
    super.key,
  });

  @override
  State<_MedicinesListScreen> createState() => __MedicinesListScreenState();
}

class __MedicinesListScreenState extends State<_MedicinesListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.cardColor,
      appBar: AppBar(title: Text(widget.title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.margin),
        itemCount: widget.medicines.length,
        itemBuilder: (_, index) {
          final med = widget.medicines[index];

          String subtitle = '';
          final isValiditySection = widget.showDate && (
              widget.title.contains('منتهية') ||
              widget.title.contains('قريبة')
          );
          if (isValiditySection && med.expiries.isNotEmpty) {
            final now = DateTime.now();
            List<ExpiryBatch> filteredBatches = [];
            if (widget.title.contains('منتهية')) {
              filteredBatches = med.expiries.where((b) => b.expiryDate.isBefore(now)).toList();
            } else if (widget.title.contains('قريبة')) {
              filteredBatches = med.expiries.where((b) =>
                b.expiryDate.isAfter(now) && b.expiryDate.difference(now).inDays <= 180
              ).toList();
            }
            if (filteredBatches.isNotEmpty) {
              subtitle = filteredBatches.map((b) =>
                DateFormat('yyyy-MM-dd').format(b.expiryDate)
              ).join('\n');
              subtitle = 'تواريخ الصلاحية:\n$subtitle';
            } else {
              subtitle = 'لا يوجد دفعات محققة';
            }
          } else if (widget.showQty) {
            subtitle = 'الكمية: ${med.totalQuantity}';
          }
          if (widget.showMuted) {
            subtitle = 'تم كتم تنبيهات هذا الدواء';
          }

          return Card(
            color: widget.cardColor,
            child: ListTile(
              title: Text(med.name, style: TextStyle(color: widget.textColor)),
              subtitle: Text(subtitle, style: TextStyle(color: widget.subTextColor)),
              trailing: IconButton(
                icon: Icon(
                  med.isMuted ? Icons.volume_off : Icons.notifications_active,
                  color: med.isMuted ? Colors.red : AppColors.primary,
                ),
                onPressed: () async {
                  await widget.store.toggleMute(med.id!);
                  setState(() {
                    widget.medicines.removeAt(index);
                  });
                },
                tooltip: med.isMuted ? 'إلغاء كتم التنبيه' : 'كتم التنبيه',
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => MedicineDetailScreen(medicine: med),
              )),
            ),
          );
        },
      ),
    );
  }
}
