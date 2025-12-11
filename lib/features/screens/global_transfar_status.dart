import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage_app/models/transfer_model.dart';
import 'package:storage_app/utils/transfer_status_extension.dart';


import '../../providers/transfer_providers.dart';


class GlobalTransferStatus extends ConsumerWidget {
  const GlobalTransferStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final activeTransfers = ref.watch(transferNotifierProvider)
        .where((t) => t.status.isActive || t.status == TransferStatus.paused)
        .toList();

    if (activeTransfers.isEmpty) {

      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: Colors.lightBlue.shade50,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ongoing Transfers (${activeTransfers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const Divider(height: 10),
              // Display the first 2 active transfers (summary view)
              ...activeTransfers.take(2).map((t) {
                final isDownload = !t.isUpload;
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Icon(isDownload ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: t.status.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            LinearProgressIndicator(
                              value: t.progress,
                              color: t.status.color,
                              backgroundColor: Colors.grey.shade300,
                            ),
                          ],
                        ),
                      ),
                      Text('${(t.progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }),

              if (activeTransfers.length > 2)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('...scroll or check Download tab for full list.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}