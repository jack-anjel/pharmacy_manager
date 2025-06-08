// lib/screens/all_medicines_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/medicine_store.dart';
import '../models/medicine.dart';
import 'medicine_detail_screen.dart';

class AllMedicinesScreen extends StatelessWidget {
  static const String routeName = '/allMedicines';

  const AllMedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MedicineStore>();
    final all = store.medicines; // قائمة الموديلات الشخصية

    return Scaffold(
      appBar: AppBar(title: const Text('كل الأدوية')),
      body: all.isEmpty
          ? Center(
              child: Text(
                'لا توجد أدوية محفوظة.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.separated(
              itemCount: all.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final m = all[idx];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    m.name,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    'المجموعة: ${m.category} • الكمية: ${m.totalQuantity}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicineDetailScreen(
                          medicine: m,
                          onUpdate: (updatedMed) {
                            // عند العودة من شاشة التفاصيل مع موديل محدث
                            store.updateMedicine(updatedMed);
                          },
                          onDelete: () {
                            if (m.id != null) {
                              store.deleteMedicine(m.id!);
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
