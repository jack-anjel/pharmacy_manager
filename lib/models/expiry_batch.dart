/// lib/models/expiry_batch.dart
library;

// أضف الاستيراد حتى يتعرف الملف على ExpiryBatchData
import 'package:pharmacy_manager/services/database.dart';

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

  /// تحويل من Drift (ExpiryBatchData)
  factory ExpiryBatch.fromDrift(ExpiryBatchData data) {
    return ExpiryBatch(
      id: data.id,
      medicineId: data.medicineId,
      expiryDate: data.expiryDate,
      quantity: data.quantity,
    );
  }

  /// تحويل إلى JSON (عند الحفظ أو التصدير)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineId': medicineId,
      'expiryDate': expiryDate.toIso8601String(),
      'quantity': quantity,
    };
  }

  factory ExpiryBatch.fromJson(Map<String, dynamic> json) {
    return ExpiryBatch(
      id: json['id'] as int?,
      medicineId: json['medicineId'] as int? ?? 0,
      expiryDate: DateTime.parse(json['expiryDate'] as String),
      quantity: json['quantity'] as int,
    );
  }
}



