// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_store.dart';
import '../theme/design_system.dart';

import 'notification_screen.dart';
import 'statistics_screen.dart';
import 'search_screen.dart';
import 'add_medicine_screen.dart';
import 'backup_screen.dart';
import 'settings_screen.dart';
import '../services/medicine_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const NotificationScreen(),
      const StatisticsScreen(),
      const SearchScreen(),
      AddMedicineScreen(
        onAdd: (med) async {
          // عند الضغط على "حفظ" في شاشة الإضافة، نضيف الدواء ثم دفعاته إلى قاعدة البيانات
          final store = Provider.of<MedicineStore>(context, listen: false);
          final newId = await store.addMedicine(
            name: med.name,
            category: med.category,
            price: med.price,
            company: med.company,
          );
          for (var e in med.expiries) {
            await store.addBatch(
              medicineId: newId,
              expiryDate: e.expiryDate,
              quantity: e.quantity,
            );
          }
        },
      ),
      const BackupScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsStore>().isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الصيدلية'),
        backgroundColor:
            isDark ? AppColors.primaryVariant : AppColors.primary,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primaryVariant,
        unselectedItemColor:
            isDark ? Colors.grey[400] : Colors.grey[600],
        backgroundColor:
            isDark ? Colors.grey[850] : Colors.white,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'التنبيهات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'الإحصائيات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'بحث',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box),
            label: 'إضافة دواء',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backup),
            label: 'نسخ/استعادة',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryVariant : AppColors.primary,
              ),
              child: Text(
                'القائمة الجانبية',
                style: AppTextStyles.headline.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('الوضع الليلي'),
              trailing: Switch(
                value: isDark,
                onChanged: (_) {
                  context.read<SettingsStore>().toggleDarkMode();
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.primary),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
