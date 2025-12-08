import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:storage_app/services/transfer_persistance_service.dart';
import 'package:storage_app/services/transfer_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'api_services.dart';
import 'local_notification_service.dart';

// --- Global Initialization Functions (omitted for brevity, assume correct) ---

void registerWorkManagerTask({
  required String taskId,
  required bool isUpload,
}) {
  Workmanager().registerOneOffTask(
    taskId,
    isUpload ? 'upload_task' : 'download_task',
    inputData: <String, dynamic>{
      'file_id': taskId,
    },
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresDeviceIdle: false,
    ),
    backoffPolicy: BackoffPolicy.exponential,
  );
}

/// The top-level entry point for native platforms (must be static/global).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskId, inputData) async {
    // 1. Manual Dependency Injection
    final dio = Dio();
    final apiProvider = ApiProvider(dio);
    final persistenceService = TransferPersistenceService();
    final notificationService = NotificationService();

    await notificationService.initializeNotifications();

    final transferService = TransferService(apiProvider, notificationService, persistenceService);

    final fileId = inputData?['file_id'] as String?;
    if (fileId == null) return Future.value(true);

    final metadata = await persistenceService.getTransferMetadata(fileId);
    if (metadata == null) {
      print('WorkManager: Metadata not found for $fileId. Skipping task.');
      return Future.value(true);
    }

    final filePath = metadata['filePath'] as String;
    final fileUrl = metadata['fileUrl'] as String?;
    final fileName = metadata['fileName'] as String;
    final isUpload = metadata['isUpload'] as bool;
    final int startByte = await persistenceService.getLastSavedByteCount(fileId) ?? 0;
    print('WorkManager: Starting task $fileId from byte offset: $startByte');

    // --- Core Execution Logic Setup ---

    final progressController = StreamController<double>();
    Future<dynamic> executionFuture;
    Stream<double> progressStream;

    if (isUpload) {
      // UPLOAD SETUP
      executionFuture = transferService.startUpload(
        filePath: filePath,
        fileName: fileName,
        taskId: fileId,
        startByte: startByte,
        onProgressUpdate: (progress) {
          if (!progressController.isClosed) {
            // 🚨 CRITICAL: We must save the progress bytes here to ensure
            // the resumability data is updated even when the app is killed.
            // NOTE: The TransferService.startUpload must call the persistence service.
            progressController.add(progress);
          }
        },
      ).whenComplete(() {
        // Close the stream once the Future is resolved (success or failure)
        if (!progressController.isClosed) progressController.close();
      });
      progressStream = progressController.stream;

    } else {
      // DOWNLOAD SETUP
      progressStream = transferService.startDownload(
        fileUrl!,
        filePath,
        fileName,
        fileId,
        startByte: startByte,
      );
      // The stream ending signifies completion/success.
      executionFuture = Future.value(null); // Set a dummy future for consistency
    }

    // --- Monitoring Loop & Final Completion ---
    try {
      // Await the stream for progress updates and show notification
      await for (double progress in progressStream) {
        notificationService.notificationsPlugin.show(
          fileId.hashCode,
          isUpload ? "Uploading..." : "Downloading...",
          "$fileName: ${(progress * 100).toStringAsFixed(1)}%",
          NotificationDetails(
            android: AndroidNotificationDetails(
              NotificationService.channelId,
              NotificationService.channelName,
              showProgress: true,
              maxProgress: 100,
              progress: (progress * 100).toInt(),
              ongoing: true,
              color: const Color(0xFF2196F3),
            ),
          ),
        );
      }

      // 5. FINAL WAIT/RESOLUTION:
      // For uploads, the await for loop finishes when the upload stream closes,
      // which happens when the Future resolves. We ensure the Future completed successfully
      // here to catch any final errors from the network service.
      if (isUpload) {
        await executionFuture;
      }

      // If we reach here, the transfer is complete (stream closed successfully).

      // Show final success notification
      transferService.showCompletionNotification(
          taskId: fileId, fileName: fileName, isUpload: isUpload, isSuccess: true
      );

      // Clean up metadata (progress bytes, paths, etc.)
      await persistenceService.cleanupTransferMetadata(fileId);

      // WorkManager success signal
      return Future.value(true);

    } catch (e) {
      print('WorkManager Task Failed: $e');

      // 🚨 FIX: Remove the redundant progressController.close() call here,
      // as it's handled in the finally block or executionFuture.whenComplete().

      // Graceful handling for cancellation (User Pause)
      if (e is DioException && e.type == DioExceptionType.cancel) {
        print('WorkManager: Task was cancelled (e.g., user paused).');
        // Return true to stop retries on user-initiated pause
        return Future.value(true);
      }

      // On network failure or exception, notify user
      transferService.showCompletionNotification(
          taskId: fileId, fileName: fileName, isUpload: isUpload, isSuccess: false
      );

      // WorkManager failure signal (retries based on BackoffPolicy)
      return Future.value(false);
    } finally {
      // Ensure the controller is closed if it wasn't by executionFuture.whenComplete (safer for downloads)
      if (!progressController.isClosed) {
        await progressController.close();
      }
      // Always cancel the notification on completion or failure
      notificationService.notificationsPlugin.cancel(fileId.hashCode);
    }
  });
}

void initializeWorkManager() {
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
}