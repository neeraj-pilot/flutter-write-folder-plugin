import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ente_directory_picker_method_channel.dart';

abstract class EnteDirectoryPickerPlatform extends PlatformInterface {
  /// Constructs a EnteDirectoryPickerPlatform.
  EnteDirectoryPickerPlatform() : super(token: _token);

  static final Object _token = Object();

  static EnteDirectoryPickerPlatform _instance = MethodChannelEnteDirectoryPicker();

  /// The default instance of [EnteDirectoryPickerPlatform] to use.
  ///
  /// Defaults to [MethodChannelEnteDirectoryPicker].
  static EnteDirectoryPickerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [EnteDirectoryPickerPlatform] when
  /// they register themselves.
  static set instance(EnteDirectoryPickerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Select a directory on the device
  /// Returns the directory path if successful, null if cancelled
  Future<String?> selectDirectory() {
    throw UnimplementedError('selectDirectory() has not been implemented.');
  }

  /// Check if we have permission to write to the selected directory
  /// Returns true if permission is granted, false otherwise
  Future<bool> hasPermission(String directoryPath) {
    throw UnimplementedError('hasPermission() has not been implemented.');
  }

  /// Request permission to write to a directory (Android specific)
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestPermission(String directoryPath) {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  /// Write content to a file in the specified directory
  /// Returns true if successful, false otherwise
  Future<bool> writeFile(String directoryPath, String fileName, String content) {
    throw UnimplementedError('writeFile() has not been implemented.');
  }

  /// List contents of a directory
  /// Returns a list of file and directory names, null if error
  Future<List<String>?> listDirectory(String directoryPath, {bool recursive = false}) {
    throw UnimplementedError('listDirectory() has not been implemented.');
  }

  /// Read content from a file
  /// Returns file content as string, null if error or file not found
  Future<String?> readFile(String filePath) {
    throw UnimplementedError('readFile() has not been implemented.');
  }

  /// Get detailed information about directory contents
  /// Returns a list of maps with file/directory details
  Future<List<Map<String, dynamic>>?> getDirectoryDetails(String directoryPath, {bool recursive = false}) {
    throw UnimplementedError('getDirectoryDetails() has not been implemented.');
  }
}
