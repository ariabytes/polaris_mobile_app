import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'controllers/auth_controller.dart';
import 'controllers/material_controller.dart';
import 'controllers/transaction_controller.dart';
import 'services/theme_service.dart';
import 'login_page.dart';
import 'views/admin/admin_navbar.dart';
import 'views/student/navbar.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final themeController = await ThemeModeController.load();
  runApp(PolarisApp(themeController: themeController));
}

class PolarisApp extends StatelessWidget {
  const PolarisApp({super.key, required this.themeController});

  final ThemeModeController themeController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => MaterialController()),
        ChangeNotifierProvider(create: (_) => TransactionController()),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: Consumer<ThemeModeController>(
        builder: (context, themeMode, _) => MaterialApp(
        title: 'Polaris',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        theme: ThemeService.light,
        darkTheme: ThemeService.dark,
        themeMode: themeMode.mode,
        home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) return const LoginPage();
        if (auth.currentUserProfile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return auth.isAdmin ? const AdminNavBar() : const StudentNavBar();
      },
    );
  }
}
