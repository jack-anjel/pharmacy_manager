/// lib/models/medicine.dart
library;

// أضف السطر التالي لكي يتعرف على MedicineData و ExpiryBatchData
import 'package:pharmacy_manager/services/database.dart';

/// هذه الفئة لم تعد تُستخدم مباشرة في الشاشات؛
/// وإنما نعتمد في الواجهات على البيانات المنزّلة من Drift: MedicineData وExpiryBatchData.
/// ولكن نحتفظ بها في حال احتجنا إلى إنشاء كائنات مؤقتة (مثال: عند الاستيراد).
class Medicine {
  final int id;
  final String name;
  final String category;
  final String? price;
  final String? company;
  final bool isMuted;
  final List<ExpiryBatch> expiries; // قائمة دفعات الصلاحية

  Medicine({
    required this.id,
    required this.name,
    required this.category,
    this.price,
    this.company,
    this.isMuted = false,
    this.expiries = const [],
  });

  /// تحويل من drift (MedicineData + ExpiryBatchData)
  factory Medicine.fromDrift({
    required MedicineData medData,
    required List<ExpiryBatchData> batchDataList,
  }) {
    return Medicine(
      id: medData.id,
      name: medData.name,
      category: medData.category,
      price: medData.price,
      company: medData.company,
      isMuted: medData.isMuted,
      expiries: batchDataList
          .map((b) => ExpiryBatch.fromDrift(b))
          .toList(),
    );
  }

  /// تحويل إلى JSON (عند الحفظ أو التصدير)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'company': company,
      'isMuted': isMuted ? 1 : 0,
      'expiries': expiries.map((e) => e.toJson()).toList(),
    };
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    final List<ExpiryBatch> batches = [];
    if (json['expiries'] is List) {
      for (var e in (json['expiries'] as List)) {
        try {
          batches.add(ExpiryBatch.fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    return Medicine(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String,
      price: json['price'] as String?,
      company: json['company'] as String?,
      isMuted: (json['isMuted'] as int? ?? 0) == 1,
      expiries: batches,
    );
  }
}
