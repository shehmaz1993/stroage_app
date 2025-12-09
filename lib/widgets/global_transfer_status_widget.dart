// global_transfer_status.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage_app/models/transfer_model.dart';
import 'package:storage_app/widgets/transfer_tile_widget.dart';
import 'package:storage_app/widgets/transfer_widget.dart';


import '../providers/transfer_providers.dart';
// import '../providers/transfer_provider.dart';


class GlobalTransferStatus extends ConsumerWidget {
  const GlobalTransferStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =  ref.read(transferNotifierProvider.notifier);

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
        elevation: 4,
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
              // Use the common tile here for summary display
              ...activeTransfers.take(2).map((t) {
                return TransferTileWidget(
                  transfer: t,
                  isActionable: false
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