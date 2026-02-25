import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioFileServiceProvider = Provider((ref) => AudioFileService());

class AudioFileService {
  /// Opens a file picker and copies the selected file to internal storage.
  /// Returns the absolute path of the saved file or null if cancelled.
  Future<String?> pickAndSaveAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return null;

    final targetPath = await _saveToInternalStorage(
      File(pickedFile.path!),
      pickedFile.name,
    );
    return targetPath;
  }

  Future<String> _saveToInternalStorage(File sourceFile, String name) async {
    final soundsDir = await _getSoundsDirectory();
    final fileName = _generateUniqueFileName(name);
    final targetPath = p.join(soundsDir.path, fileName);

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  Future<Directory> _getSoundsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory(p.join(appDir.path, 'sounds'));
    if (!await soundsDir.exists()) {
      await soundsDir.create(recursive: true);
    }
    return soundsDir;
  }

  String _generateUniqueFileName(String originalName) {
    final ext = p.extension(originalName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$timestamp$ext';
  }

  /// Extracts the filename from a full path for UI display.
  String getFileName(String? path) {
    if (path == null) return 'Default Beep';
    return p.basename(path);
  }
}
