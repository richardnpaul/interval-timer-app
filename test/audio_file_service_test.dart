import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/services/audio_file_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('audioFileServiceProvider provides an instance', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(audioFileServiceProvider);
    expect(service, isA<AudioFileService>());
  });

  late AudioFileService service;
  late MockPathProviderPlatform mockPathProvider;
  late FakeFilePicker mockFilePicker;

  setUp(() {
    service = AudioFileService();
    mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;

    mockFilePicker = FakeFilePicker();
    FilePicker.platform = mockFilePicker;
  });

  group('AudioFileService', () {
    group('getFileName', () {
      test('returns Default Beep for null path', () {
        expect(service.getFileName(null), 'Default Beep');
      });

      test('extracts basename for valid path', () {
        expect(service.getFileName('/path/to/sound.mp3'), 'sound.mp3');
      });
    });

    group('generateUniqueFileName', () {
      test('preserves extension', () {
        expect(service.generateUniqueFileName('test.mp3').endsWith('.mp3'), true);
      });
    });

    group('getSoundsDirectory', () {
      test('creates and returns sounds directory', () async {
        final dir = await service.getSoundsDirectory();
        expect(p.basename(dir.path), 'sounds');
        expect(await dir.exists(), true);
      });
    });

    group('pickAndSaveAudio', () {
      test('returns null if no file picked', () async {
        mockFilePicker.nextResult = null;
        final result = await service.pickAndSaveAudio();
        expect(result, isNull);
      });

      test('saves file and returns path on success', () async {
        final tempDir = Directory.systemTemp.createTempSync();
        final sourceFile = File(p.join(tempDir.path, 'source.mp3'))..createSync();

        mockFilePicker.nextResult = FilePickerResult([
          PlatformFile(
            name: 'source.mp3',
            path: sourceFile.path,
            size: 0,
          )
        ]);

        final result = await service.pickAndSaveAudio();
        expect(result, contains('/sounds/'));
        expect(result!.endsWith('.mp3'), true);

        tempDir.deleteSync(recursive: true);
      });
    });
  });
}

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final temp = Directory.systemTemp.createTempSync('docs');
    return temp.path;
  }
}

class FakeFilePicker extends FilePicker {
  FilePickerResult? nextResult;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return nextResult;
  }
}
