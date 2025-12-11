import 'package:file_picker/file_picker.dart';

import '../models/file_selection_result_model.dart';

class FileSelectionService {

  bool _isPicking = false;

  Future<FileSelectionResult?> pickFile() async {

    if (_isPicking) {

      print("File picker already active, skipping new request.");
      return null;
    }


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

      _isPicking = false;
    }

    return result;
  }
}