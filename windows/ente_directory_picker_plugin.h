#ifndef FLUTTER_PLUGIN_ENTE_DIRECTORY_PICKER_PLUGIN_H_
#define FLUTTER_PLUGIN_ENTE_DIRECTORY_PICKER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace ente_directory_picker {

class EnteDirectoryPickerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  EnteDirectoryPickerPlugin();

  virtual ~EnteDirectoryPickerPlugin();

  // Disallow copy and assign.
  EnteDirectoryPickerPlugin(const EnteDirectoryPickerPlugin&) = delete;
  EnteDirectoryPickerPlugin& operator=(const EnteDirectoryPickerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  // Implementation methods for Windows API calls
  std::string SelectDirectoryImpl();
  bool HasPermissionImpl(const std::string& directory_path);
  bool RequestPermissionImpl(const std::string& directory_path);
  bool WriteFileImpl(const std::string& directory_path, const std::string& file_name, const std::string& content);
  flutter::EncodableValue ListDirectoryImpl(const std::string& directory_path);
  std::string ReadFileImpl(const std::string& file_path);
  flutter::EncodableValue GetDirectoryDetailsImpl(const std::string& directory_path);
};

}  // namespace ente_directory_picker

#endif  // FLUTTER_PLUGIN_ENTE_DIRECTORY_PICKER_PLUGIN_H_
