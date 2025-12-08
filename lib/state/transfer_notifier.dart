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
      filePath: filePath,
      fileUrl: null,
    );

    // 1. Add to state
    state = [...state, newTransfer];

    // 2. Start the service operation
    final progressStream = _service.startUpload(filePath, fileName, id, startByte: 0);

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
      filePath: savePath,
      fileUrl: fileUrl,  
    );

    state = [...state, newTransfer];

    final progressStream = _service.startDownload(fileUrl, savePath, fileName, id,startByte: 0);

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

      // 1. CRITICAL: Cancel the underlying network request via the service.
      _service.cancelTransfer(id);

      // 2. Cancel the stream listener, ensuring no further data is processed.
      transfer.subscription!.cancel();

      // 3. Update the state to paused, setting subscription to null.
      state = state.map((t) => t.id == id ? t.copyWith(status: TransferStatus.paused, subscription: null) : t).toList();
    }
  }

  void resumeTransfer(String id) async {
    final transfer = state.firstWhere((t) => t.id == id && t.status == TransferStatus.paused);

    // 1. Get the last known progress bytes from persistence.
    final lastSavedBytes = await _service.getSavedBytes(id);

    // 2. Determine transfer parameters using the saved data.
    final String source = transfer.isUpload ? transfer.filePath : transfer.fileUrl!;
    final String fileName = transfer.name;

    // 3. Update the status in the UI immediately.
    final newStatus = transfer.isUpload ? TransferStatus.uploading : TransferStatus.downloading;
    state = state.map((t) => t.id == id ? t.copyWith(status: newStatus) : t).toList();

    // 4. Start a NEW resumable transfer from lastSavedBytes.
    final Stream<double> progressStream;
    if (transfer.isUpload) {
      progressStream = _service.startUpload(
          source, // filePath
          fileName,
          id,
          startByte: lastSavedBytes! // Resume point
      );
    } else {
      progressStream = _service.startDownload(
          source, // fileUrl
          transfer.filePath, // savePath
          fileName,
          id,
          startByte: lastSavedBytes! // Resume point
      );
    }

    // 5. Set up the NEW listener.
    final subscription = progressStream.listen(
          (progress) => updateProgress(id, progress),
      onDone: () => markAsComplete(id),
      onError: (error) => markAsFailed(id),
    );

    // 6. Update the transfer object with the NEW subscription.
    state = state.map((t) => t.id == id ? t.copyWith(subscription: subscription) : t).toList();
  }

  // --- STATE UPDATES ---

  void updateProgress(String id, double progress) {
    print('Notifier: Updating progress for $id: ${progress.toStringAsFixed(4)}');
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