// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';

import 'theme/design_system.dart';
import 'services/database.dart';
import 'services/medicine_store.dart';
import 'services/settings_store.dart';
import 'services/local_notifications_service.dart';
import 'services/workmanager_callback.dart';

import 'screens/home_screen.dart';

/// مفتاح الـ Navigator لتمريره إلى خدمة الإشعارات
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // رسالة تتبع للتأكد من وصول التنفيذ إلى هنا
  debugPrint("🚀 main() started");

  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة WorkManager
  debugPrint("🔧 Initializing WorkManager…");
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  Workmanager().registerPeriodicTask(
    "pharmacyManagerDailyCheck",
    taskCheckDaily,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    initialDelay: const Duration(minutes: 1),
  );
  debugPrint("✅ WorkManager initialized");

  // 2. تهيئة الإشعارات المحلية
  debugPrint("🔔 Initializing LocalNotificationsService…");
  await LocalNotificationsService.initialize(navigatorKey);
  debugPrint("✅ LocalNotificationsService initialized");

  // 3. جدولة تذكير صباحي عند 8:00
  debugPrint("🗓 Scheduling daily reminder at 08:00…");
  await LocalNotificationsService.scheduleDailyReminder(
    id: 500,
    hour: 8,
    minute: 0,
    title: 'تذكير يومي بالصيدلية',
    body: 'اضغط للاطلاع على التنبيهات',
    payload: 'go_to_notifications',
  );
  debugPrint("✅ Daily reminder scheduled");

  // 4. إنشاء كائن قاعدة البيانات
  debugPrint("🗄 Opening AppDatabase…");
  final database = AppDatabase();
  debugPrint("✅ AppDatabase created");

  // 5. تهيئة MedicineStore باستخدام قاعدة البيانات
  debugPrint("📦 Initializing MedicineStore…");
  final store = MedicineStore.instance(database);
  debugPrint("✅ MedicineStore initialized");

  // 6. تهيئة SettingsStore
  debugPrint("⚙️ Initializing SettingsStore…");
  final settings = SettingsStore();
  debugPrint("✅ SettingsStore initialized");

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<MedicineStore>.value(value: store),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
      ],
      child: const PharmacyApp(),
    ),
  );
}

class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();

    return MaterialApp(
      title: 'إدارة الصيدلية',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: GoogleFonts.cairo().fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          titleTextStyle: AppTextStyles.headline.copyWith(color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          titleLarge: AppTextStyles.headline,
          titleMedium: AppTextStyles.subtitle,
          bodyMedium: AppTextStyles.body,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.primaryVariant,
        scaffoldBackgroundColor: Colors.grey[900],
        fontFamily: GoogleFonts.cairo().fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primaryVariant,
          titleTextStyle: AppTextStyles.headline.copyWith(color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          titleLarge: AppTextStyles.headline,
          titleMedium: AppTextStyles.subtitle,
          bodyMedium: AppTextStyles.body,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
