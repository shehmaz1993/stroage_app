import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../models/transfer_model.dart';
import '../../providers/transfer_providers.dart';
import '../../widgets/transfer_widget.dart';

// Assuming imports for your core components:
// import '../providers/transfer_providers.dart'; // Contains transferNotifierProvider
// import '../models/transfer_model.dart'; // Contains FileTransfer and TransferStatus
// import '../widgets/transfer_tile_widget.dart'; // The common tile for active transfers
// import '../extensions/transfer_status_ui_extensions.dart'; // For .isActive, .color, etc.


// --- Helper Function ---
/// Helper to generate a safe file path in the app's document directory.
Future<String> _getDownloadPath(String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  return '${directory.path}/$fileName';
}


// --- Download Initiation Button (Specific to this screen) ---
class DownloadInitiationButton extends ConsumerWidget {
  final FileTransfer? existingTransfer;
  final Map<String, dynamic> fileMetadata;

  const DownloadInitiationButton({
    super.key,
    required this.existingTransfer,
    required this.fileMetadata,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(transferNotifierProvider.notifier);
    final fileName = fileMetadata['fileName']!;
    final fileUrl = fileMetadata['fileUrl']!;
    final fileSize = fileMetadata['size']!;

    // Logic for Pause, Resume, Downloaded status
    if (existingTransfer != null) {
      if (existingTransfer!.status.isActive) {
        return ElevatedButton(onPressed: () => notifier.pauseTransfer(existingTransfer!.id), child: const Text('Pause'));
      } else if (existingTransfer!.status == TransferStatus.paused || existingTransfer!.status == TransferStatus.failed) {
        return ElevatedButton(onPressed: () => notifier.resumeTransfer(existingTransfer!.id), child: const Text('Resume'));
      } else if (existingTransfer!.status == TransferStatus.complete && !existingTransfer!.isUpload) {
        // Check if the downloaded file still exists on device
        if (File(existingTransfer!.filePath).existsSync()) {
          return const Text('Downloaded!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
        }
        return const Text('Complete', style: TextStyle(color: Colors.green));
      }
    }

    // Default Download Button
    return ElevatedButton.icon(
      icon: const Icon(Icons.cloud_download, size: 18),
      label: const Text('Download'),
      onPressed: () async {
        final savePath = await _getDownloadPath(fileName);
        notifier.startNewDownload(fileUrl, fileName, fileSize, savePath);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Starting download for $fileName')));
      },
    );
  }
}


// --- Main Download Screen Widget ---

class DownloadScreen extends ConsumerWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all transfers for real-time updates
    final transfers = ref.watch(transferNotifierProvider);

    // Fetch files available for download (Source List)
    final futureDownloadableFiles = ref.watch(
      // The FutureProvider handles fetching the data once (Mock or API call)
        FutureProvider((ref) => ref.read(transferNotifierProvider.notifier).fetchDownloadableFiles())
    );

    // Filter transfers for organization
    final activeTransfers = transfers.where((t) => t.status.isActive || t.status == TransferStatus.paused).toList();
    final completedTransfers = transfers.where((t) => t.status == TransferStatus.complete).toList();

    return Column(
      children: [
        // --- Section 1: Files Available to Download (Source List) ---
        Padding(
          padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
          child: Text('Files Available to Download', style: Theme.of(context).textTheme.titleLarge),
        ),
        const Divider(),

        Expanded(
          flex: 3, // Gives more space to the download source list
          child: futureDownloadableFiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading files: $err')),
            data: (downloadableFiles) {
              if (downloadableFiles.isEmpty) {
                return const Center(child: Text('No files available for download.'));
              }
              return ListView.builder(
                itemCount: downloadableFiles.length,
                itemBuilder: (context, index) {
                  final file = downloadableFiles[index];
                  // Check if this file is already active in the transfer list by URL
                  final existingTransfer = transfers.where((t) => t.fileUrl == file['fileUrl']).firstOrNull;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: ListTile(
                      title: Text(file['fileName']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Size: ${file['size']}'),
                      trailing: DownloadInitiationButton(
                        existingTransfer: existingTransfer,
                        fileMetadata: file,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const Divider(thickness: 4.0),

        // --- Section 2: Active Transfers (Full Progress List & Control) ---
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Active / Paused Transfers (${activeTransfers.length})', style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          flex: 2, // Gives less space than the source list
          child: activeTransfers.isEmpty
              ? const Center(child: Text('No active transfers.'))
              : ListView.builder(
            itemCount: activeTransfers.length,
            itemBuilder: (context, index) {
              final transfer = activeTransfers[index];
              // Using the common TransferTileWidget for detailed display and control
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TransferTileWidget(transfer: transfer, isActionable: true),
              );
            },
          ),
        ),

        // --- Section 3: Completed Transfer Count ---
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Completed: ${completedTransfers.length}', style: Theme.of(context).textTheme.titleSmall),
        ),
      ],
    );
  }
}