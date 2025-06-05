import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:external_path/external_path.dart';

import '../services/medicine_store.dart';
import '../models/medicine.dart';

// إذا في الويب نستخدم دالة مساعدة لجلب التنزيل:
import '../services/web_download_stub.dart';

class ImportExportScreen extends StatefulWidget {
  static const String routeName = '/importExport';

  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  bool isProcessing = false;

  Future<void> exportToJson() async {
    setState(() => isProcessing = true);
    final store = context.read<MedicineStore>();
    final data = jsonEncode(store.medicines.map((e) => e.toJson()).toList());

    if (kIsWeb) {
      downloadJsonOnWeb('medicines_export.json', data);
    } else {
      try {
        final downloadsDir =
            await ExternalPath.getExternalStoragePublicDirectory('Download');
        final file = io.File('$downloadsDir/medicines_export.json');
        await file.writeAsString(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('تمّ التصدير إلى: $downloadsDir/medicines_export.json'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء التصدير: ${e.toString()}'),
          ),
        );
      }
    }
    setState(() => isProcessing = false);
  }

  Future<void> importFromJson() async {
    setState(() => isProcessing = true);
    final store = context.read<MedicineStore>();

    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.first.bytes != null) {
        final content = utf8.decode(result.files.first.bytes!);
        try {
          final List<dynamic> decoded = jsonDecode(content);
          final imported = decoded.map((e) => Medicine.fromJson(e)).toList();
          store.medicines = imported;
          store.saveMedicines();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمَّ الاستيراد بنجاح.')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في قراءة الملف: ${e.toString()}')),
          );
        }
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          try {
            final file = io.File(path);
            final content = await file.readAsString();
            final List<dynamic> decoded = jsonDecode(content);
            final imported = decoded.map((e) => Medicine.fromJson(e)).toList();
            store.medicines = imported;
            store.saveMedicines();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تمَّ الاستيراد بنجاح.')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطأ في قراءة الملف: ${e.toString()}')),
            );
          }
        }
      }
    }

    setState(() => isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد/تصدير'),
      ),
      body: Center(
        child: isProcessing
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: exportToJson,
                      icon: const Icon(Icons.download),
                      label: const Text('تصدير إلى JSON'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: importFromJson,
                      icon: const Icon(Icons.upload),
                      label: const Text('استيراد من JSON'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}


