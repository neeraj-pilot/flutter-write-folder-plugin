#include "include/ente_directory_picker/ente_directory_picker_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gio/gio.h>
#include <glib.h>
#include <sys/utsname.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <fstream>

#include <cstring>
#include <memory>

#include "ente_directory_picker_plugin_private.h"

#define ENTE_DIRECTORY_PICKER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), ente_directory_picker_plugin_get_type(), \
                              EnteDirectoryPickerPlugin))

struct _EnteDirectoryPickerPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(EnteDirectoryPickerPlugin, ente_directory_picker_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void ente_directory_picker_plugin_handle_method_call(
    EnteDirectoryPickerPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "selectDirectory") == 0) {
    response = select_directory();
  } else if (strcmp(method, "hasPermission") == 0) {
    response = has_permission(args);
  } else if (strcmp(method, "requestPermission") == 0) {
    response = request_permission(args);
  } else if (strcmp(method, "writeFile") == 0) {
    response = write_file(args);
  } else if (strcmp(method, "listDirectory") == 0) {
    response = list_directory(args);
  } else if (strcmp(method, "readFile") == 0) {
    response = read_file(args);
  } else if (strcmp(method, "getDirectoryDetails") == 0) {
    response = get_directory_details(args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Helper function to check if running in Flatpak
static gboolean is_running_in_flatpak() {
  // Check if /run/flatpak-info exists
  return g_file_test("/run/flatpak-info", G_FILE_TEST_EXISTS);
}

// Helper function to check if running in Snap
static gboolean is_running_in_snap() {
  // Check if SNAP environment variable is set
  const char* snap = g_getenv("SNAP");
  return snap != nullptr && strlen(snap) > 0;
}

// Helper function to check if xdg-desktop-portal is available
static gboolean is_xdg_portal_available() {
  GDBusConnection* connection = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, nullptr);
  if (!connection) {
    return FALSE;
  }
  
  GDBusProxy* proxy = g_dbus_proxy_new_sync(
    connection,
    G_DBUS_PROXY_FLAGS_NONE,
    nullptr,
    "org.freedesktop.portal.Desktop",
    "/org/freedesktop/portal/desktop",
    "org.freedesktop.portal.FileChooser",
    nullptr,
    nullptr
  );
  
  gboolean available = (proxy != nullptr);
  if (proxy) {
    g_object_unref(proxy);
  }
  g_object_unref(connection);
  return available;
}

// Helper function to select directory using xdg-desktop-portal
static gchar* select_directory_via_portal() {
  // Note: Portal implementation requires async handling which is complex.
  // For now, we detect if we're in a sandboxed environment and inform the user.
  // A full portal implementation would require:
  // 1. Creating a portal request
  // 2. Handling async response via DBus signals
  // 3. Extracting the selected path from the response

  if (is_running_in_flatpak()) {
    g_print("Running in Flatpak - using GTK dialog with portal permissions\n");
  } else if (is_running_in_snap()) {
    g_print("Running in Snap - using GTK dialog with snap permissions\n");
  }

  // Return nullptr to fall back to GTK dialog
  // In sandboxed environments, the GTK dialog will use portal internally
  return nullptr;
}

// Helper function to select directory using GTK
static gchar* select_directory_via_gtk() {
  GtkWidget* dialog = gtk_file_chooser_dialog_new(
    "Select Directory",
    nullptr,
    GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
    "_Cancel", GTK_RESPONSE_CANCEL,
    "_Select", GTK_RESPONSE_ACCEPT,
    nullptr
  );
  
  gchar* selected_path = nullptr;
  gint result = gtk_dialog_run(GTK_DIALOG(dialog));
  
  if (result == GTK_RESPONSE_ACCEPT) {
    selected_path = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
  }
  
  gtk_widget_destroy(dialog);
  return selected_path;
}

FlMethodResponse* select_directory() {
  gchar* selected_path = nullptr;

  // Check if we're in a sandboxed environment
  gboolean is_sandboxed = is_running_in_flatpak() || is_running_in_snap();

  // Try xdg-desktop-portal first if available and sandboxed
  if (is_sandboxed && is_xdg_portal_available()) {
    selected_path = select_directory_via_portal();
  }

  // Use GTK dialog (will use portal internally if sandboxed)
  if (!selected_path) {
    selected_path = select_directory_via_gtk();
  }
  
  if (selected_path) {
    g_autoptr(FlValue) result = fl_value_new_string(selected_path);
    g_free(selected_path);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    // Return null if user cancelled or error occurred
    g_autoptr(FlValue) result = fl_value_new_null();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
}

FlMethodResponse* has_permission(FlValue* args) {
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "Arguments must be a map", nullptr));
  }

  FlValue* directory_path_value = fl_value_lookup_string(args, "directoryPath");
  if (!directory_path_value || fl_value_get_type(directory_path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "directoryPath must be a string", nullptr));
  }

  const gchar* directory_path = fl_value_get_string(directory_path_value);
  
  // Check if directory exists and is accessible
  struct stat st;
  if (stat(directory_path, &st) != 0) {
    // Directory doesn't exist or is not accessible
    g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  
  // Check if it's actually a directory
  if (!S_ISDIR(st.st_mode)) {
    g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  
  // Check if we have write permission
  if (access(directory_path, W_OK) == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
}

FlMethodResponse* request_permission(FlValue* args) {
  // On Linux, permissions are typically managed by the file system
  // and user account privileges. We can't "request" permissions like on mobile platforms.
  // We'll just check if we have permission and return the result.
  return has_permission(args);
}

FlMethodResponse* write_file(FlValue* args) {
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "Arguments must be a map", nullptr));
  }
  
  FlValue* directory_path_value = fl_value_lookup_string(args, "directoryPath");
  FlValue* file_name_value = fl_value_lookup_string(args, "fileName");
  FlValue* content_value = fl_value_lookup_string(args, "content");
  
  if (!directory_path_value || fl_value_get_type(directory_path_value) != FL_VALUE_TYPE_STRING ||
      !file_name_value || fl_value_get_type(file_name_value) != FL_VALUE_TYPE_STRING ||
      !content_value || fl_value_get_type(content_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "directoryPath, fileName, and content must be strings", nullptr));
  }
  
  const gchar* directory_path = fl_value_get_string(directory_path_value);
  const gchar* file_name = fl_value_get_string(file_name_value);
  const gchar* content = fl_value_get_string(content_value);
  
  // Validate directory path
  struct stat st;
  if (stat(directory_path, &st) != 0 || !S_ISDIR(st.st_mode)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_DIRECTORY", "Directory does not exist or is not accessible", nullptr));
  }
  
  // Check write permission
  if (access(directory_path, W_OK) != 0) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "PERMISSION_DENIED", "No write permission for directory", nullptr));
  }
  
  // Build full file path
  g_autofree gchar* file_path = g_build_filename(directory_path, file_name, nullptr);
  
  // Validate file name (basic security check)
  if (strstr(file_name, "..") || strstr(file_name, "/") || strstr(file_name, "\\")) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_FILENAME", "File name contains invalid characters", nullptr));
  }
  
  // Write file using GLib for better UTF-8 handling
  GError* error = nullptr;
  gboolean success = g_file_set_contents(file_path, content, -1, &error);
  
  if (success) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    FlMethodResponse* response = FL_METHOD_RESPONSE(fl_method_error_response_new(
      "FILE_WRITE_ERROR", error ? error->message : "Failed to write file", nullptr));
    if (error) {
      g_error_free(error);
    }
    return response;
  }
}

