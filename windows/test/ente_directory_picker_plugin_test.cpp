#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>
#include <filesystem>
#include <fstream>

#include "ente_directory_picker_plugin.h"

namespace ente_directory_picker {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(EnteDirectoryPickerPlugin, GetPlatformVersion) {
  EnteDirectoryPickerPlugin plugin;
  // Save the reply value from the success callback.
  std::string result_string;
  plugin.HandleMethodCall(
      MethodCall("getPlatformVersion", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&result_string](const EncodableValue* result) {
            result_string = std::get<std::string>(*result);
          },
          nullptr, nullptr));

  // Since the exact string varies by host, just ensure that it's a string
  // with the expected format.
  EXPECT_TRUE(result_string.rfind("Windows ", 0) == 0);
}

TEST(EnteDirectoryPickerPlugin, HasPermissionValidDirectory) {
  EnteDirectoryPickerPlugin plugin;
  bool result_value = false;
  bool success_called = false;
  
  // Create a temporary directory for testing
  std::filesystem::path temp_dir = std::filesystem::temp_directory_path() / "test_write_folder";
  std::filesystem::create_directories(temp_dir);
  
  EncodableMap args;
  args[EncodableValue("directoryPath")] = EncodableValue(temp_dir.string());
  
  plugin.HandleMethodCall(
      MethodCall("hasPermission", std::make_unique<EncodableValue>(args)),
      std::make_unique<MethodResultFunctions<>>(
          [&result_value, &success_called](const EncodableValue* result) {
            result_value = std::get<bool>(*result);
            success_called = true;
          },
          nullptr, nullptr));

  EXPECT_TRUE(success_called);
  EXPECT_TRUE(result_value); // Should have permission to temp directory
  
  // Clean up
  std::filesystem::remove_all(temp_dir);
}

TEST(EnteDirectoryPickerPlugin, HasPermissionInvalidDirectory) {
  EnteDirectoryPickerPlugin plugin;
  bool result_value = true;
  bool success_called = false;
  
  EncodableMap args;
  args[EncodableValue("directoryPath")] = EncodableValue("C:\\NonExistentDirectory12345");
  
  plugin.HandleMethodCall(
      MethodCall("hasPermission", std::make_unique<EncodableValue>(args)),
      std::make_unique<MethodResultFunctions<>>(
          [&result_value, &success_called](const EncodableValue* result) {
            result_value = std::get<bool>(*result);
            success_called = true;
          },
          nullptr, nullptr));

  EXPECT_TRUE(success_called);
  EXPECT_FALSE(result_value); // Should not have permission to non-existent directory
}

TEST(EnteDirectoryPickerPlugin, HasPermissionMissingArgument) {
  EnteDirectoryPickerPlugin plugin;
  bool error_called = false;
  std::string error_code;
  
  plugin.HandleMethodCall(
      MethodCall("hasPermission", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          nullptr,
          [&error_called, &error_code](const std::string& code, const std::string& message, const EncodableValue* details) {
            error_called = true;
            error_code = code;
          },
          nullptr));

  EXPECT_TRUE(error_called);
  EXPECT_EQ(error_code, "INVALID_ARGUMENT");
}

TEST(EnteDirectoryPickerPlugin, RequestPermissionValidDirectory) {
  EnteDirectoryPickerPlugin plugin;
  bool result_value = false;
  bool success_called = false;
  
  // Create a temporary directory for testing
  std::filesystem::path temp_dir = std::filesystem::temp_directory_path() / "test_write_folder_request";
  std::filesystem::create_directories(temp_dir);
  
  EncodableMap args;
  args[EncodableValue("directoryPath")] = EncodableValue(temp_dir.string());
  
  plugin.HandleMethodCall(
      MethodCall("requestPermission", std::make_unique<EncodableValue>(args)),
      std::make_unique<MethodResultFunctions<>>(
          [&result_value, &success_called](const EncodableValue* result) {
            result_value = std::get<bool>(*result);
            success_called = true;
          },
          nullptr, nullptr));

  EXPECT_TRUE(success_called);
  EXPECT_TRUE(result_value); // Should have permission to temp directory
  
  // Clean up
  std::filesystem::remove_all(temp_dir);
}

TEST(EnteDirectoryPickerPlugin, WriteFileValidArguments) {
  EnteDirectoryPickerPlugin plugin;
  bool result_value = false;
  bool success_called = false;
  
  // Create a temporary directory for testing
  std::filesystem::path temp_dir = std::filesystem::temp_directory_path() / "test_write_file";
  std::filesystem::create_directories(temp_dir);
  
  EncodableMap args;
  args[EncodableValue("directoryPath")] = EncodableValue(temp_dir.string());
  args[EncodableValue("fileName")] = EncodableValue("test.txt");
  args[EncodableValue("content")] = EncodableValue("Hello, World!");
  
  plugin.HandleMethodCall(
      MethodCall("writeFile", std::make_unique<EncodableValue>(args)),
      std::make_unique<MethodResultFunctions<>>(
          [&result_value, &success_called](const EncodableValue* result) {
            result_value = std::get<bool>(*result);
            success_called = true;
          },
          nullptr, nullptr));

  EXPECT_TRUE(success_called);
  EXPECT_TRUE(result_value);
  
  // Verify file was created and has correct content
  std::filesystem::path file_path = temp_dir / "test.txt";
  EXPECT_TRUE(std::filesystem::exists(file_path));
  
  std::ifstream file(file_path);
  std::string content;
  std::getline(file, content);
  EXPECT_EQ(content, "Hello, World!");
  
  // Clean up
  std::filesystem::remove_all(temp_dir);
}

TEST(EnteDirectoryPickerPlugin, WriteFileMissingArguments) {
  EnteDirectoryPickerPlugin plugin;
  bool error_called = false;
  std::string error_code;
  
  EncodableMap args;
  args[EncodableValue("directoryPath")] = EncodableValue("C:\\temp");
  // Missing fileName and content
  
  plugin.HandleMethodCall(
      MethodCall("writeFile", std::make_unique<EncodableValue>(args)),
      std::make_unique<MethodResultFunctions<>>(
          nullptr,
          [&error_called, &error_code](const std::string& code, const std::string& message, const EncodableValue* details) {
            error_called = true;
            error_code = code;
          },
          nullptr));

  EXPECT_TRUE(error_called);
  EXPECT_EQ(error_code, "INVALID_ARGUMENT");
}

}  // namespace test
}  // namespace ente_directory_picker
