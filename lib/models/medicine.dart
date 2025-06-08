import 'package:drift/drift.dart'; // لـ Value و MedicinesCompanion
import '../services/database.dart' as dr; // للوصول إلى dr.Medicine و dr.MedicinesCompanion
import 'expiry_batch.dart';             // ExpiryBatch (الكلاس الشخصي)

/// كلاس شخصيّ لدواء مع قائمة دفعاته
class Medicine {
  final int? id;
  final String name;
  final String category;
  final String? price;
  final String? company;
  final bool isMuted;
  final List<ExpiryBatch> expiries;

  Medicine({
    this.id,
    required this.name,
    required this.category,
    this.price,
    this.company,
    this.isMuted = false,
    required this.expiries,
  });

  /// ينشئ Medicine شخصيّ من DataClass المولَّد بواسطة Drift (dr.Medicine)
  factory Medicine.fromDrift(dr.Medicine data, List<ExpiryBatch> batchData) {
    return Medicine(
      id: data.id,
      name: data.name,
      category: data.category,
      price: data.price,
      company: data.company,
      isMuted: data.isMuted,
      expiries: batchData,
    );
  }

  /// يحوّل هذا الكلاس الشخصيّ إلى Companion كي ندخّله في جدول Medicines
  dr.MedicinesCompanion toDriftCompanion() {
    return dr.MedicinesCompanion(
      id: id == null ? const Value.absent() : Value(id!),
      name: Value(name),
      category: Value(category),
      price: Value(price),
      company: Value(company),
      isMuted: Value(isMuted),
    );
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    final batchesJson = json['expiries'] as List<dynamic>? ?? [];
    final batchObjs = batchesJson
        .map((e) => ExpiryBatch.fromJson(e as Map<String, dynamic>))
        .toList();

    return Medicine(
      id: json['id'] as int?,
      name: json['name'] as String,
      category: json['category'] as String,
      price: json['price'] as String?,
      company: json['company'] as String?,
      isMuted: json['isMuted'] as bool? ?? false,
      expiries: batchObjs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'company': company,
        'isMuted': isMuted,
        'expiries': expiries.map((e) => e.toJson()).toList(),
      };

  /// لحساب إجمالي الكمية عبر كل دفعات الصلاحية
  int get totalQuantity =>
      expiries.fold<int>(0, (sum, batch) => sum + batch.quantity);
}


