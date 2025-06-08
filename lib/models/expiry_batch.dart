import 'package:drift/drift.dart';
import '../services/database.dart' as dr; // للوصول إلى ExpiryBatchesCompanion

/// كلاس شخصيّ لدفعة الصلاحية (نُميّزه عن DataClass المولَّد بواسطة Drift)
class ExpiryBatch {
  final int? id;
  final int medicineId;
  final DateTime expiryDate;
  final int quantity;

  ExpiryBatch({
    this.id,
    required this.medicineId,
    required this.expiryDate,
    required this.quantity,
  });

  /// ينشئ ExpiryBatch من DataClass المولَّد بواسطة Drift (ExpiryBatche)
  factory ExpiryBatch.fromDrift(dr.ExpiryBatche data) {
    return ExpiryBatch(
      id: data.id,
      medicineId: data.medicineId,
      expiryDate: data.expiryDate,
      quantity: data.quantity,
    );
  }

  /// يحوّل هذا الكلاس الشخصيّ إلى Companion كي ندخّله في جدول ExpiryBatches
  dr.ExpiryBatchesCompanion toDriftCompanion() {
    return dr.ExpiryBatchesCompanion(
      id: id == null ? const Value.absent() : Value(id!),
      medicineId: Value(medicineId),
      expiryDate: Value(expiryDate),
      quantity: Value(quantity),
    );
  }

  factory ExpiryBatch.fromJson(Map<String, dynamic> json) => ExpiryBatch(
        id: json['id'] as int?,
        medicineId: json['medicineId'] as int,
        expiryDate: DateTime.parse(json['expiryDate'] as String),
        quantity: json['quantity'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineId': medicineId,
        'expiryDate': expiryDate.toIso8601String(),
        'quantity': quantity,
      };
}


