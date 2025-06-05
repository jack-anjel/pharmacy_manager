import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../models/expiry_batch.dart';
import '../services/settings_store.dart';
import '../theme/design_system.dart';

class AddMedicineScreen extends StatefulWidget {
  final void Function(Medicine) onAdd;
  const AddMedicineScreen({super.key, required this.onAdd});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  // ──── حقول النموذج ────
  final TextEditingController nameCtrl = TextEditingController();
  String? selectedCategory;
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController companyCtrl = TextEditingController();

  // قائمة دفعات الصلاحية المؤقتة
  List<ExpiryBatch> expiries = [];

  // للتحكم بحوار إضافة دفعة
  final TextEditingController _expiryInputController = TextEditingController();
  final TextEditingController _quantityInputController = TextEditingController();
  DateTime? _pickedDate;

  bool _isEdited = false;

  @override
  void initState() {
    super.initState();
    // في البداية، نعطي القيمة الأولى من قائمة الفئات بعد تحميل SettingsStore
    final cats = context.read<SettingsStore>().categories;
    selectedCategory = cats.isNotEmpty ? cats.first : null;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    companyCtrl.dispose();
    _expiryInputController.dispose();
    _quantityInputController.dispose();
    super.dispose();
  }

  void _markEdited() {
    if (!_isEdited) {
      setState(() {
        _isEdited = true;
      });
    }
  }

