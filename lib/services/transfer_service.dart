import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:storage_app/services/transfer_persistance_service.dart';

import 'api_services.dart';
import 'background_manager.dart';
import 'local_notification_service.dart';


class TransferService {
  final ApiProvider _apiProvider;
  final NotificationService _notificationService;
  final TransferPersistenceService _persistenceService;
  // 🎯 NEW: Map to store Dio CancelToken instances by taskId for cancellation
  final Map<String, CancelToken> _cancelTokens = {};

  // Constructor receives all dependencies via Riverpod
  TransferService(
      this._apiProvider,
      this._notificationService,
      this._persistenceService
      );

  // --- Core Upload Logic ---

  /// Initiates the file upload process, starting from a specific byte offset.
  Future<String> startUpload({
    required String filePath,
    required String fileName,
    required String taskId,
    required int startByte,
    required Function(double progress) onProgressUpdate, // 🎯 NEW progress update callback
  }) async {
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;
    _registerBackgroundAndPersistData(taskId, true, filePath, fileName: fileName);

    final fileLength = File(filePath).lengthSync(); // Get total bytes

    try {
      final String downloadUrl = await _apiProvider.uploadFile(
        filePath: filePath,
        fileName: fileName,
        startByte: startByte,
        cancelToken: cancelToken,

        // 🎯 Dio's callback (int sent, int total) is mapped to notifier's (double progress)
        onSendProgress: (count, total) {
          double totalBytesSent = (count + startByte).toDouble();
          double progress = totalBytesSent / fileLength;
          onProgressUpdate(progress); // Pass calculated progress to the Notifier
        },
      );
      return downloadUrl; // 🎯 Return the URL to the Notifier
    } catch (e) {
      rethrow;
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  // --- Core Download Logic ---

  /// Initiates the file download process, starting from a specific byte offset.
  Stream<double> startDownload(
      String fileUrl,
      String savePath,
      String fileName,
      String taskId,
      {required int startByte}
      ) {
    // We create the controller and return its stream immediately.
    final controller = StreamController<double>();

    // We start the asynchronous work immediately, but DO NOT return the Future.
    _startDownloadAsync(fileUrl, savePath, fileName, taskId, startByte, controller);

    return controller.stream;
  }

  // 🚨 CORRECTION 2: Separate the asynchronous execution logic into a private method
  void _startDownloadAsync(
      String fileUrl,
      String savePath,
      String fileName,
      String taskId,
      int startByte,
      StreamController<double> controller,
      ) async {
    // 1. Hook for background persistence
    _registerBackgroundAndPersistData(taskId, false, savePath, fileName: fileName, fileUrl: fileUrl);

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    // 🎯 NOTE: We need the full file size (total bytes) for accurate progress
    // calculation when resuming downloads. This size should ideally be passed
    // from the TransferNotifier/FileTransfer model.

    try {
      // 2. Delegate the network task to the ApiProvider
      await _apiProvider.downloadFile(
        fileUrl: fileUrl,
        savePath: savePath,
        // The ApiProvider should handle the actual progress calculation (count / total)
        // Note: For resumed downloads, total will often be the REMAINING size
        // if the server supports it, so the notifier must handle the final progress calculation.
        onReceiveProgress: (count, total) {
          if (total != -1) {
            // We pass Dio's progress directly to the controller
            controller.add(count / total);
          }
        },
        fileId: taskId, // 🚨 CORRECTION 3: Use the actual taskId
        startByte: startByte,
        cancelToken: cancelToken,
      );

      // Signal successful completion
      controller.add(1.0);

    } on DioException catch (e) {
      // Signal error
      if (!controller.isClosed) {
        controller.addError(e);
      }
    } finally {
      // Clean up resources
      await controller.close();
      _cancelTokens.remove(taskId);
    }
  }

  // --- Control & Persistence Hooks ---

  void cancelTransfer(String id) {
    final token = _cancelTokens[id];
    if (token != null && !token.isCancelled) {
      token.cancel('Transfer paused/cancelled by user or app.');
      _cancelTokens.remove(id);
    }
  }


  // 🎯 NEW: Expose method to retrieve saved bytes from persistence
  Future<int?> getSavedBytes(String id) {
    return _persistenceService.getLastSavedByteCount(id);
  }

  Future<void> cleanupTransferMetadata(String id) {
    // Delegate the task to the persistence service
    return _persistenceService.cleanupTransferMetadata(id);
  }
  Future<void> saveProgressBytes(String id, int byteCount) {
    // Delegates the actual persistence job to the Persistence Service
    return _persistenceService.saveCurrentByteCount(id, byteCount);
  }
  Future<void> saveDownloadableFileMetadata({
    required String fileId,
    required String fileName,
    required String fileUrl,
    required String size,
  }) async {
    // 🎯 Delegate to the persistence layer (which needs to be implemented/updated)
    await _persistenceService.saveDownloadableFileMetadata(
      fileId: fileId,
      fileName: fileName,
      fileUrl: fileUrl,
      size: size,
    );
  }
  Future<List<Map<String, dynamic>>> getDownloadableFilesMetadata() async {
    return _persistenceService.getDownloadableFiles();
  }


  // --- External Service Hooks ---

  /// Handles saving metadata and registering the WorkManager task sequentially.
  void _registerBackgroundAndPersistData(
      String taskId,
      bool isUpload,
      String path, // Path is source for upload, destination for download
          {required String fileName, String? fileUrl}
      ) {
    // 1. Persist the data first
    _persistenceService.saveTransferMetadata(
      id: taskId,
      filePath: path,
      fileName: fileName,
      isUpload: isUpload,
      fileUrl: fileUrl,
    ).then((_) {
      // 2. Register native task only after persistence is confirmed
      registerWorkManagerTask(
        taskId: taskId,
        isUpload: isUpload,
      );
    });
  }

  /// Triggers a persistent system notification using the dedicated service.
  void showCompletionNotification({
    required String taskId,
    required String fileName,
    required bool isUpload,
    required bool isSuccess,
  }) {
    _notificationService.showCompletionNotification(
      taskId: taskId,
      fileName: fileName,
      isUpload: isUpload,
      isSuccess: isSuccess,
    );
  }
}