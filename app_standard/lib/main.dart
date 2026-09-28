import 'package:flutter/material.dart';
import 'database/db_helper.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation FFI SQLite pour Desktop (Windows / Linux)
  DbHelper.initFfiIfNeeded();

  runApp(const AchatVenteStockApp());
}

class AchatVenteStockApp extends StatelessWidget {
  const AchatVenteStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Caisse & Trésorerie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShell(),
    );
  }
}
