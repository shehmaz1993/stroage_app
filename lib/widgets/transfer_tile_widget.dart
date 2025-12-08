import 'package:flutter/material.dart';

import '../models/transfer_model.dart';
import '../state/transfer_notifier.dart';


/*class TransferTileWidget extends StatelessWidget {
  final FileTransfer transfer;
  final TransferNotifier notifier;
  final bool isActionable; // Determines if Pause/Resume buttons should appear

  const TransferTileWidget({
    required this.transfer,
    required this.notifier,
    this.isActionable = true, // Default to true for the main dashboard
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(transfer.status);
    final isDone = transfer.status.isDone;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Title and Status ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transfer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  transfer.status.name.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- Progress Bar (Only for active or paused states) ---
            if (transfer.status.isActive || transfer.status == TransferStatus.paused)
              LinearProgressIndicator(
                value: transfer.progress,
                color: statusColor,
                backgroundColor: Colors.grey[300],
              ),

            const SizedBox(height: 8),

            // --- Details and Actions ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(transfer.progress * 100).toStringAsFixed(1)}% complete - ${transfer.size}'),

                // Action Buttons (Only shown if isActionable is true)
                if (isActionable) _buildActionButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Utility method to determine action button ---
  Widget _buildActionButton() {
    if (transfer.status.isActive) {
      return IconButton(
        icon: const Icon(Icons.pause, color: Colors.blue),
        onPressed: () => notifier.pauseTransfer(transfer.id),
      );
    } else if (transfer.status == TransferStatus.paused) {
      return IconButton(
        icon: const Icon(Icons.play_arrow, color: Colors.green),
        onPressed: () => notifier.resumeTransfer(transfer.id),
      );
    } else if (transfer.status == TransferStatus.failed) {
      // Example: Add retry logic here
      return IconButton(
        icon: const Icon(Icons.refresh, color: Colors.red),
        onPressed: () => notifier.resumeTransfer(transfer.id), // Can use resume to trigger retry
      );
    }
    // Return an empty container for completed or non-actionable items
    return Container();
  }

  // --- Status Color Utility ---
  Color _getStatusColor(TransferStatus status) {
    switch (status) {
      case TransferStatus.pending:
        return Colors.grey;
      case TransferStatus.uploading:
      case TransferStatus.downloading:
        return Colors.blue;
      case TransferStatus.paused:
        return Colors.orange;
      case TransferStatus.complete:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
    }
  }
}*/