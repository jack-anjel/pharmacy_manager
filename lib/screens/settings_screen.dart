// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_store.dart';
import '../theme/design_system.dart';
import 'categories_screen.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatelessWidget {
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('الوضع الليلي'),
            subtitle: const Text('تفعيل/تعطيل الوضع الليلي'),
            value: settings.isDarkMode,
            onChanged: (val) {
              settings.toggleDarkMode(val);
            },
            activeColor: AppColors.primary,
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.category, color: AppColors.primary),
            title: const Text('إدارة الفئات'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              );
            },
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.backup, color: AppColors.primary),
            title: const Text('نسخ احتياطي / استعادة'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
