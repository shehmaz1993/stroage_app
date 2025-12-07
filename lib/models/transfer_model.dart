import 'dart:async';

enum TransferStatus { pending, uploading, downloading,paused, complete, failed }
extension TransferStatusExtension on TransferStatus {
  bool get isActive => this == TransferStatus.uploading || this == TransferStatus.downloading;
  bool get isDone => this == TransferStatus.complete || this == TransferStatus.failed;
}

class FileTransfer {
  final String id;
  final String name;
  final String size;
  final int totalBytes;
  double progress;
  TransferStatus status;
  final bool isUpload;

  StreamSubscription<double>? subscription;

  FileTransfer({
    required this.id,
    required this.name,
    required this.size,
    required this.totalBytes,
    this.progress = 0.0,
    this.status = TransferStatus.pending,
    required this.isUpload,
    this.subscription,
  });

  // Method used by the StateNotifier to update the object immutably
  FileTransfer copyWith({
    double? progress,
    TransferStatus? status,
    StreamSubscription<double>? subscription,
  }) {
    return FileTransfer(
      id: id,
      name: name,
      size: size,
      totalBytes: totalBytes,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      isUpload: isUpload,
      subscription: subscription ?? this.subscription,
    );
  }
}