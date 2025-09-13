# Ente Directory Picker

A Flutter plugin that allows users to select directories and write files across all platforms (Android, iOS, Windows, macOS, Linux) with native platform-specific implementations.

## Features

- **Cross-platform directory selection**: Native file dialogs on all platforms
- **Platform-specific implementations**:
  - **Android**: Uses SAF (Storage Access Framework) for scoped storage compliance
  - **iOS**: Uses UIDocumentPickerViewController for secure directory access
  - **Windows**: Native Windows file dialog with COM interfaces
  - **macOS**: NSOpenPanel for native macOS experience
  - **Linux**: GTK file chooser with xdg-desktop-portal support
- **Permission handling**: Platform-appropriate permission management
- **File writing**: Write files to user-selected directories
- **File reading**: Read file contents from selected directories
- **Directory exploration**: List and explore directory contents recursively
- **Timestamp utilities**: Built-in timestamp filename generation

## Platform Support

| Platform | Status | Implementation |
|----------|--------|----------------|
| Android  | ✅     | SAF (Storage Access Framework) |
| iOS      | ✅     | UIDocumentPickerViewController |
| Windows  | ✅     | Win32 File Dialog API |
| macOS    | ✅     | NSOpenPanel |
| Linux    | ✅     | GTK File Chooser |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ente_directory_picker: ^0.0.1
```

## Usage

### Basic Example

```dart
import 'package:ente_directory_picker/ente_directory_picker.dart';

final plugin = EnteDirectoryPicker();

// Select a directory
final directoryPath = await plugin.selectDirectory();
if (directoryPath != null) {
  print('Selected directory: $directoryPath');
  
  // Check permissions
  final hasPermission = await plugin.hasPermission(directoryPath);
  if (hasPermission) {
    // Write a file
    final success = await plugin.writeFile(
      directoryPath,
      'my_file.txt',
      'Hello, World!'
    );
    
    if (success) {
      print('File written successfully!');
    }
  }
}
```

### Timestamp File Writing

```dart
// Generate a timestamp-based filename
final filename = plugin.generateTimestampFilename(); // 2024-12-12_14-30-45.txt

// Write a file with current timestamp as content
final success = await plugin.writeTimestampFile(directoryPath);
```

### File Reading and Directory Exploration

```dart
// List directory contents
final files = await plugin.listDirectory(directoryPath);
print('Found ${files?.length} items');

// Get detailed directory information
final details = await plugin.getDirectoryDetails(directoryPath, recursive: true);
for (final item in details ?? []) {
  print('${item['name']}: ${item['isDirectory'] ? 'Directory' : '${item['size']} bytes'}');
}

// Read a specific file
final content = await plugin.readFile('/path/to/file.txt');
if (content != null) {
  print('File content: $content');
}

// Get directory tree structure
final tree = await plugin.getDirectoryTree(directoryPath);
print('Directory structure: $tree');
```

### App Lifecycle Integration

For apps that need to write files when coming from dead state or periodically:

```dart
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _periodicTimer;
  String? _selectedDirectory;
  final _plugin = EnteDirectoryPicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Write file when app comes to foreground from dead/paused state
    if (state == AppLifecycleState.resumed && _selectedDirectory != null) {
      _plugin.writeTimestampFile(_selectedDirectory!);
    }
  }

  void startPeriodicWriting() {
    _periodicTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (_selectedDirectory != null) {
        _plugin.writeTimestampFile(_selectedDirectory!);
      }
    });
  }
}
```

## API Reference

### Methods

#### `selectDirectory() → Future<String?>`
Opens a platform-specific directory picker dialog.
- **Returns**: Directory path if selected, `null` if cancelled
- **Platforms**: All supported platforms

#### `hasPermission(String directoryPath) → Future<bool>`
Checks if the app has write permission for the specified directory.
- **Parameters**: `directoryPath` - Path to check
- **Returns**: `true` if write permission is available

#### `requestPermission(String directoryPath) → Future<bool>`
Requests write permission for the specified directory (mainly for Android).
- **Parameters**: `directoryPath` - Path to request permission for
- **Returns**: `true` if permission granted

#### `writeFile(String directoryPath, String fileName, String content) → Future<bool>`
Writes content to a file in the specified directory.
- **Parameters**: 
  - `directoryPath` - Target directory path
  - `fileName` - Name of the file to create
  - `content` - File content to write
- **Returns**: `true` if file was written successfully

#### `generateTimestampFilename([String extension = 'txt']) → String`
Generates a timestamp-based filename.
- **Parameters**: `extension` - File extension (default: 'txt')
- **Returns**: Filename in format: `YYYY-MM-DD_HH-mm-ss.ext`

#### `writeTimestampFile(String directoryPath) → Future<bool>`
Convenience method to write a file with timestamp name and current time as content.
- **Parameters**: `directoryPath` - Target directory path
- **Returns**: `true` if file was written successfully

#### `listDirectory(String directoryPath, {bool recursive = false}) → Future<List<String>?>`
Lists the contents of a directory.
- **Parameters**: 
  - `directoryPath` - Directory to explore
  - `recursive` - Whether to include subdirectory contents (default: false)
- **Returns**: List of file and directory names, null if error

#### `readFile(String filePath) → Future<String?>`
Reads the content of a file.
- **Parameters**: `filePath` - Path to the file to read
- **Returns**: File content as string, null if error or file not found

#### `getDirectoryDetails(String directoryPath, {bool recursive = false}) → Future<List<Map<String, dynamic>>?>`
Gets detailed information about directory contents.
- **Parameters**: 
  - `directoryPath` - Directory to explore
  - `recursive` - Whether to include subdirectory contents (default: false)
- **Returns**: List of maps containing file/directory details:
  - `'name'`: file/directory name
  - `'path'`: full path
  - `'isDirectory'`: true if it's a directory
  - `'size'`: file size in bytes (directories have size 0)
  - `'lastModified'`: last modification timestamp

#### `getDirectoryTree(String directoryPath) → Future<Map<String, dynamic>?>`
Gets a tree-like structure of the directory contents.
- **Parameters**: `directoryPath` - Directory to explore
- **Returns**: Nested map representing the directory tree structure

## Platform-Specific Notes

### Android
- Uses Storage Access Framework (SAF) for Android 10+ compliance
- No manifest permissions required
- Persistent URI permissions are automatically handled
- Works with external storage and cloud storage providers

### iOS
- Uses document picker with security-scoped resources
- Automatically handles sandbox restrictions
- Works with Files app and cloud storage providers

### Windows
- Uses native Windows file dialog with COM interfaces
- Full system access (no sandboxing restrictions)
- Supports all Windows file systems

### macOS
- Uses NSOpenPanel for native macOS experience
- Handles app sandboxing automatically
- Integrates with Finder and cloud storage

### Linux
- Uses GTK file chooser for broad desktop environment support
- xdg-desktop-portal integration for modern Linux systems
- Works with GNOME, KDE, XFCE, and other desktop environments

## Example App

The plugin includes a comprehensive example app that demonstrates:
- Directory selection with native file pickers
- Permission checking and handling
- Manual file writing with timestamp names
- Automatic periodic writing (every 10 seconds)
- App lifecycle integration (writes on app resume)
- **Directory exploration and file listing**
- **File content reading with preview**
- **Interactive file browser with details**
- Real-time status updates and progress tracking

Run the example:
```bash
cd example
flutter run
```

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to help improve this plugin.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

