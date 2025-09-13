
import 'ente_directory_picker_platform_interface.dart';

class EnteDirectoryPicker {
  Future<String?> getPlatformVersion() {
    return EnteDirectoryPickerPlatform.instance.getPlatformVersion();
  }

  /// Select a directory on the device
  /// Returns the directory path if successful, null if cancelled or error
  Future<String?> selectDirectory() {
    return EnteDirectoryPickerPlatform.instance.selectDirectory();
  }

  /// Check if we have permission to write to the selected directory
  /// Returns true if permission is granted, false otherwise
  Future<bool> hasPermission(String directoryPath) {
    return EnteDirectoryPickerPlatform.instance.hasPermission(directoryPath);
  }

  /// Request permission to write to a directory (Android specific)
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestPermission(String directoryPath) {
    return EnteDirectoryPickerPlatform.instance.requestPermission(directoryPath);
  }

  /// Write content to a file in the specified directory
  /// Returns true if successful, false otherwise
  Future<bool> writeFile(String directoryPath, String fileName, String content) {
    return EnteDirectoryPickerPlatform.instance.writeFile(directoryPath, fileName, content);
  }

  /// Generate a timestamp-based filename
  /// Returns filename in format: YYYY-MM-DD_HH-mm-ss.txt
  String generateTimestampFilename([String extension = 'txt']) {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    return '$timestamp.$extension';
  }

  /// Convenience method to write a timestamped file with current time as content
  /// Returns true if successful, false otherwise
  Future<bool> writeTimestampFile(String directoryPath) async {
    final now = DateTime.now();
    final fileName = generateTimestampFilename();
    final content = now.toString();
    return await writeFile(directoryPath, fileName, content);
  }

  /// List contents of a directory
  /// Returns a list of file and directory names
  /// Set recursive to true to include subdirectory contents
  Future<List<String>?> listDirectory(String directoryPath, {bool recursive = false}) {
    return EnteDirectoryPickerPlatform.instance.listDirectory(directoryPath, recursive: recursive);
  }

  /// Read content from a file
  /// Returns file content as string, null if error or file not found
  Future<String?> readFile(String filePath) {
    return EnteDirectoryPickerPlatform.instance.readFile(filePath);
  }

  /// Get detailed information about directory contents including file sizes, types, etc.
  /// Returns a list of maps with file/directory details:
  /// - 'name': file/directory name
  /// - 'path': full path
  /// - 'isDirectory': true if it's a directory
  /// - 'size': file size in bytes (directories have size 0)
  /// - 'lastModified': last modification timestamp
  Future<List<Map<String, dynamic>>?> getDirectoryDetails(String directoryPath, {bool recursive = false}) {
    return EnteDirectoryPickerPlatform.instance.getDirectoryDetails(directoryPath, recursive: recursive);
  }

  /// Convenience method to explore a directory and get a tree-like structure
  /// Returns a nested map representing the directory tree
  Future<Map<String, dynamic>?> getDirectoryTree(String directoryPath) async {
    final details = await getDirectoryDetails(directoryPath, recursive: true);
    if (details == null) return null;

    final tree = <String, dynamic>{};
    
    for (final item in details) {
      final path = item['path'] as String;
      final relativePath = path.replaceFirst(directoryPath, '').replaceFirst(RegExp(r'^[/\\]'), '');
      final pathParts = relativePath.split(RegExp(r'[/\\]'));
      
      Map<String, dynamic> current = tree;
      for (int i = 0; i < pathParts.length; i++) {
        final part = pathParts[i];
        if (part.isEmpty) continue;
        
        if (i == pathParts.length - 1) {
          // Leaf node (file or empty directory)
          current[part] = item;
        } else {
          // Directory node
          current[part] ??= <String, dynamic>{};
          current = current[part] as Map<String, dynamic>;
        }
      }
    }
    
    return tree;
  }
}
