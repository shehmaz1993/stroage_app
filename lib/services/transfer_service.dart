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

  // Constructor receives all dependencies via Riverpod
  TransferService(
      this._apiProvider,
      this._notificationService,
      this._persistenceService
      );

  // --- Core Upload Logic ---

  /// Initiates the file upload process.
  Stream<double> startUpload(String filePath, String fileName, String taskId) {
    // 1. Hook for background persistence (Saves necessary data)
    _registerBackgroundAndPersistData(taskId, true, filePath, fileName: fileName);

    // 2. Delegate the actual network task to the ApiProvider
    return _apiProvider.uploadFile(
      filePath: filePath,
      fileName: fileName,
    );
  }

  // --- Core Download Logic ---

  /// Initiates the file download process.
  Stream<double> startDownload(String fileUrl, String savePath, String fileName, String taskId) async* {
    // 1. Hook for background persistence (Saves necessary data)
    _registerBackgroundAndPersistData(taskId, false, savePath, fileName: fileName, fileUrl: fileUrl);

    final controller = StreamController<double>();
    final lastProgressBytes = await _persistenceService.getLastSavedByteCount(taskId);
    final startByte = lastProgressBytes ?? 0;

    try {
      // 2. Delegate the network task to the ApiProvider
      await _apiProvider.downloadFile(
        fileUrl: fileUrl,
        savePath: savePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            controller.add(count / total);
          }
        }, fileId: '',startByte: startByte,
      );
      controller.add(1.0);
    } on DioException catch (e) {
      controller.addError(e);
    } finally {
      await controller.close();
    }
    yield* controller.stream;
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