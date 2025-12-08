import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Required for jsonEncode/jsonDecode

class TransferPersistenceService {

  // --- KEY DEFINITIONS ---

  // Prefix for saving individual transfer metadata (progress, path for ongoing jobs)
  static const String _transferPrefix = 'transfer_';

  // Key for saving the list of successfully uploaded files (for the Download Screen)
  static const String _downloadableFilesKey = 'downloadable_files_list';

  // --- NEW DOWNLOADABLE FILE MANAGEMENT ---

  /// Saves the metadata for a successfully uploaded file, making it available for download.
  Future<void> saveDownloadableFileMetadata({
    required String fileId,
    required String fileName,
    required String fileUrl,
    required String size,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Create the metadata map for the downloadable file
    final newFileMetadata = {
      'fileId': fileId,
      'fileName': fileName,
      'fileUrl': fileUrl, // The critical piece of data
      'size': size,
    };

    // 2. Retrieve the existing list of downloadable files
    final String? existingJson = prefs.getString(_downloadableFilesKey);
    List<Map<String, dynamic>> downloadableFiles = [];

    if (existingJson != null) {
      // Decode the existing list
      // Ensure safe casting from dynamic List to List<Map<String, dynamic>>
      downloadableFiles = (jsonDecode(existingJson) as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();

      // Prevent duplicates by removing an entry with the same ID if it exists
      downloadableFiles.removeWhere((file) => file['fileId'] == fileId);
    }

    // 3. Add the new metadata and re-save the list
    downloadableFiles.add(newFileMetadata);
    await prefs.setString(_downloadableFilesKey, jsonEncode(downloadableFiles));

    print('PersistenceService: Saved downloadable file metadata for $fileName (URL: $fileUrl)');
  }

  /// Retrieves the list of files available for download.
  Future<List<Map<String, dynamic>>> getDownloadableFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? existingJson = prefs.getString(_downloadableFilesKey);

    if (existingJson != null) {
      return (jsonDecode(existingJson) as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
    return [];
  }


  // --- EXISTING TRANSFER PROGRESS/METADATA METHODS ---

  Future<void> saveTransferMetadata({
    required String id,
    required String filePath,
    required String fileName,
    required bool isUpload,
    String? fileUrl,

  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('$_transferPrefix${id}_path', filePath);
    await prefs.setString('$_transferPrefix${id}_name', fileName);
    await prefs.setBool('$_transferPrefix${id}_isUpload', isUpload);

    if (fileUrl != null) {
      await prefs.setString('$_transferPrefix${id}_url', fileUrl);
    }
  }

  /// Retrieves the metadata needed by the isolated WorkManager task.
  Future<Map<String, dynamic>?> getTransferMetadata(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final filePath = prefs.getString('$_transferPrefix${id}_path');
    final fileName = prefs.getString('$_transferPrefix${id}_name');
    final isUpload = prefs.getBool('$_transferPrefix${id}_isUpload');
    final fileUrl = prefs.getString('$_transferPrefix${id}_url');

    if (filePath == null || isUpload == null) {
      return null;
    }

    return {
      'filePath': filePath,
      'fileName': fileName,
      'isUpload': isUpload,
      'fileUrl': fileUrl,
    };
  }

  Future<void> saveCurrentByteCount(String id, int byteCount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_transferPrefix${id}_progress', byteCount);
  }

  Future<int?> getLastSavedByteCount(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_transferPrefix${id}_progress');
  }

  /// Cleans up the metadata after a transfer is successfully completed.
  Future<void> cleanupTransferMetadata(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_transferPrefix${id}_path');
    await prefs.remove('$_transferPrefix${id}_name');
    await prefs.remove('$_transferPrefix${id}_isUpload');
    await prefs.remove('$_transferPrefix${id}_url');
    await prefs.remove('$_transferPrefix${id}_progress');

  }
}