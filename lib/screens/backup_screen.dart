// lib/screens/backup_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

import '../services/medicine_store.dart';
import '../models/medicine.dart';
import '../models/expiry_batch.dart';
import '../theme/design_system.dart';

/// شاشة للنسخ الاحتياطي (تصدير JSON/CSV) والاستعادة (استيراد JSON/CSV).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isProcessing = false;

  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return null;
      }
      return await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[<>:"\/\\|?*]'), '_');
  }

  Future<void> _exportAsJson() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final store = Provider.of<MedicineStore>(context, listen: false);
      final meds = store.medicines; // List<Medicine> (موديلاتنا الشخصية)

      // نصدر قائمة من خرائط JSON مباشرةً
      final List<Map<String, dynamic>> data =
          meds.map((m) => m.toJson()).toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await _getDownloadsDirectory();
      if (dir == null) throw Exception('لم يُسمح بالوصول إلى التخزين');

      final fileName =
          'medicines_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = '${dir.path}/${_sanitizeFileName(fileName)}';
      final file = File(filePath);
      await file.writeAsString(jsonString, flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ الملف في: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _exportAsCsv() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final store = Provider.of<MedicineStore>(context, listen: false);
      final meds = store.medicines;

      // رؤوس الأعمدة
      final headers = [
        'id',
        'name',
        'category',
        'price',
        'company',
        'expiry_date',
        'quantity',
        'isMuted'
      ];
      final buffer = StringBuffer()..writeln(headers.join(','));

      for (var m in meds) {
        if (m.expiries.isEmpty) {
          // صف بدون دفعات
          final fields = [
            m.id?.toString() ?? '',
            '"${m.name}"',
            '"${m.category}"',
            m.price == null ? '' : '"${m.price!}"',
            m.company == null ? '' : '"${m.company!}"',
            '',
            '',
            m.isMuted ? '1' : '0'
          ];
          buffer.writeln(fields.join(','));
        } else {
          // صف لكل دفعة
          for (var e in m.expiries) {
            final expiryStr = e.expiryDate.toIso8601String();
            final fields = [
              m.id?.toString() ?? '',
              '"${m.name}"',
              '"${m.category}"',
              m.price == null ? '' : '"${m.price!}"',
              m.company == null ? '' : '"${m.company!}"',
              '"$expiryStr"',
              e.quantity.toString(),
              m.isMuted ? '1' : '0'
            ];
            buffer.writeln(fields.join(','));
          }
        }
      }

      final dir = await _getDownloadsDirectory();
      if (dir == null) throw Exception('لم يُسمح بالوصول إلى التخزين');

      final fileName =
          'medicines_backup_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${dir.path}/${_sanitizeFileName(fileName)}';
      final file = File(filePath);
      await file.writeAsString(buffer.toString(), flush: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ الملف في: ${file.path}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _importJson() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;

      // نحوّل كل عنصر إلى Medicine شخصي
      final imported = <Medicine>[];
      for (var item in list) {
        try {
          imported.add(Medicine.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // نتجاهل العناصر غير الصالحة
        }
      }
      if (imported.isEmpty) {
        throw Exception('لم يتم العثور على بيانات صالحة في الملف');
      }

      final store = Provider.of<MedicineStore>(context, listen: false);
      for (var m in imported) {
        final newMedId = await store.addMedicine(
          name: m.name,
          category: m.category,
          price: m.price,
          company: m.company,
        );
        for (var e in m.expiries) {
          await store.addBatch(
            medicineId: newMedId,
            expiryDate: e.expiryDate,
            quantity: e.quantity,
          );
        }
      }
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استيراد البيانات بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاستيراد: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _importCsv() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        throw Exception('الملف فارغ');
      }

      final header = lines.first.split(',');
      final dataLines = lines.skip(1);
      final Map<int, _TempMedicine> tempMap = {};

      for (var raw in dataLines) {
        final parts = _parseCsvLine(raw);
        if (parts.length < 8) continue;

        final id = int.tryParse(parts[0]) ??
            DateTime.now().millisecondsSinceEpoch; // معرف وهمي في حال التعذّر
        final name = parts[1].replaceAll('"', '');
        final category = parts[2].replaceAll('"', '');
        final price = parts[3].isEmpty ? null : parts[3].replaceAll('"', '');
        final company =
            parts[4].isEmpty ? null : parts[4].replaceAll('"', '');
        final expiryStr = parts[5].replaceAll('"', '');
        final qty = int.tryParse(parts[6]) ?? 0;
        final isMuted = parts[7] == '1';

        final expiryDate =
            expiryStr.isEmpty ? DateTime.now() : DateTime.tryParse(expiryStr) ?? DateTime.now();
        final batch = ExpiryBatch(
          id: null,
          medicineId: id,
          expiryDate: expiryDate,
          quantity: qty,
        );

        if (!tempMap.containsKey(id)) {
          tempMap[id] = _TempMedicine(
            id: id,
            name: name,
            category: category,
            price: price,
            company: company,
            isMuted: isMuted,
            expiries: [batch],
          );
        } else {
          tempMap[id]!.expiries.add(batch);
        }
      }

      final imported = tempMap.values.toList();
      if (imported.isEmpty) {
        throw Exception('لم يتم العثور على بيانات صالحة في الملف');
      }

      final store = Provider.of<MedicineStore>(context, listen: false);
      for (var m in imported) {
        final newMedId = await store.addMedicine(
          name: m.name,
          category: m.category,
          price: m.price,
          company: m.company,
        );
        for (var e in m.expiries) {
          await store.addBatch(
            medicineId: newMedId,
            expiryDate: e.expiryDate,
            quantity: e.quantity,
          );
        }
      }
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استيراد البيانات بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاستيراد: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"' && (i == 0 || line[i - 1] != '\\')) {
        inQuotes = !inQuotes;
        buffer.write(char);
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نسخ احتياطي / استعادة'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _exportAsJson,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('تصدير JSON'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
            const SizedBox(height: AppSpacing.margin),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _exportAsCsv,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('تصدير CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
            const SizedBox(height: AppSpacing.margin),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _importJson,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('استيراد JSON'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
            const SizedBox(height: AppSpacing.margin),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _importCsv,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('استيراد CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.margin),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

/// نموذج مساعدة مؤقت عند استيراد CSV
class _TempMedicine {
  final int id;
  final String name;
  final String category;
  final String? price;
  final String? company;
  final bool isMuted;
  List<ExpiryBatch> expiries;

  _TempMedicine({
    required this.id,
    required this.name,
    required this.category,
    this.price,
    this.company,
    required this.isMuted,
    required this.expiries,
  });
}
