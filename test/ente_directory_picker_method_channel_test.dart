import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ente_directory_picker/ente_directory_picker_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelEnteDirectoryPicker platform = MethodChannelEnteDirectoryPicker();
  const MethodChannel channel = MethodChannel('ente_directory_picker');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
