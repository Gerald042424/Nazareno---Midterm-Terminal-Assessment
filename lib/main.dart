import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/services/auth_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/sqlite_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/weather_service.dart';
import 'core/utils/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/connectivity_provider.dart';
import 'features/dashboard/main_screen.dart';
import 'features/dashboard/sync_provider.dart';
import 'features/dashboard/weather_provider.dart';
import 'features/tasks/task_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const StrmApp());
}

class StrmApp extends StatelessWidget {
  const StrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<SqliteService>(create: (_) => SqliteService()),
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(Connectivity()),
        ),
        Provider<AuthService>(
          create: (BuildContext context) => AuthService(
            firebaseAuth: FirebaseAuth.instance,
            connectivityService: context.read<ConnectivityService>(),
          ),
        ),
        Provider<WeatherService>(create: (_) => WeatherService(http.Client())),
        Provider<SyncService>(
          create: (BuildContext context) => SyncService(
            firestore: FirebaseFirestore.instance,
            firebaseAuth: FirebaseAuth.instance,
            sqliteService: context.read<SqliteService>(),
          ),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (BuildContext context) =>
              AuthProvider(context.read<AuthService>()),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create: (BuildContext context) => TaskProvider(
            context.read<SqliteService>(),
            FirebaseAuth.instance,
          ),
        ),
        ChangeNotifierProvider<WeatherProvider>(
          create: (BuildContext context) =>
              WeatherProvider(context.read<WeatherService>()),
        ),
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (BuildContext context) =>
              ConnectivityProvider(context.read<ConnectivityService>()),
        ),
        ChangeNotifierProvider<SyncProvider>(
          create: (BuildContext context) =>
              SyncProvider(context.read<SyncService>()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SecureCloud Task & Resource Manager',
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectivityProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder:
          (BuildContext context, AuthProvider authProvider, Widget? child) {
            if (authProvider.isAuthenticated) {
              return const MainScreen();
            }
            return const LoginScreen();
          },
    );
  }
}
