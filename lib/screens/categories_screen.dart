import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_store.dart';
import '../theme/design_system.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<String> _cats;
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // نستعيد القائمة الحالية من الـ SettingsStore
    final store = context.read<SettingsStore>();
    _cats = List.from(store.categories);
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final text = _newCategoryController.text.trim();
    if (text.isEmpty) return;

    final store = context.read<SettingsStore>();
    if (store.categories.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذه الفئة موجودة بالفعل.')),
      );
      return;
    }

    // نضيف محليًا أولًا في AnimatedList
    setState(() {
      _cats.insert(0, text);
      _listKey.currentState?.insertItem(0);
    });

    // ثم نطلب من SettingsStore الحفظ
    await store.addCategory(text);
    _newCategoryController.clear();
  }

  Future<void> _confirmAndRemoveCategory(int index) async {
    final removedCat = _cats[index];

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد أنك تريد حذف فئة "$removedCat"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    final store = context.read<SettingsStore>();

    // نحذف من AnimatedList أولًا مع التأثير
    setState(() {
      _cats.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => SizeTransition(
          sizeFactor: animation,
          child: _buildCategoryTile(removedCat, index, forRemoval: true),
        ),
        duration: const Duration(milliseconds: 300),
      );
    });

    // ثم نقول لـ SettingsStore يحذفه من SharedPreferences
    await store.removeCategory(index);
  }

  Widget _buildCategoryTile(String cat, int index, {bool forRemoval = false}) {
    return ListTile(
      leading: const Icon(Icons.label, color: AppColors.primary),
      title: Text(cat),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () {
          _confirmAndRemoveCategory(index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفئات'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    decoration: const InputDecoration(
                      hintText: 'أضف فئة جديدة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.margin / 2),
                ElevatedButton(
                  onPressed: _addCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: const Text('إضافة'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: _cats.length,
              itemBuilder: (context, index, animation) {
                final cat = _cats[index];
                return SizeTransition(
                  sizeFactor: animation,
                  child: _buildCategoryTile(cat, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

