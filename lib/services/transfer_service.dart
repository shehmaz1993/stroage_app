import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:storage_app/services/transfer_persistance_service.dart';


import '../exceptions/network_exception.dart';
import '../exceptions/transfer_exceptions.dart';
import 'api_services.dart';
import 'background_manager.dart';
import 'local_notification_service.dart';


class TransferService {
  final ApiProvider _apiProvider;
  final NotificationService _notificationService;
  final TransferPersistenceService _persistenceService;
  // Map to store Dio CancelToken instances by taskId for cancellation
  final Map<String, CancelToken> _cancelTokens = {};

  // Constructor receives all dependencies via Riverpod
  TransferService(
      this._apiProvider,
      this._notificationService,
      this._persistenceService
      );



  /// Initiates the file upload process, starting from a specific byte offset.
  Future<String> startUpload({
    required String filePath,
    required String fileName,
    required String taskId,
    required int startByte,
    required Function(double progress) onProgressUpdate,
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


        onSendProgress: (count, total) {
          double totalBytesSent = (count + startByte).toDouble();
          double progress = totalBytesSent / fileLength;
          double finalProgress = progress.clamp(0.0, 1.0);
          onProgressUpdate(finalProgress); // Pass calculated progress to the Notifier
        },
      );
      return downloadUrl; // Return the URL to the Notifier
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel){

        throw TransferCancelledException('Upload was paused by user.');
      }
      String failureMessage = _getFailureMessage(e);

      throw NetworkFailureException(
          message: failureMessage,
          originalError: e
      );
    } catch (e) {
      // Catch non-Dio errors (like file system errors)
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

    try {
      // 2. Delegate the network task to the ApiProvider
      await _apiProvider.downloadFile(
        fileUrl: fileUrl,
        savePath: savePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {

            controller.add(count / total);
          }
        },
        fileId: taskId,
        startByte: startByte,
        cancelToken: cancelToken,
      );

      // Signal successful completion
      controller.add(1.0);

    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        print('Service: Download was cancelled/paused.');
      } else if (!controller.isClosed) {

        String failureMessage = _getFailureMessage(e);
        controller.addError(NetworkFailureException(
            message: failureMessage,
            originalError: e
        ));
      }
    } catch (e) {
      // Handle other non-Dio exceptions
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
      // 🚨 When this is called, it triggers the DioExceptionType.cancel in startUpload/Download
      token.cancel('Transfer paused/cancelled by user or app.');
      _cancelTokens.remove(id);
    }
  }


  Future<int?> getSavedBytes(String id) {
    return _persistenceService.getLastSavedByteCount(id);
  }

  Future<void> cleanupTransferMetadata(String id) {
    return _persistenceService.cleanupTransferMetadata(id);
  }
  Future<void> saveProgressBytes(String id, int byteCount) {
    return _persistenceService.saveCurrentByteCount(id, byteCount);
  }
  Future<void> saveDownloadableFileMetadata({
    required String fileId,
    required String fileName,
    required String fileUrl,
    required String size,
  }) async {
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
  String _getFailureMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Connection timed out. Please check your network.";
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 404) {
          return "File not found on the server (Error 404).";
        } else if (statusCode != null && statusCode >= 500) {
          return "Server error occurred (Error $statusCode). Try again later.";
        }
        return "Received an invalid server response.";
      case DioExceptionType.unknown:
      case DioExceptionType.connectionError:
        return "No internet connection or network failure detected.";
      case DioExceptionType.badCertificate:
        return "Security certificate error.";
      default:
        return "An unknown network error occurred.";
    }
  }


  // --- External Service Hooks ---

  void _registerBackgroundAndPersistData(
      String taskId,
      bool isUpload,
      String path,
      {required String fileName, String? fileUrl}
      ) {
    _persistenceService.saveTransferMetadata(
      id: taskId,
      filePath: path,
      fileName: fileName,
      isUpload: isUpload,
      fileUrl: fileUrl,
    ).then((_) {
      registerWorkManagerTask(
        taskId: taskId,
        isUpload: isUpload,
      );
    });
  }

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