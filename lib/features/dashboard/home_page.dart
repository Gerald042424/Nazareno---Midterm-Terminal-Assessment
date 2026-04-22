import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/task_model.dart';
import '../../core/services/sync_service.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/preferences_helper.dart';
import '../tasks/task_provider.dart';
import '../auth/auth_provider.dart';
import 'connectivity_provider.dart';
import 'sync_provider.dart';
import 'weather_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _dialogFormKey = GlobalKey<FormState>();
  bool _wasOffline = false;
  ConnectivityProvider? _connectivityProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _connectivityProvider = context.read<ConnectivityProvider>();
      final TaskProvider taskProvider = context.read<TaskProvider>();
      final WeatherProvider weatherProvider = context.read<WeatherProvider>();
      final SyncService syncService = context.read<SyncService>();

      _wasOffline = !_connectivityProvider!.isOnline;
      _connectivityProvider!.addListener(_onConnectivityChanged);
      
      if (mounted && _connectivityProvider!.isOnline) {
        await syncService.restoreCloudTasksToLocal();
      }
      await taskProvider.loadTasks();
      if (mounted && _connectivityProvider!.isOnline) {
        final AuthProvider authProvider = context.read<AuthProvider>();
        final String city = await PreferencesHelper.getWeatherCity(authProvider.user?.uid);
        await weatherProvider.fetchWeather(city: city, userId: authProvider.user?.uid);
      }
    });
  }

  @override
  void dispose() {
    _connectivityProvider?.removeListener(_onConnectivityChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (_connectivityProvider == null) return;
    final bool isOnline = _connectivityProvider!.isOnline;

    if (_wasOffline && isOnline) {
      _syncNow();
    }

    _wasOffline = !isOnline;
  }

  Future<void> _showCreateTaskDialog() async {
    _titleController.clear();
    _descriptionController.clear();

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create Task'),
          content: Form(
            key: _dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (String? value) =>
                      Validators.validateRequired(value ?? '', 'Title'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (String? value) =>
                      Validators.validateRequired(value ?? '', 'Description'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final NavigatorState dialogNavigator = Navigator.of(context);
                final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                  this.context,
                );
                if (!_dialogFormKey.currentState!.validate()) {
                  return;
                }

                final bool success = await this.context
                    .read<TaskProvider>()
                    .createTask(
                      title: _titleController.text,
                      description: _descriptionController.text,
                    );
                if (!mounted) {
                  return;
                }
                dialogNavigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Task saved locally.' : 'Failed to save task.',
                    ),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _syncNow() async {
    final ConnectivityProvider connectivityProvider = context
        .read<ConnectivityProvider>();
    final SyncProvider syncProvider = context.read<SyncProvider>();
    final TaskProvider taskProvider = context.read<TaskProvider>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    if (!connectivityProvider.isOnline) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No internet. Sync is disabled.')),
      );
      return;
    }

    final bool success = await syncProvider.sync();
    await taskProvider.loadTasks();

    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (syncProvider.successMessage ?? 'Sync complete.')
              : (syncProvider.errorMessage ?? 'Sync failed.'),
        ),
      ),
    );
  }

  String _getLastSyncText(DateTime? lastSyncTime) {
    if (lastSyncTime == null) {
      return 'Last sync: Not synced yet';
    }

    final Duration difference = DateTime.now().difference(lastSyncTime);

    if (difference.inSeconds < 60) {
      return 'Last sync: Just now';
    } else if (difference.inMinutes < 60) {
      return 'Last sync: ${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return 'Last sync: ${difference.inHours} hr${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Last sync: ${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
  }

  String _getWeatherGifAsset(String condition) {
    final String normalizedCondition = condition.trim().toLowerCase();
    final bool isNight = _isNightTime();

    switch (normalizedCondition) {
      case 'clear':
        return isNight ? 'assets/weather/night.gif' : 'assets/weather/sunny.gif';
      case 'clouds':
        return 'assets/weather/clouds.gif';
      case 'rain':
      case 'drizzle':
        return 'assets/weather/rain.gif';
      case 'thunderstorm':
        return 'assets/weather/thunderstorm.gif';
      case 'snow':
        return 'assets/weather/snow.gif';
      case 'mist':
      case 'fog':
      case 'haze':
        return 'assets/weather/fog.gif';
      default:
        return 'assets/weather/clouds.gif';
    }
  }

  bool _isNightTime() {
    final int hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  @override
  Widget build(BuildContext context) {
    final ConnectivityProvider connectivityProvider = context
        .watch<ConnectivityProvider>();
    final WeatherProvider weatherProvider = context.watch<WeatherProvider>();
    final TaskProvider taskProvider = context.watch<TaskProvider>();
    final SyncProvider syncProvider = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Agent Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final AuthProvider authProvider = context.read<AuthProvider>();
          if (connectivityProvider.isOnline) {
            await context.read<SyncService>().restoreCloudTasksToLocal();
          }
          await taskProvider.loadTasks();
          if (connectivityProvider.isOnline) {
            final String city = await PreferencesHelper.getWeatherCity(authProvider.user?.uid);
            if (!mounted) return;
            await weatherProvider.fetchWeather(city: city, userId: authProvider.user?.uid);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: weatherProvider.weather != null
                            ? Image.asset(
                                key: ValueKey<String>(
                                    _getWeatherGifAsset(weatherProvider.weather!.condition)),
                                _getWeatherGifAsset(weatherProvider.weather!.condition),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.error, color: Colors.red),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey.shade300,
                                key: const ValueKey<String>('default'),
                              ),
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: <Widget>[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text(
                                    'Weather',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (weatherProvider.isLoading)
                                    const SizedBox(
                                      height: 24,
                                      child: LinearProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  else if (!connectivityProvider.isOnline)
                                    const Text(
                                      'No Internet',
                                      style: TextStyle(fontSize: 14, color: Colors.white),
                                    )
                                  else if (weatherProvider.errorMessage != null)
                                    Text(
                                      weatherProvider.errorMessage!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.orangeAccent,
                                      ),
                                    )
                                  else if (weatherProvider.weather !=
                                      null) ...<Widget>[
                                    Text(
                                      weatherProvider.weather!.locationName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${weatherProvider.weather!.temperature.toStringAsFixed(0)}°C | ${weatherProvider.weather!.condition}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ] else
                                    const Text(
                                      'N/A',
                                      style: TextStyle(fontSize: 14, color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: weatherProvider.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                              onPressed:
                                  connectivityProvider.isOnline &&
                                      !weatherProvider.isLoading
                                  ? () async {
                                      final AuthProvider authProvider = context.read<AuthProvider>();
                                      final String city = await PreferencesHelper.getWeatherCity(authProvider.user?.uid);
                                      await weatherProvider.fetchWeather(city: city, userId: authProvider.user?.uid);
                                    }
                                  : null,
                              tooltip: 'Refresh Weather',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        connectivityProvider.isOnline
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        color: connectivityProvider.isOnline
                            ? Colors.green
                            : Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              connectivityProvider.isOnline
                                  ? 'Status: 🟢 Online'
                                  : 'Status: 🔴 Offline',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: connectivityProvider.isOnline
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getLastSyncText(syncProvider.lastSyncTime),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sync Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ElevatedButton.icon(
                                icon: syncProvider.isSyncing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.sync, size: 18),
                                label: const Text(
                                  'Sync Now',
                                  style: TextStyle(fontSize: 14),
                                ),
                                onPressed: connectivityProvider.isOnline &&
                                        !syncProvider.isSyncing
                                    ? _syncNow
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text(
                                  'Add Task',
                                  style: TextStyle(fontSize: 14),
                                ),
                                onPressed: _showCreateTaskDialog,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add tasks and sync them to the cloud.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          Text(
                            'Local Tasks (Offline)',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.cloud_done,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${taskProvider.tasks.where((TaskModel t) => t.status == AppConstants.taskStatusSynced).length} Synced',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 27,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(
                                  Icons.edit_note,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${taskProvider.tasks.where((TaskModel t) => t.status == AppConstants.taskStatusDraft).length} Unsynced',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (taskProvider.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (taskProvider.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            taskProvider.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else if (taskProvider.tasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No tasks yet. Tap Add Task to create one.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      else
                        ...taskProvider.tasks.map(_buildTaskTile),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTile(TaskModel task) {
    final bool isSynced = task.status == AppConstants.taskStatusSynced;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red,
              ),
              onPressed: () => _deleteTask(task),
              tooltip: 'Delete Task',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSynced ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSynced
                      ? Colors.green.shade200
                      : Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Text(
                isSynced ? 'synced' : 'unsynced',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSynced
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTask(TaskModel task) async {
    final int? taskId = task.id;
    if (taskId == null) return;

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Task'),
              content: Text('Are you sure you want to delete "${task.title}"?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;
    if (!mounted) return;

    final TaskProvider taskProvider = context.read<TaskProvider>();
    final ConnectivityProvider connectivityProvider = context
        .read<ConnectivityProvider>();
    final SyncService syncService = context.read<SyncService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool localDeleted = await taskProvider.deleteTask(taskId);
    if (!localDeleted) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to delete task locally.')),
      );
      return;
    }

    if (task.status == AppConstants.taskStatusSynced &&
        connectivityProvider.isOnline) {
      await syncService.deleteTaskFromFirestore(taskId);
    }

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Task deleted successfully.')),
    );
  }
}
