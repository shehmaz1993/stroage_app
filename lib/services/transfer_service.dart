import 'dart:async';
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
  Stream<double> startUpload(
      String filePath,
      String fileName,
      String taskId,
      {required int startByte} // 🎯 NEW: Added startByte
      ) {
    _registerBackgroundAndPersistData(taskId, true, filePath, fileName: fileName);

    // 🎯 NEW: Create a new CancelToken and map it to the taskId
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    // The stream logic is now simpler, as the ApiProvider handles the stream controller setup.
    // We rely on ApiProvider to handle the startByte logic for the resumable upload.
    return _apiProvider.uploadFile(
      filePath: filePath,
      fileName: fileName,
      startByte: startByte, // 🎯 Pass the resume point
      cancelToken: cancelToken, // 🎯 Pass the token for cancellation
    );
  }

  // --- Core Download Logic ---

  /// Initiates the file download process, starting from a specific byte offset.
  Stream<double> startDownload(
      String fileUrl,
      String savePath,
      String fileName,
      String taskId,
      {required int startByte} // 🎯 NEW: Added startByte
      ) async* {
    // 1. Hook for background persistence (Saves necessary data)
    _registerBackgroundAndPersistData(taskId, false, savePath, fileName: fileName, fileUrl: fileUrl);

    // 🎯 NEW: Create a new CancelToken and map it to the taskId
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    final controller = StreamController<double>();

    // We use the startByte passed in the function signature for resumption logic
    // The ApiProvider will use this value to set the Range header.

    try {
      // 2. Delegate the network task to the ApiProvider
      await _apiProvider.downloadFile(
        fileUrl: fileUrl,
        savePath: savePath,
        // The ApiProvider should handle the actual progress calculation (count / total)
        // to simplify the service layer.
        onReceiveProgress: (count, total) {
          if (total != -1) {
            // Note: This needs to be carefully implemented in ApiProvider
            // to account for the startByte offset.
            controller.add(count / total);
          }
        },
        fileId: '',
        startByte: startByte, // 🎯 Pass the resume point
        cancelToken: cancelToken, // 🎯 Pass the token for cancellation
      );
      controller.add(1.0);
    } on DioException catch (e) {
      controller.addError(e);
    } finally {
      await controller.close();
      _cancelTokens.remove(taskId); // Clean up token regardless of outcome
    }
    yield* controller.stream;
  }

  // 🎯 NEW: Method to cancel the running Dio request
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