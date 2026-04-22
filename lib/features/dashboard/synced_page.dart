import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/task_model.dart';
import '../../core/utils/app_constants.dart';
import '../../core/utils/app_theme.dart';
import 'connectivity_provider.dart';
import 'providers/firebase_task_provider.dart';

class SyncedPage extends StatefulWidget {
  const SyncedPage({super.key});

  @override
  State<SyncedPage> createState() => _SyncedPageState();
}

class _SyncedPageState extends State<SyncedPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ConnectivityProvider connectivityProvider = context
          .read<ConnectivityProvider>();
      final FirebaseTaskProvider firebaseTaskProvider = context
          .read<FirebaseTaskProvider>();

      await connectivityProvider.initialize();
      if (connectivityProvider.isOnline) {
        await firebaseTaskProvider.loadFirebaseTasks();
      }
    });
  }

  Future<void> _refreshTasks() async {
    final ConnectivityProvider connectivityProvider = context
        .read<ConnectivityProvider>();
    final FirebaseTaskProvider firebaseTaskProvider = context
        .read<FirebaseTaskProvider>();

    if (connectivityProvider.isOnline) {
      await firebaseTaskProvider.loadFirebaseTasks();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Cannot refresh.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConnectivityProvider connectivityProvider = context
        .watch<ConnectivityProvider>();
    final FirebaseTaskProvider firebaseTaskProvider = context
        .watch<FirebaseTaskProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synced Tasks'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTasks,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Cloud Data Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.cloud,
                        color: connectivityProvider.isOnline
                            ? AppTheme.primaryColor
                            : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Cloud Data (Online)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              connectivityProvider.isOnline
                                  ? '${firebaseTaskProvider.tasks.length} task(s) synced'
                                  : 'Offline',
                              style: TextStyle(
                                fontSize: 13,
                                color: connectivityProvider.isOnline
                                    ? Colors.grey
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!connectivityProvider.isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Synced Tasks List
              if (firebaseTaskProvider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (firebaseTaskProvider.errorMessage != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            firebaseTaskProvider.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (firebaseTaskProvider.tasks.isEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          connectivityProvider.isOnline
                              ? Icons.cloud_off
                              : Icons.wifi_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          connectivityProvider.isOnline
                              ? 'No synced tasks found in the cloud.'
                              : 'Offline mode. Connect to internet to view synced tasks.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...firebaseTaskProvider.tasks.map(_buildTaskTile),
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
            Icon(
              isSynced ? Icons.cloud_done : Icons.cloud_upload,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
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
            const SizedBox(width: 8),
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
}
