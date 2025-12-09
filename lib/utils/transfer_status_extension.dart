// 📁 transfer_status_ui_extensions.dart
import 'package:flutter/material.dart';

import '../models/transfer_model.dart';

extension TransferStatusVisuals on TransferStatus {


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


  bool get canControl {

    return this == TransferStatus.paused || isActive;
  }
}