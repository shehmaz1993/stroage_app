import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:storage_app/models/transfer_model.dart';
import 'dart:math';

import '../../providers/transfer_providers.dart';
import '../../state/transfer_notifier.dart';
import '../../widgets/select_file_button.dart';
import '../../widgets/transfer_tile_widget.dart';



class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  // Helper to convert bytes to human-readable format (MB/GB)
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes > 0) ? (bytes.toDouble().logBase(1024)).floor() : 0;
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  // --- File Selection and Initiation Orchestration ---
  void _startFileSelection(BuildContext context, WidgetRef ref, TransferNotifier notifier) async {
    // 1. Read the dedicated FileSelectionService
    final fileSelector = ref.read(fileSelectionServiceProvider);

    // 2. Call the service to open the picker and get results
    final result = await fileSelector.pickFile();

    if (result != null) {
      // 3. Prepare data for the Notifier
      final String humanReadableSize = _formatBytes(result.byteSize);

      // 4. Initiate the upload using the Notifier
      // The Notifier now receives the clean, raw data it needs to start the process.
      notifier.startNewUpload(
        result.filePath,
        result.fileName,
        humanReadableSize,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preparing upload for: ${result.fileName}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transferNotifierProvider);
    final notifier = ref.read(transferNotifierProvider.notifier);

    // Filter to show only active/pending uploads for this screen
    final activeUploads = transfers
        .where((t) => t.isUpload && !t.status.isDone)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload File'),
      ),
      body: Column(
        children: [
          // 1. Main scrollable content area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Select a file from your device to begin the upload process.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // Primary Action Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _startFileSelection(context, ref, notifier), // Pass ref here
                    icon: const Icon(Icons.add_to_photos),
                    label: const Text('Select File to Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // --- Active Uploads List ---
                if (activeUploads.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Uploads',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Divider(),
                      ...activeUploads.map((transfer) => TransferTileWidget(
                        transfer: transfer,
                        notifier: notifier,
                        isActionable: true,
                      )),
                    ],
                  ),
              ],
            ),
          ),

          // 2. Persistent Bottom Button Area (Reusable Widget)
          SelectFileButton(
            text: 'Select File to Upload',
            icon: Icons.upload_file,
            onPressed: () => _startFileSelection(context, ref, notifier), // Pass ref here
          ),
        ],
      ),
    );
  }
}

// Simple extension for log base 1024 needed for size calculation
extension on double {
  double logBase(double base) => log(this) / log(base);
}