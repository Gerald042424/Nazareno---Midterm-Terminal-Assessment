import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/services/sqlite_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/weather_service.dart';
import '../tasks/task_provider.dart';
import 'connectivity_provider.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'providers/firebase_task_provider.dart';
import 'sync_provider.dart';
import 'synced_page.dart';
import 'weather_provider.dart';
import 'widgets/bottom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (_) =>
              ConnectivityProvider(context.read<ConnectivityService>()),
        ),
        ChangeNotifierProvider<WeatherProvider>(
          create: (_) => WeatherProvider(context.read<WeatherService>()),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create: (_) => TaskProvider(
            context.read<SqliteService>(),
            FirebaseAuth.instance,
          ),
        ),
        ChangeNotifierProvider<SyncProvider>(
          create: (_) {
            final syncProvider = SyncProvider(
              SyncService(
                firestore: FirebaseFirestore.instance,
                firebaseAuth: FirebaseAuth.instance,
                sqliteService: context.read<SqliteService>(),
              ),
            );
            syncProvider.init(FirebaseAuth.instance.currentUser?.uid);
            return syncProvider;
          },
        ),
        ChangeNotifierProvider<FirebaseTaskProvider>(
          create: (_) => FirebaseTaskProvider(
            firestore: FirebaseFirestore.instance,
            firebaseAuth: FirebaseAuth.instance,
          ),
        ),
      ],
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: const <Widget>[HomePage(), SyncedPage(), ProfilePage()],
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex,
          onTap: _onNavTap,
        ),
      ),
    );
  }
}
