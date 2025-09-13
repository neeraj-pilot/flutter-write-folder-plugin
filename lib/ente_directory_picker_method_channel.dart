import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ente_directory_picker_platform_interface.dart';

/// An implementation of [EnteDirectoryPickerPlatform] that uses method channels.
class MethodChannelEnteDirectoryPicker extends EnteDirectoryPickerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ente_directory_picker');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> selectDirectory() async {
    final result = await methodChannel.invokeMethod<String>('selectDirectory');
    return result;
  }

  @override
  Future<bool> hasPermission(String directoryPath) async {
    final result = await methodChannel.invokeMethod<bool>(
      'hasPermission',
      {'directoryPath': directoryPath},
    );
    return result ?? false;
  }

  @override
  Future<bool> requestPermission(String directoryPath) async {
    final result = await methodChannel.invokeMethod<bool>(
      'requestPermission',
      {'directoryPath': directoryPath},
    );
    return result ?? false;
  }

  @override
  Future<bool> writeFile(String directoryPath, String fileName, String content) async {
    final result = await methodChannel.invokeMethod<bool>(
      'writeFile',
      {
        'directoryPath': directoryPath,
        'fileName': fileName,
        'content': content,
      },
    );
    return result ?? false;
  }

  @override
  Future<List<String>?> listDirectory(String directoryPath, {bool recursive = false}) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'listDirectory',
      {
        'directoryPath': directoryPath,
        'recursive': recursive,
      },
    );
    return result?.cast<String>();
  }

  @override
  Future<String?> readFile(String filePath) async {
    final result = await methodChannel.invokeMethod<String>(
      'readFile',
      {'filePath': filePath},
    );
    return result;
  }

  @override
  Future<List<Map<String, dynamic>>?> getDirectoryDetails(String directoryPath, {bool recursive = false}) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'getDirectoryDetails',
      {
        'directoryPath': directoryPath,
        'recursive': recursive,
      },
    );
    return result?.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
