import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transfer_model.dart';
import '../services/transfer_service.dart';

class TransferNotifier extends StateNotifier<List<FileTransfer>> {
  final TransferService _service;

  TransferNotifier(this._service) : super([]);

  // --- START TRANSFER ---

  void startNewUpload(String filePath, String fileName, String fileSize) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final int totalBytes = _parseSizeStringToBytes(fileSize);
    final newTransfer = FileTransfer(
      id: id,
      name: fileName,
      size: fileSize,
      isUpload: true,
      status: TransferStatus.uploading,
      totalBytes: totalBytes,
    );

    // 1. Add to state
    state = [...state, newTransfer];

    // 2. Start the service operation
    final progressStream = _service.startUpload(filePath, fileName, id);

    // 3. Listen to the stream and update the state
    final subscription = progressStream.listen(
          (progress) => updateProgress(id, progress),
      onDone: () => markAsComplete(id),
      onError: (error) => markAsFailed(id),
    );

    // 4. Update the transfer object with its subscription (for pause/resume)
    state = state.map((t) => t.id == id ? t.copyWith(subscription: subscription) : t).toList();
  }

  void startNewDownload(String fileUrl, String fileName, String fileSize, String savePath) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final int totalBytes = _parseSizeStringToBytes(fileSize);

    final newTransfer = FileTransfer(
      id: id,
      name: fileName,
      size: fileSize,
      isUpload: false,
      status: TransferStatus.pending,
      totalBytes: totalBytes,
    );

    state = [...state, newTransfer];

    final progressStream = _service.startDownload(fileUrl, savePath, fileName, id);

    final subscription = progressStream.listen(
          (progress) => updateProgress(id, progress),
      onDone: () => markAsComplete(id),
      onError: (error) => markAsFailed(id),
    );

    state = state.map((t) => t.id == id ? t.copyWith(subscription: subscription) : t).toList();
  }

  // --- CONTROL ACTIONS ---

  void pauseTransfer(String id) {
    final transfer = state.firstWhere((t) => t.id == id && t.status.isActive);

    if (transfer.subscription != null) {
      transfer.subscription!.pause(); // Pause the stream listener
      // Note: Resumability logic (saving bytes) is handled in the background worker

      state = state.map((t) => t.id == id ? t.copyWith(status: TransferStatus.paused) : t).toList();
    }
  }

  void resumeTransfer(String id) {
    final transfer = state.firstWhere((t) => t.id == id && t.status == TransferStatus.paused);

    if (transfer.subscription != null) {
      transfer.subscription!.resume(); // Resume the stream listener

      final newStatus = transfer.isUpload ? TransferStatus.uploading : TransferStatus.downloading;
      state = state.map((t) => t.id == id ? t.copyWith(status: newStatus) : t).toList();
    }
  }

  // --- STATE UPDATES ---

  void updateProgress(String id, double progress) {
    state = state.map((t) {
      if (t.id == id) {
        TransferStatus newStatus = t.status;

        // 1. THE RESUMABILITY HOOK: Save the current byte count (uses the stored t.totalBytes)
        if (t.totalBytes > 0) {
          final int currentBytes = (progress * t.totalBytes).toInt();
          _service.saveProgressBytes(id, currentBytes);
        }

        // 2. Handle status transition (Pending -> Active)
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

    // 1. Cancel the subscription as the job is done
    transfer.subscription?.cancel();

    // 2. Cleanup persistence data
    _service.cleanupTransferMetadata(id);

    // 3. Notify user (WorkManager usually handles background notification, but we trigger the completion notification here too for in-app completion)
    _service.showCompletionNotification(
      taskId: id,
      fileName: transfer.name,
      isUpload: transfer.isUpload,
      isSuccess: true,
    );

    // 4. Update state
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

  int _parseSizeStringToBytes(String size) {
    final sizeParts = size.split(' ');
    final double sizeValue = double.tryParse(sizeParts[0]) ?? 0.0;
    final String unit = sizeParts.length > 1 ? sizeParts[1].toUpperCase() : 'MB';

    int totalBytes = 0;
    if (unit.startsWith('M')) {
      totalBytes = (sizeValue * 1024 * 1024).toInt(); // Megabytes to Bytes
    } else if (unit.startsWith('K')) {
      totalBytes = (sizeValue * 1024).toInt(); // Kilobytes to Bytes
    } else if (unit.startsWith('G')) {
      totalBytes = (sizeValue * 1024 * 1024 * 1024).toInt(); // Gigabytes to Bytes
    }
    return totalBytes;
  }
}