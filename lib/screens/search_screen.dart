import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/medicine_store.dart';
import '../services/settings_store.dart';
import '../models/medicine.dart';
import '../theme/design_system.dart';
import 'medicine_detail_screen.dart';
import 'add_medicine_screen.dart';

enum SortBy { name, quantity, expiry }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  String selectedGroup = 'كل المجموعات';
  String filterBy = 'بدون فلترة';
  SortBy _sortBy = SortBy.name;
  bool _ascending = true;

  List<Medicine> filtered = [];

  @override
  void initState() {
    super.initState();
    filtered = [];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      applySearchAndFilter();
    });
  }

  void _clearAllFilters() {
    setState(() {
      selectedGroup = 'كل المجموعات';
      filterBy = 'بدون فلترة';
      _sortBy = SortBy.name;
      _ascending = true;
      _searchCtrl.clear();
      filtered.clear();
    });
  }

  void applySearchAndFilter() {
    final store = context.read<MedicineStore>();
    final allMeds = store.medicines;
    final query = _searchCtrl.text.trim().toLowerCase();
    final now = DateTime.now();

    setState(() {
      filtered = allMeds.where((m) {
        final inGroup =
            (selectedGroup == 'كل المجموعات' || m.category == selectedGroup);

        bool filterOk = true;
        if (filterBy == 'الكمية ≤ 60') {
          filterOk = m.totalQuantity <= 60;
        } else if (filterBy == 'صلاحية ≤ 180 يوم') {
          filterOk = m.expiries.any((e) {
            if (e.expiryDate == null) return false;
            final diff = e.expiryDate!.difference(now).inDays;
            return diff <= 180;
          });
        }

        bool matches = query.isEmpty;
        if (query.isNotEmpty) {
          final nameMatch = m.name.toLowerCase().contains(query);
          final catMatch = m.category.toLowerCase().contains(query);
          final dateMatch = m.expiries.any((e) {
            if (e.expiryDate == null) return false;
            final d = e.expiryDate!;
            final str1 = DateFormat('yyyy-MM-dd').format(d);
            final str2 = DateFormat('dd/MM/yyyy').format(d);
            return str1.contains(query) || str2.contains(query);
          });
          matches = nameMatch || catMatch || dateMatch;
        }

        return inGroup && filterOk && matches;
      }).toList();

      filtered.sort((a, b) {
        int cmp = 0;
        switch (_sortBy) {
          case SortBy.name:
            cmp = a.name.compareTo(b.name);
            break;
          case SortBy.quantity:
            cmp = a.totalQuantity.compareTo(b.totalQuantity);
            break;
          case SortBy.expiry:
            DateTime aMin = DateTime(9999);
            if (a.expiries.isNotEmpty) {
              final datesA = a.expiries
                  .where((e) => e.expiryDate != null)
                  .map((e) => e.expiryDate!);
              if (datesA.isNotEmpty) {
                aMin = datesA.reduce((v, e) => v.isBefore(e) ? v : e);
              }
            }
            DateTime bMin = DateTime(9999);
            if (b.expiries.isNotEmpty) {
              final datesB = b.expiries
                  .where((e) => e.expiryDate != null)
                  .map((e) => e.expiryDate!);
              if (datesB.isNotEmpty) {
                bMin = datesB.reduce((v, e) => v.isBefore(e) ? v : e);
              }
            }
            cmp = aMin.compareTo(bMin);
            break;
        }
        return _ascending ? cmp : -cmp;
      });
    });
  }

  List<TextSpan> _highlightOccurrences(String source, String query) {
    if (query.isEmpty) return [TextSpan(text: source)];
    final spans = <TextSpan>[];
    final lcSource = source.toLowerCase();
    final lcQuery = query.toLowerCase();
    int start = 0;
    int index;
    while ((index = lcSource.indexOf(lcQuery, start)) != -1) {
      if (index > start) {
        spans.add(TextSpan(text: source.substring(start, index)));
      }
      spans.add(TextSpan(
        text: source.substring(index, index + query.length),
        style: const TextStyle(backgroundColor: Colors.yellow),
      ));
      start = index + query.length;
    }
    if (start < source.length) {
      spans.add(TextSpan(text: source.substring(start)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MedicineStore>();
    final cats = context.watch<SettingsStore>().categories;

    final groupCounts = <String, int>{
      'كل المجموعات': store.medicines.length,
      for (var c in cats)
        c: store.medicines.where((m) => m.category == c).length,
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('بحث عن دواء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة دواء جديد',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddMedicineScreen(onAdd: (newMed) {
                    store.addMedicine(newMed);
                  }),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'مسح الفلاتر',
            onPressed: _clearAllFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // حقل البحث
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.margin, vertical: AppSpacing.margin / 2),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو المجموعة أو التاريخ',
                prefixIcon: Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          applySearchAndFilter();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadius),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // ChoiceChips للفئات
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(
                      'كل المجموعات (${groupCounts['كل المجموعات']})'),
                  selected: selectedGroup == 'كل المجموعات',
                  onSelected: (_) {
                    setState(() => selectedGroup = 'كل المجموعات');
                    applySearchAndFilter();
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    color: selectedGroup == 'كل المجموعات'
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(width: AppSpacing.margin / 2),
                ...cats.map((c) {
                  final count = groupCounts[c] ?? 0;
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: AppSpacing.margin / 2),
                    child: ChoiceChip(
                      label: Text('$c ($count)'),
                      selected: selectedGroup == c,
                      onSelected: (_) {
                        setState(() => selectedGroup = c);
                        applySearchAndFilter();
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      labelStyle: TextStyle(
                        color: selectedGroup == c
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.margin / 2),

          // ChoiceChips للفلترة حسب الكمية/الصلاحية
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
            child: Wrap(
              spacing: AppSpacing.margin / 2,
              children: [
                ChoiceChip(
                  label: const Text('بدون فلترة'),
                  selected: filterBy == 'بدون فلترة',
                  onSelected: (_) {
                    setState(() => filterBy = 'بدون فلترة');
                    applySearchAndFilter();
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    color: filterBy == 'بدون فلترة'
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                ChoiceChip(
                  label: const Text('الكمية ≤ 60'),
                  selected: filterBy == 'الكمية ≤ 60',
                  onSelected: (_) {
                    setState(() => filterBy = 'الكمية ≤ 60');
                    applySearchAndFilter();
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    color: filterBy == 'الكمية ≤ 60'
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                ChoiceChip(
                  label: const Text('صلاحية ≤ 180 يوم'),
                  selected: filterBy == 'صلاحية ≤ 180 يوم',
                  onSelected: (_) {
                    setState(() => filterBy = 'صلاحية ≤ 180 يوم');
                    applySearchAndFilter();
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    color: filterBy == 'صلاحية ≤ 180 يوم'
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.margin / 2),

          // Dropdown للترتيب وعكس الترتيب + عدد النتائج
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
            child: Row(
              children: [
                const Text("ترتيب حسب: "),
                DropdownButton<SortBy>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(
                        value: SortBy.name, child: Text("الاسم")),
                    DropdownMenuItem(
                        value: SortBy.quantity, child: Text("الكمية")),
                    DropdownMenuItem(
                        value: SortBy.expiry, child: Text("الصلاحية")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _sortBy = val;
                        applySearchAndFilter();
                      });
                    }
                  },
                ),
                const SizedBox(width: AppSpacing.margin),
                IconButton(
                  icon: Icon(
                    _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    color: AppColors.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _ascending = !_ascending;
                      applySearchAndFilter();
                    });
                  },
                  tooltip: "عكس الترتيب",
                ),
                const Spacer(),
                Text('${filtered.length} نتيجة'),
              ],
            ),
          ),

          const Divider(),
          const SizedBox(height: 6),

          // عرض النتائج
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _searchCtrl.text.isEmpty
                          ? 'لا توجد نتائج'
                          : 'لم يتم العثور على دواء',
                      style: AppTextStyles.body,
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final med = filtered[index];

                      // إيجاد أقرب تاريخ أو منتهٍ
                      DateTime? nearestExpiry;
                      for (var e in med.expiries) {
                        if (e.expiryDate == null) continue;
                        final d = e.expiryDate!;
                        if (nearestExpiry == null ||
                            d.isBefore(nearestExpiry)) {
                          nearestExpiry = d;
                        }
                      }
                      final nearestText = nearestExpiry != null
                          ? DateFormat('yyyy-MM-dd').format(nearestExpiry)
                          : '—';

                      // تحديد الأيقونة واللون وفق الحالة
                      IconData statusIcon;
                      Color statusColor;
                      if (med.totalQuantity == 0) {
                        statusIcon = Icons.warning;
                        statusColor = AppColors.danger;
                      } else if (med.totalQuantity <= 60) {
                        statusIcon = Icons.error_outline;
                        statusColor = AppColors.warning;
                      } else if (nearestExpiry != null &&
                          nearestExpiry.isBefore(DateTime.now())) {
                        statusIcon = Icons.calendar_today;
                        statusColor = AppColors.danger;
                      } else if (nearestExpiry != null) {
                        statusIcon = Icons.schedule;
                        statusColor = AppColors.warning;
                      } else {
                        statusIcon = Icons.check_circle;
                        statusColor = AppColors.primary;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.margin,
                          vertical: AppSpacing.margin / 2,
                        ),
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicineDetailScreen(
                                  medicine: med,
                                  onUpdate: () {
                                    store.updateMedicine();
                                  },
                                  onDelete: () {
                                    store.deleteMedicine(med.id);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                            );
                            applySearchAndFilter();
                          },
                          child: Card(
                            color: AppColors.cardBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.borderRadius),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.padding),
                              child: Row(
                                children: [
                                  Icon(statusIcon,
                                      size: 28, color: statusColor),
                                  const SizedBox(width: AppSpacing.padding),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: AppTextStyles.cardTitle
                                                .copyWith(color: Colors.black87),
                                            children: _highlightOccurrences(
                                                med.name,
                                                _searchCtrl.text.trim()),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'كمية: ${med.totalQuantity}  •  صلاحية: $nearestText',
                                          style: AppTextStyles.cardSubtitle
                                              .copyWith(color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
