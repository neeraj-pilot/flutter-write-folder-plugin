#include "include/ente_directory_picker/ente_directory_picker_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "ente_directory_picker_plugin.h"

void EnteDirectoryPickerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ente_directory_picker::EnteDirectoryPickerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
