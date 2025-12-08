// 📁 transfer_status_ui_extensions.dart
import 'package:flutter/material.dart';

import '../models/transfer_model.dart';
// import '.../models/transfer_model.dart'; // Import the file containing TransferStatus

// Note: This extension MUST NOT contain 'isActive' or 'isDone'
// if they are already defined in your model file.
extension TransferStatusVisuals on TransferStatus {
  // You must use the existing 'isActive' property defined in your model file:
  // bool get isActive => this == TransferStatus.uploading || this == TransferStatus.downloading;

  Color get color {
    switch (this) {
      case TransferStatus.pending: return Colors.grey;
      case TransferStatus.uploading:
      case TransferStatus.downloading:
        return Colors.blue;
      case TransferStatus.paused: return Colors.orange;
      case TransferStatus.complete: return Colors.green;
      case TransferStatus.failed: return Colors.red;
    }
  }

  String get label {
    switch (this) {
      case TransferStatus.pending: return 'Pending';
      case TransferStatus.uploading: return 'Uploading';
      case TransferStatus.downloading: return 'Downloading';
      case TransferStatus.paused: return 'Paused';
      case TransferStatus.complete: return 'Complete';
      case TransferStatus.failed: return 'Failed';
    }
  }

  // Use isActive which is already defined in the model file
  bool get canControl {
    // 💡 IMPORTANT: Ensure you have access to the model file's extension property 'isActive'
    return this == TransferStatus.paused || this.isActive;
  }
}