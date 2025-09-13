#include "ente_directory_picker_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <commdlg.h>
#include <shlobj.h>
#include <shobjidl.h>
#include <comdef.h>
#include <atlbase.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <string>
#include <fstream>
#include <filesystem>
#include <vector>
#include <chrono>

namespace ente_directory_picker {

// static
void EnteDirectoryPickerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "ente_directory_picker",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<EnteDirectoryPickerPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

EnteDirectoryPickerPlugin::EnteDirectoryPickerPlugin() {}

EnteDirectoryPickerPlugin::~EnteDirectoryPickerPlugin() {}

void EnteDirectoryPickerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name().compare("selectDirectory") == 0) {
    std::string selected_path = SelectDirectoryImpl();
    if (!selected_path.empty()) {
      result->Success(flutter::EncodableValue(selected_path));
    } else {
      result->Success(); // Return null if no directory selected
    }
  } else if (method_call.method_name().compare("hasPermission") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto it = arguments->find(flutter::EncodableValue("directoryPath"));
      if (it != arguments->end()) {
        const std::string path = std::get<std::string>(it->second);
        bool has_permission = HasPermissionImpl(path);
        result->Success(flutter::EncodableValue(has_permission));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "directoryPath is required");
  } else if (method_call.method_name().compare("requestPermission") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto it = arguments->find(flutter::EncodableValue("directoryPath"));
      if (it != arguments->end()) {
        const std::string path = std::get<std::string>(it->second);
        bool permission_granted = RequestPermissionImpl(path);
        result->Success(flutter::EncodableValue(permission_granted));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "directoryPath is required");
  } else if (method_call.method_name().compare("writeFile") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto dir_it = arguments->find(flutter::EncodableValue("directoryPath"));
      auto name_it = arguments->find(flutter::EncodableValue("fileName"));
      auto content_it = arguments->find(flutter::EncodableValue("content"));
      
      if (dir_it != arguments->end() && name_it != arguments->end() && content_it != arguments->end()) {
        const std::string directory_path = std::get<std::string>(dir_it->second);
        const std::string file_name = std::get<std::string>(name_it->second);
        const std::string content = std::get<std::string>(content_it->second);
        
        bool write_success = WriteFileImpl(directory_path, file_name, content);
        result->Success(flutter::EncodableValue(write_success));
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "directoryPath, fileName, and content are required");
  } else if (method_call.method_name().compare("listDirectory") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto dir_it = arguments->find(flutter::EncodableValue("directoryPath"));
      if (dir_it != arguments->end()) {
        const std::string directory_path = std::get<std::string>(dir_it->second);
        flutter::EncodableValue file_list = ListDirectoryImpl(directory_path);
        result->Success(file_list);
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "directoryPath is required");
  } else if (method_call.method_name().compare("readFile") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto file_it = arguments->find(flutter::EncodableValue("filePath"));
      if (file_it != arguments->end()) {
        const std::string file_path = std::get<std::string>(file_it->second);
        std::string content = ReadFileImpl(file_path);
        if (!content.empty()) {
          result->Success(flutter::EncodableValue(content));
        } else {
          result->Success(); // Return null if file doesn't exist or can't be read
        }
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "filePath is required");
  } else if (method_call.method_name().compare("getDirectoryDetails") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto dir_it = arguments->find(flutter::EncodableValue("directoryPath"));
      if (dir_it != arguments->end()) {
        const std::string directory_path = std::get<std::string>(dir_it->second);
        flutter::EncodableValue details = GetDirectoryDetailsImpl(directory_path);
        result->Success(details);
        return;
      }
    }
    result->Error("INVALID_ARGUMENT", "directoryPath is required");
  } else {
    result->NotImplemented();
  }
}

// Implementation methods for Windows API calls
std::string EnteDirectoryPickerPlugin::SelectDirectoryImpl() {
  HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
  if (FAILED(hr)) {
    return "";
  }

  CComPtr<IFileOpenDialog> pFileOpen;
  hr = CoCreateInstance(CLSID_FileOpenDialog, NULL, CLSCTX_ALL, IID_IFileOpenDialog, reinterpret_cast<void**>(&pFileOpen));

  if (SUCCEEDED(hr)) {
    // Set dialog options to pick folders only
    DWORD dwOptions;
    hr = pFileOpen->GetOptions(&dwOptions);
    if (SUCCEEDED(hr)) {
      hr = pFileOpen->SetOptions(dwOptions | FOS_PICKFOLDERS);
    }

    if (SUCCEEDED(hr)) {
      // Show the dialog
      hr = pFileOpen->Show(NULL);

      if (SUCCEEDED(hr)) {
        // Get the result
        CComPtr<IShellItem> pItem;
        hr = pFileOpen->GetResult(&pItem);
        if (SUCCEEDED(hr)) {
          PWSTR pszFilePath;
          hr = pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath);

          if (SUCCEEDED(hr)) {
            // Convert wide string to standard string
            int size_needed = WideCharToMultiByte(CP_UTF8, 0, pszFilePath, -1, NULL, 0, NULL, NULL);
            std::string str_path(size_needed, 0);
            WideCharToMultiByte(CP_UTF8, 0, pszFilePath, -1, &str_path[0], size_needed, NULL, NULL);
            
            // Remove null terminator
            str_path.pop_back();
            
            CoTaskMemFree(pszFilePath);
            CoUninitialize();
            return str_path;
          }
        }
      }
    }
  }

  CoUninitialize();
  return ""; // Return empty string if dialog was cancelled or failed
}

