//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <ente_directory_picker/ente_directory_picker_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) ente_directory_picker_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "EnteDirectoryPickerPlugin");
  ente_directory_picker_plugin_register_with_registrar(ente_directory_picker_registrar);
}
