import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_theme.dart';
import '../../core/utils/preferences_helper.dart';
import '../auth/auth_provider.dart';
import 'weather_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _cityController = TextEditingController();
  String _currentCity = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentCity();
  }

  Future<void> _loadCurrentCity() async {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String city = await PreferencesHelper.getWeatherCity(authProvider.user?.uid);
    setState(() {
      _currentCity = city;
      _cityController.text = city;
    });
  }

  Future<void> _saveCity() async {
    final String newCity = _cityController.text.trim();
    if (newCity.isNotEmpty && newCity != _currentCity) {
      final AuthProvider authProvider = context.read<AuthProvider>();
      await PreferencesHelper.setWeatherCity(authProvider.user?.uid ?? '', newCity);
      setState(() {
        _currentCity = newCity;
      });
      if (mounted) {
        final WeatherProvider weatherProvider = context.read<WeatherProvider>();
        await weatherProvider.fetchWeather(city: newCity, userId: authProvider.user?.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Weather city updated successfully.')),
          );
        }
      }
    }
  }

  String _maskEmail(String email) {
    final int atIndex = email.indexOf('@');
    if (atIndex <= 0) return email;
    final String localPart = email.substring(0, atIndex);
    final String domain = email.substring(atIndex);
    if (localPart.length <= 2) return email;
    return '${localPart[0]}***${localPart[localPart.length - 1]}$domain';
  }

  Future<void> _showLogoutDialog(BuildContext context, AuthProvider authProvider) async {
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true && context.mounted) {
      await authProvider.logout();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Profile Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Account Info Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Account Info',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: _maskEmail(user?.email ?? 'unknown@email.com'),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.person,
                      label: 'Display Name',
                      value: user?.displayName ?? 'Unknown',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // App Info Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'App Info',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.info,
                      label: 'Version',
                      value: '1.0.0',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: Icons.cloud,
                      label: 'Sync Status',
                      value: 'Active',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Weather Settings Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Weather Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'Weather City',
                        hintText: 'Enter city name (e.g., Manila)',
                        prefixIcon: const Icon(Icons.location_city),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.save),
                          onPressed: _saveCity,
                          tooltip: 'Save city',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current: $_currentCity',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Logout Button
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context, authProvider),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Logout', style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