bool EnteDirectoryPickerPlugin::HasPermissionImpl(const std::string& directory_path) {
  // Convert string to wide string for Windows API
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, directory_path.c_str(), -1, NULL, 0);
  std::wstring wide_path(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, directory_path.c_str(), -1, &wide_path[0], size_needed);
  
  // Remove null terminator
  wide_path.pop_back();

  // Check if directory exists
  DWORD attributes = GetFileAttributesW(wide_path.c_str());
  if (attributes == INVALID_FILE_ATTRIBUTES || !(attributes & FILE_ATTRIBUTE_DIRECTORY)) {
    return false; // Directory doesn't exist
  }

  // Try to create a temporary file to test write access
  std::wstring test_file_path = wide_path + L"\\write_test_temp.tmp";
  HANDLE hFile = CreateFileW(
    test_file_path.c_str(),
    GENERIC_WRITE,
    0,
    NULL,
    CREATE_NEW,
    FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_DELETE_ON_CLOSE,
    NULL
  );

  if (hFile != INVALID_HANDLE_VALUE) {
    CloseHandle(hFile); // File will be automatically deleted due to FILE_FLAG_DELETE_ON_CLOSE
    return true;
  }

  return false;
}

bool EnteDirectoryPickerPlugin::RequestPermissionImpl(const std::string& directory_path) {
  // On Windows, permissions are typically handled automatically by the OS
  // We just check if we have permission using the same logic as HasPermission
  return HasPermissionImpl(directory_path);
}

bool EnteDirectoryPickerPlugin::WriteFileImpl(const std::string& directory_path, const std::string& file_name, const std::string& content) {
  try {
    // Construct full file path
    std::filesystem::path dir_path(directory_path);
    std::filesystem::path full_path = dir_path / file_name;

    // Create directories if they don't exist
    std::filesystem::create_directories(dir_path);

    // Write the file
    std::ofstream file(full_path, std::ios::binary | std::ios::out);
    if (!file.is_open()) {
      return false;
    }

    file << content;
    file.close();

    return file.good();
  }
  catch (const std::exception&) {
    return false;
  }
}

flutter::EncodableValue EnteDirectoryPickerPlugin::ListDirectoryImpl(const std::string& directory_path) {
  try {
    std::filesystem::path dir_path(directory_path);

    // Check if directory exists
    if (!std::filesystem::exists(dir_path) || !std::filesystem::is_directory(dir_path)) {
      return flutter::EncodableValue(); // Return null
    }

    flutter::EncodableList file_list;

    for (const auto& entry : std::filesystem::directory_iterator(dir_path)) {
      file_list.push_back(flutter::EncodableValue(entry.path().filename().string()));
    }

    return flutter::EncodableValue(file_list);
  }
  catch (const std::exception&) {
    return flutter::EncodableValue(); // Return null on error
  }
}

std::string EnteDirectoryPickerPlugin::ReadFileImpl(const std::string& file_path) {
  try {
    std::filesystem::path path(file_path);

    // Check if file exists
    if (!std::filesystem::exists(path) || !std::filesystem::is_regular_file(path)) {
      return "";
    }

    std::ifstream file(path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
      return "";
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::string content(size, '\0');
    if (!file.read(&content[0], size)) {
      return "";
    }

    return content;
  }
  catch (const std::exception&) {
    return "";
  }
}

flutter::EncodableValue EnteDirectoryPickerPlugin::GetDirectoryDetailsImpl(const std::string& directory_path) {
  try {
    std::filesystem::path dir_path(directory_path);

    // Check if directory exists
    if (!std::filesystem::exists(dir_path) || !std::filesystem::is_directory(dir_path)) {
      return flutter::EncodableValue(); // Return null
    }

    flutter::EncodableList details_list;

    for (const auto& entry : std::filesystem::directory_iterator(dir_path)) {
      flutter::EncodableMap item;

      item[flutter::EncodableValue("name")] = flutter::EncodableValue(entry.path().filename().string());
      item[flutter::EncodableValue("path")] = flutter::EncodableValue(entry.path().string());
      item[flutter::EncodableValue("isDirectory")] = flutter::EncodableValue(entry.is_directory());

      if (entry.is_regular_file()) {
        try {
          item[flutter::EncodableValue("size")] = flutter::EncodableValue(static_cast<int64_t>(std::filesystem::file_size(entry)));
        } catch (...) {
          item[flutter::EncodableValue("size")] = flutter::EncodableValue(0);
        }
      } else {
        item[flutter::EncodableValue("size")] = flutter::EncodableValue(0);
      }

      // Get last modified time
      try {
        auto ftime = std::filesystem::last_write_time(entry);
        auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
          ftime - std::filesystem::file_time_type::clock::now() + std::chrono::system_clock::now());
        auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(sctp.time_since_epoch()).count();
        item[flutter::EncodableValue("lastModified")] = flutter::EncodableValue(millis);
      } catch (...) {
        item[flutter::EncodableValue("lastModified")] = flutter::EncodableValue(0);
      }

      details_list.push_back(flutter::EncodableValue(item));
    }

    return flutter::EncodableValue(details_list);
  }
  catch (const std::exception&) {
    return flutter::EncodableValue(); // Return null on error
  }
}

}  // namespace ente_directory_picker
