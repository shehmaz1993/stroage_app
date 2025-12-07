import 'package:file_picker/file_picker.dart';

import '../models/file_selection_result_model.dart';

class FileSelectionService {
  // 1. Add a private lock variable
  bool _isPicking = false;

  Future<FileSelectionResult?> pickFile() async {
    // 2. Check the lock: If already picking, abort silently (or throw an error)
    if (_isPicking) {
      // You can return null or print a message to prevent multiple dialogs
      print("File picker already active, skipping new request.");
      return null;
    }

    // 3. Set the lock before attempting to open the dialog
    _isPicking = true;
    FileSelectionResult? result;

    try {
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (pickerResult != null) {
        final platformFile = pickerResult.files.first;
        result = FileSelectionResult(
          filePath: platformFile.path!,
          fileName: platformFile.name,
          byteSize: platformFile.size,
        );
      }
    } catch (e) {
      // Handle any specific file picker errors here if needed
      print("Error during file picking: $e");
    } finally {
      // 4. IMPORTANT: Reset the lock when the async operation completes,
      // whether it succeeded, failed, or was canceled.
      _isPicking = false;
    }

    return result;
  }
}