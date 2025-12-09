

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage_app/utils/transfer_status_extension.dart';

import '../models/transfer_model.dart';
import '../providers/transfer_providers.dart';
import '../state/transfer_notifier.dart';

class TransferTileWidget extends ConsumerWidget {
  final FileTransfer transfer;
  final bool isActionable;

  const TransferTileWidget({
    required this.transfer,
    this.isActionable = true,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Access the notifier methods here
    final notifier = ref.read(transferNotifierProvider.notifier);

    final statusColor = transfer.status.color; // Using the extension

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
                  transfer.status.label.toUpperCase(), // Using the extension
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),


            if (transfer.status.isActive || transfer.status == TransferStatus.paused)
              LinearProgressIndicator(
                value: transfer.progress,
                color: statusColor,
                backgroundColor: Colors.grey[300],
              ),

            const SizedBox(height: 8),


            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(transfer.progress * 100).toStringAsFixed(1)}% complete - ${transfer.size}'),

                // Action Buttons
                if (isActionable && transfer.status.canControl) _buildActionButton(notifier),
                if (transfer.status == TransferStatus.failed && isActionable) _buildRetryButton(notifier),
                if (transfer.status == TransferStatus.complete && isActionable)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(TransferNotifier notifier) {
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
    }
    return Container();
  }

  Widget _buildRetryButton(TransferNotifier notifier) {
    return IconButton(
      icon: const Icon(Icons.refresh, color: Colors.red),
      onPressed: () => notifier.resumeTransfer(transfer.id),
    );
  }
}