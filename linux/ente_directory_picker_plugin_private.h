#include <flutter_linux/flutter_linux.h>

#include "include/ente_directory_picker/ente_directory_picker_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles the getPlatformVersion method call.
FlMethodResponse *get_platform_version();

// Handles the selectDirectory method call.
FlMethodResponse *select_directory();

// Handles the hasPermission method call.
FlMethodResponse *has_permission(FlValue* args);

// Handles the requestPermission method call.
FlMethodResponse *request_permission(FlValue* args);

// Handles the writeFile method call.
FlMethodResponse *write_file(FlValue* args);

// Handles the listDirectory method call.
FlMethodResponse *list_directory(FlValue* args);

// Handles the readFile method call.
FlMethodResponse *read_file(FlValue* args);

// Handles the getDirectoryDetails method call.
FlMethodResponse *get_directory_details(FlValue* args);