  DateTime? _parseFlexibleDate(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final patterns = <DateFormat>[
      DateFormat("yyyy-MM-dd"),
      DateFormat("yyyy/MM/dd"),
      DateFormat("yyyy MMM d"),
      DateFormat("MM/dd/yyyy"),
      DateFormat("dd-MM-yyyy"),
      DateFormat("yyyy-MM"),
      DateFormat("yyyy/MM"),
      DateFormat("yyyy"),
    ];
    for (var fmt in patterns) {
      try {
        final dt = fmt.parseStrict(text);
        if (fmt.pattern == "yyyy-MM" || fmt.pattern == "yyyy/MM") {
          final parts = text.split(RegExp(r'[-/]'));
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final lastDay = DateTime(year, month + 1, 0).day;
          return DateTime(year, month, lastDay);
        }
        if (fmt.pattern == "yyyy") {
          final year = int.parse(text);
          return DateTime(year, 12, 31);
        }
        return dt;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> _pickExpiryBatchDialog() async {
    _expiryInputController.clear();
    _quantityInputController.clear();
    _pickedDate = null;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('إضافة تاريخ صلاحية وكمية'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // حقل نصي للتاريخ مع أيقونة لفتح DatePicker
              TextField(
                controller: _expiryInputController,
                decoration: InputDecoration(
                  hintText:
                      'أدخل تاريخ الصلاحية نصيًا أو اضغط على أيقونة التقويم',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_view_month),
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                        locale: const Locale('ar'),
                      );
                      if (picked != null) {
                        setState(() {
                          _pickedDate = picked;
                          final formatted =
                              DateFormat('yyyy-MM-dd').format(picked);
                          _expiryInputController.text = formatted;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // حقل نصي لإدخال الكمية
              TextField(
                controller: _quantityInputController,
                decoration: const InputDecoration(
                  hintText: 'الكمية (رقم صحيح)',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // إغلاق دون إضافة
              },
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop(); // إغلاق ثم معالجة البيانات
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );

    final dateText = _expiryInputController.text.trim();
    final qtyText = _quantityInputController.text.trim();
    if (dateText.isEmpty && qtyText.isEmpty) return;

    final qty = int.tryParse(qtyText);
    if (qty == null || qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب إدخال عدد صحيح للكمية.')),
      );
      return;
    }
    if (qty == 0) {
      final confirmZero = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد الكمية الصفرية'),
          content: const Text(
              'أدخلت كمية “0”. هل تريد إضافة هذه الدفعة بكمية منتهية؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (confirmZero != true) return;
    }

    DateTime? finalDate;
    if (dateText.isNotEmpty) {
      final parsed = _parseFlexibleDate(dateText);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('صيغة التاريخ غير صحيحة.')),
        );
        return;
      }
      finalDate = parsed;
    } else {
      finalDate = null;
    }

    setState(() {
      expiries.add(ExpiryBatch(expiryDate: finalDate, quantity: qty));
      _markEdited();
    });
  }

  void _saveMedicine({bool continueAdding = false}) {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategory == null || selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الفئة')),
      );
      return;
    }
    if (expiries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء إضافة دفعة صلاحية واحدة على الأقل')),
      );
      return;
    }

    final newMed = Medicine(
      id: DateTime.now().millisecondsSinceEpoch,
      name: nameCtrl.text.trim(),
      category: selectedCategory!,
      price: priceCtrl.text.trim().isEmpty ? null : priceCtrl.text.trim(),
      company: companyCtrl.text.trim().isEmpty
          ? null
          : companyCtrl.text.trim(),
      expiries: [...expiries],
      isMuted: false,
    );

    widget.onAdd(newMed);
    _isEdited = false;

    if (continueAdding) {
      nameCtrl.clear();
      priceCtrl.clear();
      companyCtrl.clear();
      expiries.clear();
      final cats = context.read<SettingsStore>().categories;
      selectedCategory = cats.isNotEmpty ? cats.first : null;
      setState(() => _isEdited = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isEdited) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text(
            'هناك تغييرات غير محفوظة.\nهل تريد الخروج دون حفظ الدواء؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('الخروج بدون حفظ'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<SettingsStore>().categories;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text('إضافة دواء'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canLeave = await _onWillPop();
              if (canLeave) Navigator.of(context).pop();
            },
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            onChanged: _markEdited,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم الدواء
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الدواء',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'يرجى إدخال اسم الدواء';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // قائمة اختيار الفئة
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'الفئة',
                    border: OutlineInputBorder(),
                  ),
                  items: cats
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedCategory = val;
                        _markEdited();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // حقل السعر (اختياري)
                TextFormField(
                  controller: priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'السعر (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // حقل الشركة (اختياري)
                TextFormField(
                  controller: companyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الشركة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // زر مسح جميع الدفعات
                if (expiries.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          expiries.clear();
                          _markEdited();
                        });
                      },
                      icon: const Icon(Icons.clear_all, color: Colors.red),
                      label: const Text(
                        'مسح جميع الدفعات',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),

                // قسم إضافة دفعات الصلاحية والكمية
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تواريخ الصلاحية والكمية',
                      style: TextStyle(fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _pickExpiryBatchDialog,
                      tooltip: 'أضف دفعة جديدة',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // عرض الدفعات
                if (expiries.isEmpty)
                  const Text('لم تتم إضافة أي دفعة حتى الآن.')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: expiries.length,
                    itemBuilder: (ctx, i) {
                      final e = expiries[i];
                      Color tileColor = Colors.transparent;
                      if (e.expiryDate != null) {
                        final now = DateTime.now();
                        final diff = e.expiryDate!.difference(now).inDays;
                        if (e.expiryDate!.isBefore(now)) {
                          tileColor = Colors.red.withOpacity(0.1);
                        } else if (diff <= 30) {
                          tileColor = Colors.orange.withOpacity(0.1);
                        }
                      }
                      final formatted = e.expiryDate != null
                          ? DateFormat('yyyy-MM-dd').format(e.expiryDate!)
                          : '—';

                      return Dismissible(
                        key: Key('expiry_${i}_${formatted}_${e.quantity}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            expiries.removeAt(i);
                            _markEdited();
                          });
                        },
                        child: Container(
                          color: tileColor,
                          child: ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: Text('تاريخ: $formatted'),
                            subtitle: Text('كمية: ${e.quantity}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  expiries.removeAt(i);
                                  _markEdited();
                                });
                              },
                              tooltip: 'حذف الدفعة',
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 20),

                // أزرار الحفظ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _isEdited ? () => _saveMedicine() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 30),
                      ),
                      child: const Text(
                        'حفظ الدواء',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isEdited
                          ? () => _saveMedicine(continueAdding: true)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[500],
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                      ),
                      child: const Text(
                        'حفظ وإضافة آخر',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
