import 'package:flutter_test/flutter_test.dart';
import 'package:ente_directory_picker/ente_directory_picker.dart';
import 'package:ente_directory_picker/ente_directory_picker_platform_interface.dart';
import 'package:ente_directory_picker/ente_directory_picker_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockEnteDirectoryPickerPlatform
    with MockPlatformInterfaceMixin
    implements EnteDirectoryPickerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<String?> selectDirectory() => Future.value('/mock/directory');

  @override
  Future<bool> hasPermission(String directoryPath) => Future.value(true);

  @override
  Future<bool> requestPermission(String directoryPath) => Future.value(true);

  @override
  Future<bool> writeFile(String directoryPath, String fileName, String content) => Future.value(true);

  @override
  Future<List<String>?> listDirectory(String directoryPath, {bool recursive = false}) => 
    Future.value(['file1.txt', 'file2.txt', 'subfolder']);

  @override
  Future<String?> readFile(String filePath) => Future.value('Mock file content');

  @override
  Future<List<Map<String, dynamic>>?> getDirectoryDetails(String directoryPath, {bool recursive = false}) =>
    Future.value([
      {'name': 'file1.txt', 'path': '/mock/path/file1.txt', 'isDirectory': false, 'size': 1024, 'lastModified': 1234567890},
      {'name': 'subfolder', 'path': '/mock/path/subfolder', 'isDirectory': true, 'size': 0, 'lastModified': 1234567890}
    ]);
}

void main() {
  final EnteDirectoryPickerPlatform initialPlatform = EnteDirectoryPickerPlatform.instance;

  test('$MethodChannelEnteDirectoryPicker is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelEnteDirectoryPicker>());
  });

  test('getPlatformVersion', () async {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    MockEnteDirectoryPickerPlatform fakePlatform = MockEnteDirectoryPickerPlatform();
    EnteDirectoryPickerPlatform.instance = fakePlatform;

    expect(await directoryPicker.getPlatformVersion(), '42');
  });

  test('selectDirectory', () async {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    MockEnteDirectoryPickerPlatform fakePlatform = MockEnteDirectoryPickerPlatform();
    EnteDirectoryPickerPlatform.instance = fakePlatform;

    expect(await directoryPicker.selectDirectory(), '/mock/directory');
  });

  test('hasPermission', () async {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    MockEnteDirectoryPickerPlatform fakePlatform = MockEnteDirectoryPickerPlatform();
    EnteDirectoryPickerPlatform.instance = fakePlatform;

    expect(await directoryPicker.hasPermission('/test/path'), true);
  });

  test('writeFile', () async {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    MockEnteDirectoryPickerPlatform fakePlatform = MockEnteDirectoryPickerPlatform();
    EnteDirectoryPickerPlatform.instance = fakePlatform;

    expect(await directoryPicker.writeFile('/test/path', 'test.txt', 'content'), true);
  });

  test('generateTimestampFilename', () {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    final filename = directoryPicker.generateTimestampFilename();
    
    expect(filename.endsWith('.txt'), true);
    expect(filename.contains('-'), true);
    expect(filename.contains('_'), true);
  });

  test('generateTimestampFilename with custom extension', () {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    final filename = directoryPicker.generateTimestampFilename('log');
    
    expect(filename.endsWith('.log'), true);
  });

  test('listDirectory', () async {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    MockEnteDirectoryPickerPlatform fakePlatform = MockEnteDirectoryPickerPlatform();
    EnteDirectoryPickerPlatform.instance = fakePlatform;

    final files = await directoryPicker.listDirectory('/test/path');
    expect(files, ['file1.txt', 'file2.txt', 'subfolder']);
  });

  test('readFile', () async {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    MockEnteDirectoryPickerPlatform fakePlatform = MockEnteDirectoryPickerPlatform();
    EnteDirectoryPickerPlatform.instance = fakePlatform;

    final content = await directoryPicker.readFile('/test/path/file.txt');
    expect(content, 'Mock file content');
  });

  test('getDirectoryDetails', () async {
    EnteDirectoryPicker directoryPicker = EnteDirectoryPicker();
    MockEnteDirectoryPickerPlatform fakePlatform = MockEnteDirectoryPickerPlatform();
    EnteDirectoryPickerPlatform.instance = fakePlatform;

    final details = await directoryPicker.getDirectoryDetails('/test/path');
    expect(details?.length, 2);
    expect(details?[0]['name'], 'file1.txt');
    expect(details?[0]['isDirectory'], false);
    expect(details?[1]['name'], 'subfolder');
    expect(details?[1]['isDirectory'], true);
  });
}
