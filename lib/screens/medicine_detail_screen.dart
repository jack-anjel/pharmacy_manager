import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/medicine_store.dart';
import '../services/settings_store.dart';
import '../models/medicine.dart';
import '../models/expiry_batch.dart';

class MedicineDetailScreen extends StatefulWidget {
  final Medicine medicine;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const MedicineDetailScreen({
    super.key,
    required this.medicine,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  _MedicineDetailScreenState createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _companyController;
  late List<ExpiryBatch> _expiriesCopy;

  bool _isEdited = false;
  String? _selectedCategory;

  final TextEditingController _expiryInputController =
      TextEditingController();
  final TextEditingController _quantityInputController =
      TextEditingController();
  DateTime? _pickedDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medicine.name);
    _priceController =
        TextEditingController(text: widget.medicine.price ?? '');
    _companyController =
        TextEditingController(text: widget.medicine.company ?? '');
    _selectedCategory = widget.medicine.category;

    // نأخذ نسخة من دفعات الصلاحية
    _expiriesCopy = widget.medicine.expiries
        .map((e) =>
            ExpiryBatch(expiryDate: e.expiryDate, quantity: e.quantity))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _companyController.dispose();
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

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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

  Future<void> _showAddExpiryDialog() async {
    _expiryInputController.clear();
    _quantityInputController.clear();
    _pickedDate = null;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return AlertDialog(
              title: const Text('إضافة تاريخ صلاحية وكمية'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _expiryInputController,
                    decoration: InputDecoration(
                      hintText:
                          'أدخل تاريخ الصلاحية نصيًا أو اضغط على أيقونة التقويم',
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_view_month),
                        onPressed: () async {
                          FocusScope.of(ctx2).unfocus();
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx2,
                            initialDate: now,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100),
                            locale: const Locale('ar'),
                          );
                          if (picked != null) {
                            _pickedDate = picked;
                            final formatted =
                                DateFormat('yyyy-MM-dd').format(picked);
                            _expiryInputController.text = formatted;
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    Navigator.of(ctx2).pop();
                  },
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx2).pop();
                  },
                  child: const Text('إضافة'),
                ),
              ],
            );
          },
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
              'أدخلتَ الكمية “0”. هل تريد إضافة هذه الدفعة بكمية منتهية؟'),
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
      _expiriesCopy.add(ExpiryBatch(expiryDate: finalDate, quantity: qty));
      _markEdited();
    });
  }

  void _saveChanges() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم الدواء')),
      );
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الفئة')),
      );
      return;
    }
    if (_expiriesCopy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء إضافة دفعة صلاحية واحدة على الأقل')),
      );
      return;
    }

    widget.medicine.name = name;
    widget.medicine.category = _selectedCategory!;
    widget.medicine.price = _priceController.text.trim().isEmpty
        ? null
        : _priceController.text.trim();
    widget.medicine.company = _companyController.text.trim().isEmpty
        ? null
        : _companyController.text.trim();
    widget.medicine.expiries = List<ExpiryBatch>.from(_expiriesCopy);

    widget.onUpdate();
    setState(() {
      _isEdited = false;
    });
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content:
              const Text('هل أنت متأكد أنك تريد حذف هذا الدواء نهائيًا؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                widget.onDelete();
                Navigator.of(ctx).pop(); // إغلاق الحوار
                Navigator.of(context).pop(); // العودة إلى شاشة التنبيهات
              },
              child: const Text(
                'حذف',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    if (!_isEdited) return true;
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هناك تعديلات لم تُحفظ. هل تريد الخروج دون حفظ؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('خروج بدون حفظ'),
          ),
        ],
      ),
    );
    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // نأخذ الفئات من SettingsStore
    final categories = context.watch<SettingsStore>().categories;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الدواء'),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'نسخ الدواء',
              onPressed: () {
                final copied = Medicine(
                  id: DateTime.now().millisecondsSinceEpoch,
                  name: '${widget.medicine.name} (نسخة)',
                  category: widget.medicine.category,
                  price: widget.medicine.price,
                  company: widget.medicine.company,
                  expiries: widget.medicine.expiries
                      .map((e) => ExpiryBatch(
                            expiryDate: e.expiryDate,
                            quantity: e.quantity,
                          ))
                      .toList(),
                  isMuted: widget.medicine.isMuted,
                );
                Provider.of<MedicineStore>(context, listen: false)
                    .addMedicine(copied);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الدواء وإضافته')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'حذف الدواء',
              onPressed: _confirmDelete,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // حقل اسم الدواء
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الدواء',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _markEdited(),
              ),
              const SizedBox(height: 12),

              // قائمة الفئات
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'الفئة',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (cat) => DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val;
                    _markEdited();
                  });
                },
              ),
              const SizedBox(height: 12),

              // حقل السعر (اختياري)
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'السعر (اختياري)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _markEdited(),
              ),
              const SizedBox(height: 12),

              // حقل الشركة (اختياري)
              TextField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'الشركة (اختياري)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _markEdited(),
              ),
              const SizedBox(height: 20),

              // زر مسح جميع الدفعات
              if (_expiriesCopy.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final confirmClear = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('تأكيد مسح الدفعات'),
                          content: const Text(
                              'هل تريد مسح جميع دفعات الصلاحية نهائيًا؟'),
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
                      if (confirmClear == true) {
                        setState(() {
                          _expiriesCopy.clear();
                          _markEdited();
                        });
                      }
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
                    onPressed: _showAddExpiryDialog,
                    tooltip: 'أضف دفعة جديدة',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // عرض قائمة الدفعات
              if (_expiriesCopy.isEmpty)
                const Text('لا توجد دفعات حالية.')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _expiriesCopy.length,
                  itemBuilder: (ctx, i) {
                    final batch = _expiriesCopy[i];
                    final date = batch.expiryDate;
                    final formattedDate =
                        date != null ? _formatDate(date) : '—';

                    Color tileColor = Colors.transparent;
                    if (date != null) {
                      final today = DateTime.now();
                      final diff = date.difference(today).inDays;
                      if (date.isBefore(today)) {
                        tileColor = Colors.red.withOpacity(0.1);
                      } else if (diff <= 180) {
                        tileColor = Colors.orange.withOpacity(0.1);
                      }
                    }

                    return Dismissible(
                      key:
                          Key('batch_${i}_${formattedDate}_${batch.quantity}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        setState(() {
                          _expiriesCopy.removeAt(i);
                          _markEdited();
                        });
                      },
                      child: Container(
                        color: tileColor,
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text('تاريخ: $formattedDate'),
                          subtitle: Text('كمية: ${batch.quantity}'),
                          trailing: IconButton(
                            icon:
                                const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _expiriesCopy.removeAt(i);
                                _markEdited();
                              });
                            },
                            tooltip: 'حذف الدُفعة',
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // زر حفظ التعديلات
              Center(
                child: ElevatedButton(
                  onPressed: _isEdited ? _saveChanges : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 30),
                  ),
                  child: const Text(
                    'حفظ التعديلات',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