FlMethodResponse* list_directory(FlValue* args) {
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "Arguments must be a map", nullptr));
  }

  FlValue* directory_path_value = fl_value_lookup_string(args, "directoryPath");
  if (!directory_path_value || fl_value_get_type(directory_path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "directoryPath must be a string", nullptr));
  }

  const gchar* directory_path = fl_value_get_string(directory_path_value);

  // Check if directory exists
  if (!g_file_test(directory_path, G_FILE_TEST_IS_DIR)) {
    g_autoptr(FlValue) result = fl_value_new_null();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  GError* error = nullptr;
  GDir* dir = g_dir_open(directory_path, 0, &error);

  if (!dir) {
    FlMethodResponse* response = FL_METHOD_RESPONSE(fl_method_error_response_new(
      "DIR_READ_ERROR", error ? error->message : "Failed to read directory", nullptr));
    if (error) g_error_free(error);
    return response;
  }

  g_autoptr(FlValue) file_list = fl_value_new_list();
  const gchar* filename;

  while ((filename = g_dir_read_name(dir)) != nullptr) {
    fl_value_append_take(file_list, fl_value_new_string(filename));
  }

  g_dir_close(dir);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(file_list));
}

FlMethodResponse* read_file(FlValue* args) {
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "Arguments must be a map", nullptr));
  }

  FlValue* file_path_value = fl_value_lookup_string(args, "filePath");
  if (!file_path_value || fl_value_get_type(file_path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "filePath must be a string", nullptr));
  }

  const gchar* file_path = fl_value_get_string(file_path_value);

  // Check if file exists
  if (!g_file_test(file_path, G_FILE_TEST_EXISTS)) {
    g_autoptr(FlValue) result = fl_value_new_null();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  GError* error = nullptr;
  gchar* content = nullptr;
  gsize length = 0;

  if (g_file_get_contents(file_path, &content, &length, &error)) {
    g_autoptr(FlValue) result = fl_value_new_string(content);
    g_free(content);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    FlMethodResponse* response = FL_METHOD_RESPONSE(fl_method_error_response_new(
      "FILE_READ_ERROR", error ? error->message : "Failed to read file", nullptr));
    if (error) g_error_free(error);
    return response;
  }
}

