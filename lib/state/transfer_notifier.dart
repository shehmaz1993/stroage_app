import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../models/transfer_model.dart';
import '../services/transfer_service.dart';

class TransferNotifier extends StateNotifier<List<FileTransfer>> {
  final TransferService _service;

  TransferNotifier(this._service) : super([]);



  void startNewUpload(String filePath, String fileName, String fileSize) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final int totalBytes = _parseSizeStringToBytes(fileSize);

    final newTransfer = FileTransfer(
      id: id,
      name: fileName,
      size: fileSize,
      isUpload: true,
      status: TransferStatus.uploading,
      totalBytes: totalBytes,
      filePath: filePath,
      fileUrl: null,
    );

    state = [...state, newTransfer];

    try {
      final String downloadUrl = await _service.startUpload(
        filePath: filePath,
        fileName: fileName,
        taskId: id,
        startByte: 0,
        onProgressUpdate: (progress) {
          updateProgress(id, progress);
        },
      );

      print('Notifier: Upload completed! Download URL retrieved: $downloadUrl');

      await _service.saveDownloadableFileMetadata(
        fileId: id,
        fileName: fileName,
        fileUrl: downloadUrl,
        size: fileSize,
      );

      markAsComplete(id);

    } catch (error) {
      markAsFailed(id);
      print('Notifier: Upload failed or was cancelled: $error');
    }
  }



  void startNewDownload(String fileUrl, String fileName, String fileSize, String savePath) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final int totalBytes = _parseSizeStringToBytes(fileSize);



    final newTransfer = FileTransfer(
      id: id,
      name: fileName,
      size: fileSize,
      isUpload: false,
      status: TransferStatus.downloading,
      totalBytes: totalBytes,
      filePath: savePath,
      fileUrl: fileUrl, // Already set here
    );

    state = [...state, newTransfer];

    // 1. Start the service operation (returns a Stream<double>)
    final progressStream = _service.startDownload(
        fileUrl,
        savePath,
        fileName,
        id,
        startByte: 0
    );

    // 2. Listen to the stream and update the state
    final subscription = progressStream.listen(
          (progress) => updateProgress(id, progress),
      onDone: () => markAsComplete(id),
      onError: (error) => markAsFailed(id),
    );

    // 3. Update the transfer object with its subscription (for pause/resume)
    state = state.map((t) => t.id == id ? t.copyWith(subscription: subscription) : t).toList();
  }



  void pauseTransfer(String id) {

    final transfer = state.where((t) => t.id == id && t.status.isActive).firstOrNull;

    if (transfer == null) return; // Exit if transfer is not found or not active

    // Cancel the underlying network request via the service
    _service.cancelTransfer(id);

    if (transfer.isUpload) {
      // For uploads, we rely on the service to stop the Dio process and save progress
      _service.saveProgressBytes(id, _getCurrentBytes(transfer));
    } else if (transfer.subscription != null) {
      // For downloads, cancel the listener
      transfer.subscription!.cancel();
    }

    // Update the state to paused
    state = state.map((t) => t.id == id ? t.copyWith(status: TransferStatus.paused, subscription: null) : t).toList();
  }

  void resumeTransfer(String id) async {
    // Safe lookup is guaranteed since resume is only called on paused transfers
    final transfer = state.firstWhere((t) => t.id == id && t.status == TransferStatus.paused);

    final lastSavedBytes = await _service.getSavedBytes(id) ?? 0;

    if (lastSavedBytes >= transfer.totalBytes) {
      markAsComplete(id);
      return;
    }

    final String source = transfer.isUpload ? transfer.filePath : transfer.fileUrl!;
    final String fileName = transfer.name;

    final newStatus = transfer.isUpload ? TransferStatus.uploading : TransferStatus.downloading;
    state = state.map((t) => t.id == id ? t.copyWith(status: newStatus) : t).toList();

    if (transfer.isUpload) {
      // --- UPLOAD RESUME (Future/Callback) ---
      try {
        final String downloadUrl = await _service.startUpload(
          filePath: source,
          fileName: fileName,
          taskId: id,
          startByte: lastSavedBytes,
          onProgressUpdate: (progress) => updateProgress(id, progress),
        );

        await _service.saveDownloadableFileMetadata(
            fileId: id, fileName: fileName, fileUrl: downloadUrl, size: transfer.size);
        markAsComplete(id);
      } catch (error) {
        markAsFailed(id);
      }

    } else {
      // --- DOWNLOAD RESUME (Stream/Subscription) ---
      final progressStream = _service.startDownload(
          source,
          transfer.filePath,
          fileName,
          id,
          startByte: lastSavedBytes
      );

      final subscription = progressStream.listen(
            (progress) => updateProgress(id, progress),
        onDone: () => markAsComplete(id),
        onError: (error) => markAsFailed(id),
      );

      state = state.map((t) => t.id == id ? t.copyWith(subscription: subscription) : t).toList();
    }
  }



  void updateProgress(String id, double progress) {
    print('Notifier: Updating progress for $id: ${progress.toStringAsFixed(4)}');
    state = state.map((t) {
      if (t.id == id) {
        TransferStatus newStatus = t.status;

        if (t.totalBytes > 0) {
          final int currentBytes = _calculateCurrentBytes(t.totalBytes, progress);

          _service.saveProgressBytes(id, currentBytes);
        }

        // Status transition logic
        if (t.status == TransferStatus.pending && progress > 0) {
          newStatus = t.isUpload ? TransferStatus.uploading : TransferStatus.downloading;
        }

        return t.copyWith(
          progress: progress,
          status: newStatus,
        );
      }
      return t;
    }).toList();
  }

  void markAsComplete(String id) {
    final transfer = state.firstWhere((t) => t.id == id);

    transfer.subscription?.cancel();

    _service.cleanupTransferMetadata(id);

    _service.showCompletionNotification(
      taskId: id,
      fileName: transfer.name,
      isUpload: transfer.isUpload,
      isSuccess: true,
    );

    state = state.map((t) => t.id == id ? t.copyWith(status: TransferStatus.complete, progress: 1.0, subscription: null) : t).toList();
  }

  void markAsFailed(String id) {
    final transfer = state.firstWhere((t) => t.id == id);

    transfer.subscription?.cancel();

    _service.showCompletionNotification(
      taskId: id,
      fileName: transfer.name,
      isUpload: transfer.isUpload,
      isSuccess: false,
    );

    state = state.map((t) => t.id == id ? t.copyWith(status: TransferStatus.failed, subscription: null) : t).toList();
  }
  Future<List<Map<String, String>>> fetchDownloadableFiles() async {
    // Simulate a quick fetch/lookup time
    await Future.delayed(const Duration(milliseconds: 100));

    // 1. Filter the current list of transfers in the state.
    // We look for files that are complete AND were initiated as uploads (isUpload: true).
    final downloadableTransfers = state.where((t) =>
    t.status == TransferStatus.complete && t.isUpload
    ).toList();

    // 2. Map the filtered FileTransfer objects to the necessary metadata format.
    return downloadableTransfers.map((t) => {
      'fileName': t.name,
      // The FileUrl is the key piece of information needed to start a new download request
      'fileUrl': t.fileUrl!,
      'size': t.size,
      // totalBytes is optional here but useful if needed for new download status tracking
      'totalBytes': t.totalBytes.toString(),
    }).toList();
  }

  int _calculateCurrentBytes(int totalBytes, double progress) {
    return (progress * totalBytes).toInt().clamp(0, totalBytes);
  }

  int _getCurrentBytes(FileTransfer transfer) {
    return _calculateCurrentBytes(transfer.totalBytes, transfer.progress);
  }

  int _parseSizeStringToBytes(String size) {
    final sizeParts = size.split(' ');
    final double sizeValue = double.tryParse(sizeParts[0]) ?? 0.0;
    final String unit = sizeParts.length > 1 ? sizeParts[1].toUpperCase() : 'MB';

    int totalBytes = 0;
    if (unit.startsWith('M')) {
      totalBytes = (sizeValue * 1024 * 1024).toInt();
    } else if (unit.startsWith('K')) {
      totalBytes = (sizeValue * 1024).toInt();
    } else if (unit.startsWith('G')) {
      totalBytes = (sizeValue * 1024 * 1024 * 1024).toInt();
    }
    return totalBytes;
  }
}