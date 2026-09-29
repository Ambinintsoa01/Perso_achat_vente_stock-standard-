import 'package:flutter/material.dart';
import 'database/db_helper.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation FFI SQLite pour Desktop (Windows / Linux)
  DbHelper.initFfiIfNeeded();

  runApp(const AchatVenteStockApp());
}

class AchatVenteStockApp extends StatelessWidget {
  final bool startAuthenticated;

  const AchatVenteStockApp({super.key, this.startAuthenticated = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final isAuth = AuthService.instance.isAuthenticated || startAuthenticated;

        return MaterialApp(
          title: 'Gestion Commerciale & Stock',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: isAuth ? const MainShell() : const LoginScreen(),
        );
      },
    );
  }
}

