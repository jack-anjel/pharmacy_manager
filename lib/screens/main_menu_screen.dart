import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/medicine_store.dart';
import '../services/settings_store.dart';

import 'search_screen.dart';
import 'add_medicine_screen.dart';
import 'notification_screen.dart';
import 'statistics_screen.dart';
import 'import_export_screen.dart';
import 'all_medicines_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatelessWidget {
  static const String routeName = '/';

  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MedicineStore>();
    final settings = context.watch<SettingsStore>();
    final badgeNum = store.countNotificationsToShow();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الصيدلية'),
        actions: [
          // زر لتبديل الوضع الفاتح/الداكن:
          IconButton(
            icon: Icon(
              settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            onPressed: () {
              settings.toggleDarkMode(!settings.isDarkMode);
            },
            tooltip: settings.isDarkMode ? 'الوضع الفاتح' : 'الوضع الداكن',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          // إذا كان العرض أكبر من 600 → شبكة بثلاثة أعمدة
          int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

          // اضبطنا aspectRatio للشاشات الضيقة كي تتاح مساحة عمودية أكبر
          double aspectRatio;
          if (constraints.maxWidth > 600) {
            aspectRatio = 1.5; // شبكات 3 أعمدة
          } else {
            aspectRatio = 1.1; // شبكات 2 عمود → ارتفاع أكبر أكثر من السابق
          }

          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: aspectRatio,
            children: [
              // بطاقة "بحث عن دواء"
              MainMenuCard(
                icon: Icons.search,
                title: 'بحث عن دواء',
                gradientColors: [
                  Colors.teal.shade400,
                  Colors.teal.shade200,
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SearchScreen(),
                    ),
                  );
                },
              ),

              // بطاقة "إضافة دواء"
              MainMenuCard(
                icon: Icons.add_circle_outline,
                title: 'إضافة دواء',
                gradientColors: [
                  Colors.teal.shade700,
                  Colors.green.shade400,
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddMedicineScreen(
                        onAdd: (newMed) {
                          store.addMedicine(newMed);
                        },
                      ),
                    ),
                  );
                },
              ),

              // بطاقة "التنبيهات" مع شارة العدّاد
              Stack(
                children: [
                  MainMenuCard(
                    icon: Icons.notifications_active_outlined,
                    title: 'التنبيهات',
                    gradientColors: [
                      Colors.orange.shade700,
                      Colors.orange.shade400,
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                  if (badgeNum > 0)
                    Positioned(
                      right: 16,
                      top: 10,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.red,
                        child: Text(
                          '$badgeNum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // بطاقة "التقارير الإحصائية" (ثنائي السطر)
              MainMenuCard(
                icon: Icons.analytics_outlined,
                title: 'التقارير\nالإحصائية',
                gradientColors: [
                  Colors.purple.shade700,
                  Colors.purple.shade300,
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StatisticsScreen(),
                    ),
                  );
                },
              ),

              // بطاقة "استيراد/تصدير"
              MainMenuCard(
                icon: Icons.import_export,
                title: 'استيراد/تصدير',
                gradientColors: [
                  Colors.blueGrey.shade500,
                  Colors.blue.shade200,
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ImportExportScreen(),
                    ),
                  );
                },
              ),

              // بطاقة "كل الأدوية"
              MainMenuCard(
                icon: Icons.list,
                title: 'كل الأدوية',
                gradientColors: [
                  Colors.teal.shade500,
                  Colors.teal.shade200,
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllMedicinesScreen(),
                    ),
                  );
                },
              ),

              // بطاقة "الإعدادات"
              MainMenuCard(
                icon: Icons.settings,
                title: 'الإعدادات',
                gradientColors: [
                  Colors.grey.shade700,
                  Colors.grey.shade500,
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// بطاقة عامة تستخدمها شاشة القائمة الرئيسية
class MainMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const MainMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      splashColor: gradientColors.first.withOpacity(0.22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.13),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.white),
              const SizedBox(height: 8),
              // العنوان مع تمكين التقسيم إلى سطرين
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