FlMethodResponse* get_directory_details(FlValue* args) {
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "Arguments must be a map", nullptr));
  }

  FlValue* directory_path_value = fl_value_lookup_string(args, "directoryPath");
  if (!directory_path_value || fl_value_get_type(directory_path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
      "INVALID_ARGUMENT", "directoryPath must be a string", nullptr));
  }

  const gchar* directory_path = fl_value_get_string(directory_path_value);

  // Check if directory exists
  if (!g_file_test(directory_path, G_FILE_TEST_IS_DIR)) {
    g_autoptr(FlValue) result = fl_value_new_null();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  GError* error = nullptr;
  GDir* dir = g_dir_open(directory_path, 0, &error);

  if (!dir) {
    FlMethodResponse* response = FL_METHOD_RESPONSE(fl_method_error_response_new(
      "DIR_READ_ERROR", error ? error->message : "Failed to read directory", nullptr));
    if (error) g_error_free(error);
    return response;
  }

  g_autoptr(FlValue) details_list = fl_value_new_list();
  const gchar* filename;

  while ((filename = g_dir_read_name(dir)) != nullptr) {
    g_autofree gchar* full_path = g_build_filename(directory_path, filename, nullptr);

    struct stat st;
    if (stat(full_path, &st) == 0) {
      g_autoptr(FlValue) item = fl_value_new_map();

      fl_value_set_string_take(item, "name", fl_value_new_string(filename));
      fl_value_set_string_take(item, "path", fl_value_new_string(full_path));
      fl_value_set_string_take(item, "isDirectory", fl_value_new_bool(S_ISDIR(st.st_mode)));
      fl_value_set_string_take(item, "size", fl_value_new_int(st.st_size));
      fl_value_set_string_take(item, "lastModified", fl_value_new_int(st.st_mtime * 1000)); // Convert to milliseconds

      fl_value_append(details_list, item);
    }
  }

  g_dir_close(dir);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(details_list));
}

static void ente_directory_picker_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(ente_directory_picker_plugin_parent_class)->dispose(object);
}

static void ente_directory_picker_plugin_class_init(EnteDirectoryPickerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = ente_directory_picker_plugin_dispose;
}

static void ente_directory_picker_plugin_init(EnteDirectoryPickerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  EnteDirectoryPickerPlugin* plugin = ENTE_DIRECTORY_PICKER_PLUGIN(user_data);
  ente_directory_picker_plugin_handle_method_call(plugin, method_call);
}

void ente_directory_picker_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  EnteDirectoryPickerPlugin* plugin = ENTE_DIRECTORY_PICKER_PLUGIN(
      g_object_new(ente_directory_picker_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "ente_directory_picker",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
