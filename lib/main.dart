import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';
import 'services/ai_classifier_service.dart';
import 'services/auth_service.dart';
import 'services/photo_store.dart';
import 'services/report_repository.dart';
import 'services/report_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SiFasilitasApp());
}

class SiFasilitasApp extends StatelessWidget {
  const SiFasilitasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ReportService>(create: (_) => ReportService()),
        Provider<ReportRepository>(create: (_) => ReportRepository()),
        Provider<PhotoStore>(create: (_) => FirestorePhotoStore.shared),
        Provider<AiClassifierService>(
          create: (_) => const AiClassifierService(),
        ),
      ],
      child: MaterialApp(
        title: 'SiFasilitas',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
