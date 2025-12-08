import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage_app/models/transfer_model.dart';
import 'dart:math';

import '../../models/file_selection_result_model.dart';
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
    // 1. Get the actual file selector service
    final fileSelector = ref.read(fileSelectionServiceProvider); // Assuming this provider exists
    final result = await fileSelector.pickFile(); // Call the actual service

    // --- REMOVE THE TEMPORARY MOCK BLOCK COMPLETELY ---
    /*
    final result = FileSelectionResult(
      filePath: '/path/to/my/video.mp4',
      fileName: 'AwesomeVideo.mp4',
      byteSize: 150 * 1024 * 1024, // Mock 150 MB file
    );
    */

    if (result != null) {
      // **CRITICAL FIX: Copy the file to a permanent location**
      try {
        final originalPath = result.filePath;
        final originalFile = File(originalPath);

        // Use a permanent, app-accessible directory
        final appDocDir = await getApplicationDocumentsDirectory();

        // Create a unique file name to avoid collisions
        final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${result.fileName}';
        final permanentPath = '${appDocDir.path}/$uniqueFileName';

        // Copy the file. This reads from the picker's URI/cache and writes to a stable location.
        final permanentFile = await originalFile.copy(permanentPath);

        final String humanReadableSize = _formatBytes(result.byteSize);

        // Initiate upload using the permanent path
        notifier.startNewUpload(
          permanentFile.path, // <-- Pass the permanent path
          result.fileName,
          humanReadableSize,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Preparing upload for: ${result.fileName}')),
          );
        }
      } catch (e) {
        // Handle errors during file copy (e.g., permission issues, file read failure)
        print('Error during file preparation/copy: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to prepare file for upload: $e')),
          );
        }
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
        /*  SelectFileButton(
            text: 'Select File to Upload',
            icon: Icons.upload_file,
            onPressed: () => _startFileSelection(context, ref, notifier), // Pass ref here
          ),*/
        ],
      ),
    );
  }
}

// Simple extension for log base 1024 needed for size calculation
extension on double {
  double logBase(double base) => log(this) / log(base);
}