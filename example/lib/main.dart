import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ente_directory_picker/ente_directory_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  String _platformVersion = 'Unknown';
  String? _selectedDirectory;
  String _status = 'Ready';
  final _directoryPicker = EnteDirectoryPicker();
  Timer? _periodicTimer;
  bool _isWritingEnabled = false;
  final List<String> _writtenFiles = [];
  AppLifecycleState? _lastLifecycleState;
  List<String>? _directoryContents;
  List<Map<String, dynamic>>? _directoryDetails;
  String? _selectedFileContent;
  String? _currentBrowsingPath;
  final List<String> _pathHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initPlatformState();
    _lastLifecycleState = WidgetsBinding.instance.lifecycleState;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPeriodicWriting();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check if app came from dead/paused state to resumed
    if (_lastLifecycleState != AppLifecycleState.resumed && 
        state == AppLifecycleState.resumed && 
        _isWritingEnabled && 
        _selectedDirectory != null) {
      _writeTimestampFile();
    }
    
    _lastLifecycleState = state;
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _directoryPicker.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> _selectDirectory() async {
    try {
      setState(() => _status = 'Selecting directory...');
      
      final directory = await _directoryPicker.selectDirectory();

      if (directory != null) {
        // Check permissions
        final hasPermission = await _directoryPicker.hasPermission(directory);

        if (hasPermission) {
          setState(() {
            _selectedDirectory = directory;
            _status = 'Directory selected successfully';
          });
          await _exploreDirectory();
        } else {
          // Try to request permission
          final permissionGranted = await _directoryPicker.requestPermission(directory);
          
          if (permissionGranted) {
            setState(() {
              _selectedDirectory = directory;
              _status = 'Directory selected with permissions';
            });
            await _exploreDirectory();
          } else {
            setState(() {
              _selectedDirectory = null;
              _status = 'Permission denied for selected directory';
            });
          }
        }
      } else {
        setState(() {
          _selectedDirectory = null;
          _status = 'Directory selection cancelled';
        });
      }
    } catch (e) {
      setState(() {
        _selectedDirectory = null;
        _status = 'Error selecting directory: $e';
      });
    }
  }

  Future<void> _writeTimestampFile() async {
    if (_selectedDirectory == null) return;

    try {
      final success = await _directoryPicker.writeTimestampFile(_selectedDirectory!);
      final fileName = _directoryPicker.generateTimestampFilename();
      
      if (success) {
        setState(() {
          _writtenFiles.insert(0, fileName);
          if (_writtenFiles.length > 10) {
            _writtenFiles.removeLast(); // Keep only last 10 files
          }
          _status = 'File written: $fileName';
        });
      } else {
        setState(() {
          _status = 'Failed to write file: $fileName';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error writing file: $e';
      });
    }
  }

  void _startPeriodicWriting() {
    if (_selectedDirectory == null) return;
    
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _writeTimestampFile();
    });
    
    // Write initial file when starting
    _writeTimestampFile();
    
    setState(() {
      _isWritingEnabled = true;
      _status = 'Periodic writing started (every 10 seconds)';
    });
  }

  void _stopPeriodicWriting() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    
    setState(() {
      _isWritingEnabled = false;
      _status = 'Periodic writing stopped';
    });
  }

  Future<void> _testManualWrite() async {
    if (_selectedDirectory == null) return;

    try {
      final fileName = 'manual_test_${DateTime.now().millisecondsSinceEpoch}.txt';
      final content = 'Manual test file created at ${DateTime.now()}';
      
      final success = await _directoryPicker.writeFile(
        _selectedDirectory!,
        fileName,
        content,
      );
      
      if (success) {
        setState(() {
          _writtenFiles.insert(0, fileName);
          if (_writtenFiles.length > 10) {
            _writtenFiles.removeLast();
          }
          _status = 'Manual file written: $fileName';
        });
      } else {
        setState(() {
          _status = 'Failed to write manual file: $fileName';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error writing manual file: $e';
      });
    }
  }

  Future<void> _exploreDirectory([String? path]) async {
    final targetPath = path ?? _selectedDirectory;
    if (targetPath == null) return;

    try {
      setState(() => _status = 'Exploring directory contents...');

      // Get basic file listing
      final contents = await _directoryPicker.listDirectory(targetPath);

      // Get detailed directory information
      final details = await _directoryPicker.getDirectoryDetails(targetPath);

      setState(() {
        _directoryContents = contents;
        _directoryDetails = details;
        _currentBrowsingPath = targetPath;
        _status = 'Found ${contents?.length ?? 0} items in directory';
      });
    } catch (e) {
      setState(() {
        _directoryContents = null;
        _directoryDetails = null;
        _status = 'Error exploring directory: $e';
      });
    }
  }

  void _navigateToDirectory(String directoryPath) {
    if (_currentBrowsingPath != null) {
      _pathHistory.add(_currentBrowsingPath!);
    }
    _exploreDirectory(directoryPath);
  }

  void _navigateBack() {
    if (_pathHistory.isNotEmpty) {
      final previousPath = _pathHistory.removeLast();
      _exploreDirectory(previousPath);
    }
  }

  String _getCurrentPathDisplay() {
    if (_currentBrowsingPath == null) return '';
    
    if (_currentBrowsingPath == _selectedDirectory) {
      return '📁 Root';
    }
    
    // For subdirectories, show relative path
    final rootPath = _selectedDirectory ?? '';
    if (_currentBrowsingPath!.startsWith(rootPath)) {
      final relativePath = _currentBrowsingPath!.substring(rootPath.length);
      return '📁 $relativePath'.replaceAll('//', '/');
    }
    
    return '📁 ${_getHumanReadablePath(_currentBrowsingPath!)}';
  }

  Future<void> _readFileContent(String fileName) async {
    if (_selectedDirectory == null) return;

    try {
      setState(() => _status = 'Reading file: $fileName');

      // For Android SAF, we need to construct the proper URI for the file
      // This is a simplified approach - in reality, we'd need to get the actual file URI
      final filePath = '$_selectedDirectory/$fileName';
      final content = await _directoryPicker.readFile(filePath);

      setState(() {
        _selectedFileContent = content;
        _status = content != null 
          ? 'Successfully read file: $fileName (${content.length} characters)'
          : 'Failed to read file: $fileName';
      });
    } catch (e) {
      setState(() {
        _selectedFileContent = null;
        _status = 'Error reading file: $e';
      });
    }
  }

  String _getHumanReadablePath(String path) {
    // URL decode the path first to make it more readable
    String decodedPath = Uri.decodeComponent(path);

    // For Android SAF URIs, try to extract a more readable representation
    if (decodedPath.startsWith('content://com.android.externalstorage.documents')) {
      // Parse Android Storage Access Framework URI
      final uri = Uri.parse(decodedPath);
      final docId = uri.pathSegments.lastOrNull?.split(':').lastOrNull;
      if (docId != null) {
        if (decodedPath.contains('/primary')) {
          return '📱 Internal Storage/$docId';
        } else if (decodedPath.contains('/home')) {
          return '📱 Internal Storage/$docId';
        } else {
          return '💾 External Storage/$docId';
        }
      }
    }

    // Check for iCloud paths (iOS)
    if (decodedPath.contains('CloudDocs') || decodedPath.contains('iCloud')) {
      // Try to extract a more readable iCloud path
      if (decodedPath.contains('iCloud~')) {
        final parts = decodedPath.split('/');
        final relevantParts = parts.where((part) =>
          !part.contains('private') &&
          !part.contains('var') &&
          !part.contains('mobile') &&
          !part.contains('Library') &&
          !part.contains('Mobile Documents') &&
          part.isNotEmpty).toList();

        if (relevantParts.isNotEmpty) {
          return '☁️ iCloud Drive/${relevantParts.skip(relevantParts.indexWhere((p) => p.contains('iCloud')) + 1).join('/')}';
        }
      }
      return '☁️ iCloud Drive/...';
    }

    // Check for local iOS paths
    if (decodedPath.contains('Documents') && (decodedPath.contains('Application') || decodedPath.contains('Container'))) {
      return '📱 On My iPhone/...';
    }

    // For other paths, show full path (no truncation)
    return decodedPath;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ente Directory Picker Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Ente Directory Picker Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Running on: $_platformVersion'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Directory Selection',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_selectedDirectory != null) ...[
                        Text(
                          'Selected Directory:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            _getHumanReadablePath(_selectedDirectory!),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ] else ...[
                        const Text('No directory selected'),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _selectDirectory,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Select Directory'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Writing',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _selectedDirectory != null ? _testManualWrite : null,
                            icon: const Icon(Icons.edit_document),
                            label: const Text('Write Test File'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _selectedDirectory != null && !_isWritingEnabled
                                ? _startPeriodicWriting
                                : null,
                            icon: const Icon(Icons.timer),
                            label: const Text('Start Auto-Write'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isWritingEnabled ? _stopPeriodicWriting : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop Auto-Write'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _status,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      if (_isWritingEnabled) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Auto-writing enabled (every 10 seconds)'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_directoryContents != null && _directoryContents!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Directory Contents',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            if (_pathHistory.isNotEmpty)
                              IconButton(
                                onPressed: _navigateBack,
                                icon: const Icon(Icons.arrow_back),
                                tooltip: 'Go Back',
                              ),
                            ElevatedButton.icon(
                              onPressed: _exploreDirectory,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        if (_currentBrowsingPath != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              _getCurrentPathDisplay(),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            itemCount: _directoryDetails?.length ?? 0,
                            itemBuilder: (context, index) {
                              final item = _directoryDetails![index];
                              final isDirectory = item['isDirectory'] as bool? ?? false;
                              final name = item['name'] as String? ?? 'Unknown';
                              final size = item['size'] as int? ?? 0;
                              final path = item['path'] as String? ?? '';
                              
                              return ListTile(
                                onTap: isDirectory ? () => _navigateToDirectory(path) : null,
                                leading: Icon(
                                  isDirectory ? Icons.folder : Icons.description,
                                  color: isDirectory ? Colors.amber : Colors.blue,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                                subtitle: Text(
                                  isDirectory 
                                    ? 'Directory • Tap to open' 
                                    : '${(size / 1024).toStringAsFixed(1)} KB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: !isDirectory 
                                  ? IconButton(
                                      icon: const Icon(Icons.visibility),
                                      onPressed: () => _readFileContent(name),
                                      tooltip: 'Read file content',
                                    )
                                  : null,
                                dense: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_selectedFileContent != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File Content',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 150,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _selectedFileContent!,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_writtenFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recently Written Files',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ListView.builder(
                            itemCount: _writtenFiles.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                leading: const Icon(Icons.description),
                                title: Text(
                                  _writtenFiles[index],
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                                dense: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
