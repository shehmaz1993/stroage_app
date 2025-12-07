import 'package:shared_preferences/shared_preferences.dart';

class TransferPersistenceService {

  static const String _transferPrefix = 'transfer_';


  Future<void> saveTransferMetadata({
    required String id,
    required String filePath,
    required String fileName,
    required bool isUpload,
    String? fileUrl,

  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Save the core details
    await prefs.setString('$_transferPrefix${id}_path', filePath);
    await prefs.setString('$_transferPrefix${id}_name', fileName);
    await prefs.setBool('$_transferPrefix${id}_isUpload', isUpload);

    // Save optional URL for downloads
    if (fileUrl != null) {
      await prefs.setString('$_transferPrefix${id}_url', fileUrl);
    }
  }

  /// 2. Retrieves the metadata needed by the isolated WorkManager task.
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

  /// 3. Cleans up the metadata after a transfer is successfully completed.
  Future<void> cleanupTransferMetadata(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_transferPrefix${id}_path');
    await prefs.remove('$_transferPrefix${id}_name');
    await prefs.remove('$_transferPrefix${id}_isUpload');
    await prefs.remove('$_transferPrefix${id}_url');
    await prefs.remove('$_transferPrefix${id}_progress');

  }
}