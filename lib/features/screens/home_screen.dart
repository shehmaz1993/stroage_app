import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage_app/models/transfer_model.dart';
import 'package:storage_app/utils/transfer_status_extension.dart';
import '../../providers/transfer_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transferNotifierProvider);


    final completedTransfers = transfers
        .where((t) => t.status == TransferStatus.complete)
        .toList();

    final failedTransfers = transfers
        .where((t) => t.status == TransferStatus.failed)
        .toList();


    final pausedTransfers = transfers
        .where((t) => t.status == TransferStatus.paused)
        .toList();


    final pendingUploads = transfers
        .where((t) => t.status == TransferStatus.pending && t.isUpload)
        .toList();


    final waitingTransfers = [...pendingUploads, ...pausedTransfers];


    final runningTransfers = transfers
        .where((t) => t.status.isActive && t.status != TransferStatus.pending)
        .toList();



    final runningUploads = runningTransfers.where((t) => t.isUpload).toList();
    final downloadedFiles = completedTransfers.where((t) => !t.isUpload).toList();
    final uploadedFiles = completedTransfers.where((t) => t.isUpload).toList();


    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview 📊',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildStorageGauge( context, usedGB: 8,totalGB: 20),
          const SizedBox(height: 20),

          // --- Transfer Activity Overview (LIVE DATA) ---
          const Text('Transfer Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          //const Divider(),

          // Active (Running) Uploads
          _buildTransferList(
            context,
            title: 'Active Uploads (${runningUploads.length})',
            icon: Icons.upload,
            color: Colors.blue,
            liveItems: runningUploads,
          ),
          const SizedBox(height: 10),

          // Paused/Pending Transfers (ALL WAITING FILES)
          _buildTransferList(
            context,
            title: 'Paused & Pending (${waitingTransfers.length})',
            icon: Icons.pause_circle_filled,
            color: Colors.orange,
            liveItems: waitingTransfers,
          ),
          const SizedBox(height: 10),

          // Completed Uploads
          _buildTransferList(
            context,
            title: 'Uploaded Files (${uploadedFiles.length})',
            icon: Icons.check_circle_outline,
            color: Colors.green,
            // Showing all completed files, reversed to show newest first
            liveItems: uploadedFiles.reversed.toList(),
          ),
          const SizedBox(height: 30),

          // Failed Transfers Banner
          if (failedTransfers.isNotEmpty)
            Card(
              color: Colors.red,
              child: ListTile(
                leading: const Icon(Icons.error, color: Colors.white),
                title: Text('${failedTransfers.length} Transfers Failed Recently', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Tap to review and resume.', style: TextStyle(color: Colors.white70)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // --- Helper Widget for Transfer Lists (UPDATED TO SHOW ALL ITEMS) ---
  Widget _buildTransferList(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required List<FileTransfer> liveItems,
        VoidCallback? onTap,
      }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              const Divider(height: 16),

              if (liveItems.isEmpty)
                Text('No ${title.split(" ").first} items.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600])),

              // Display ALL live items (NO .take(2) LIMIT)
              ...liveItems.map((transfer) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Name and Size Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                              transfer.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                          ),
                        ),
                        Text(
                          transfer.size,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 2. ID Row
                    Text(
                        'ID: ${transfer.id}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic)
                    ),
                    // Progress Bar for Active/Paused transfers
                    if (transfer.status.isActive || transfer.status == TransferStatus.paused)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: LinearProgressIndicator(
                          value: transfer.progress,
                          color: transfer.status.color,
                          backgroundColor: Colors.grey[200],
                          minHeight: 4,
                        ),
                      ),
                  ],
                ),
              )).toList(),

              // REMOVED: The conditional '+N more...' text is gone.
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildStorageGauge(BuildContext context, {required double usedGB, required double totalGB}) {
    final double percentage = usedGB / totalGB;
    final Color color = percentage > 0.8 ? Colors.red : percentage > 0.5 ? Colors.orange : Colors.blue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Local Device Storage', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${usedGB.toStringAsFixed(1)} GB / ${totalGB.toStringAsFixed(0)} GB', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: percentage, backgroundColor: Colors.grey[300], color: color, minHeight: 12),
            const SizedBox(height: 5),
            Text('${((1 - percentage) * totalGB).toStringAsFixed(1)} GB Available', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}