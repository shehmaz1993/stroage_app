import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:storage_app/services/transfer_persistance_service.dart';
import 'package:storage_app/services/transfer_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'api_services.dart';
import 'local_notification_service.dart'; // Needed for Colors in notifications



// --- Global Initialization Functions ---

/// Global function used to register the background task with WorkManager.
void registerWorkManagerTask({
  required String taskId,
  required bool isUpload,
}) {
  // NOTE: Persistence (saving the file path/URL) MUST happen BEFORE this call.
  // The TransferService handles the saving via TransferPersistenceService.

  Workmanager().registerOneOffTask(
    taskId,
    isUpload ? 'upload_task' : 'download_task',
    inputData: <String, dynamic>{
      'file_id': taskId, // Pass only the ID; the worker retrieves data using the ID
    },
    // Constraints ensure the task is reliable
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresDeviceIdle: false, // Run immediately if needed
    ),
    backoffPolicy: BackoffPolicy.exponential, // Recommended for retries
  );
}

/// The top-level entry point for native platforms (must be static/global).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskId, inputData) async {
    // 1. Manually initialize all necessary dependencies (Manual Dependency Injection)
    final dio = Dio();
    final apiProvider = ApiProvider(dio);
    final persistenceService = TransferPersistenceService();
    final notificationService = NotificationService();

    // Initialize notifications within the isolated environment
    await notificationService.initializeNotifications();

    final transferService = TransferService(apiProvider, notificationService, persistenceService); // All services linked

    final fileId = inputData?['file_id'] as String?;
    if (fileId == null) return Future.value(true);

    // 2. Retrieve state from persistent storage
    final metadata = await persistenceService.getTransferMetadata(fileId);
    if (metadata == null) {
      print('WorkManager: Metadata not found for $fileId. Skipping task.');
      return Future.value(true); // Treat as done if metadata is missing
    }

    final filePath = metadata['filePath'] as String;
    final fileUrl = metadata['fileUrl'] as String?;
    final fileName = metadata['fileName'] as String;
    final isUpload = metadata['isUpload'] as bool;

    // --- Core Execution Logic ---
    try {
      final progressStream = isUpload
          ? transferService.startUpload(filePath, fileName, fileId) // Upload path is source
          : transferService.startDownload(fileUrl!, filePath, fileId,taskId); // Download path is destination

      await for (double progress in progressStream) {
        // 3. Update the persistent notification with real-time progress
        notificationService.notificationsPlugin.show(
          fileId.hashCode, // Unique ID for this task
          isUpload ? "Uploading..." : "Downloading...",
          "$fileName: ${(progress * 100).toStringAsFixed(1)}%",
          NotificationDetails(
            android: AndroidNotificationDetails(
              NotificationService.channelId,
              NotificationService.channelName,
              showProgress: true,
              maxProgress: 100,
              progress: (progress * 100).toInt(),
              ongoing: true, // Keep notification visible during transfer
              color: Colors.blue,
            ),
          ),
        );
      }

      // 4. Cleanup and Success Notification
      await persistenceService.cleanupTransferMetadata(fileId);

      transferService.showCompletionNotification(
          taskId: fileId, fileName: fileName, isUpload: isUpload, isSuccess: true
      );

      // WorkManager success signal
      return Future.value(true);

    } catch (e) {
      print('WorkManager Task Failed: $e');

      // On network failure or exception, notify user and signal retry
      transferService.showCompletionNotification(
          taskId: fileId, fileName: fileName, isUpload: isUpload, isSuccess: false
      );

      // WorkManager failure signal (retries based on BackoffPolicy)
      return Future.value(false);
    }
  });
}

/// Main initialization called once in main()
void initializeWorkManager() {
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
}