import Cocoa
import FlutterMacOS

public class EnteDirectoryPickerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ente_directory_picker", binaryMessenger: registrar.messenger)
    let instance = EnteDirectoryPickerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
      
    case "selectDirectory":
      selectDirectory(result: result)
      
    case "hasPermission":
      if let args = call.arguments as? [String: Any],
         let directoryPath = args["directoryPath"] as? String {
        result(hasPermission(directoryPath: directoryPath))
      } else {
        result(false)
      }
      
    case "requestPermission":
      if let args = call.arguments as? [String: Any],
         let directoryPath = args["directoryPath"] as? String {
        result(requestPermission(directoryPath: directoryPath))
      } else {
        result(false)
      }
      
    case "writeFile":
      if let args = call.arguments as? [String: Any],
         let directoryPath = args["directoryPath"] as? String,
         let fileName = args["fileName"] as? String,
         let content = args["content"] as? String {
        result(writeFile(directoryPath: directoryPath, fileName: fileName, content: content))
      } else {
        result(false)
      }

    case "listDirectory":
      if let args = call.arguments as? [String: Any],
         let directoryPath = args["directoryPath"] as? String {
        let recursive = args["recursive"] as? Bool ?? false
        result(listDirectory(directoryPath: directoryPath, recursive: recursive))
      } else {
        result(nil)
      }

    case "readFile":
      if let args = call.arguments as? [String: Any],
         let filePath = args["filePath"] as? String {
        result(readFile(filePath: filePath))
      } else {
        result(nil)
      }

    case "getDirectoryDetails":
      if let args = call.arguments as? [String: Any],
         let directoryPath = args["directoryPath"] as? String {
        let recursive = args["recursive"] as? Bool ?? false
        result(getDirectoryDetails(directoryPath: directoryPath, recursive: recursive))
      } else {
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func selectDirectory(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let openPanel = NSOpenPanel()
      openPanel.canChooseDirectories = true
      openPanel.canChooseFiles = false
      openPanel.allowsMultipleSelection = false
      openPanel.title = "Select a folder"
      openPanel.prompt = "Choose"
      
      let response = openPanel.runModal()
      
      if response == NSApplication.ModalResponse.OK {
        if let url = openPanel.url {
          result(url.path)
        } else {
          result(nil)
        }
      } else {
        result(nil)
      }
    }
  }
  
  private func hasPermission(directoryPath: String) -> Bool {
    let url = URL(fileURLWithPath: directoryPath)
    
    // Check if directory exists
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      return false
    }
    
    // Check write permission by trying to create a temporary file
    let testFileName = ".write_test_" + UUID().uuidString
    let testFileURL = url.appendingPathComponent(testFileName)
    
    do {
      try "test".write(to: testFileURL, atomically: true, encoding: .utf8)
      try FileManager.default.removeItem(at: testFileURL)
      return true
    } catch {
      return false
    }
  }
  
  private func requestPermission(directoryPath: String) -> Bool {
    // On macOS, permissions are typically handled through file dialogs
    // or app sandboxing. This method is mainly for compatibility.
    return hasPermission(directoryPath: directoryPath)
  }
  
  private func writeFile(directoryPath: String, fileName: String, content: String) -> Bool {
    let dirURL = URL(fileURLWithPath: directoryPath)
    let fileURL = dirURL.appendingPathComponent(fileName)

    do {
      // Create directory if it doesn't exist
      try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)

      // Write file
      try content.write(to: fileURL, atomically: true, encoding: .utf8)
      return true
    } catch {
      print("Error writing file: \(error)")
      return false
    }
  }

  private func listDirectory(directoryPath: String, recursive: Bool) -> [String]? {
    let dirURL = URL(fileURLWithPath: directoryPath)

    do {
      var result: [String] = []
      try listDirectoryRecursive(url: dirURL, currentPath: "", result: &result, recursive: recursive)
      return result
    } catch {
      print("Error listing directory: \(error)")
      return nil
    }
  }

  private func listDirectoryRecursive(url: URL, currentPath: String, result: inout [String], recursive: Bool) throws {
    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [])

    for itemURL in contents {
      let fileName = itemURL.lastPathComponent
      let fullPath = currentPath.isEmpty ? fileName : "\(currentPath)/\(fileName)"

      result.append(fullPath)

      if recursive {
        let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey])
        if resourceValues.isDirectory == true {
          try listDirectoryRecursive(url: itemURL, currentPath: fullPath, result: &result, recursive: true)
        }
      }
    }
  }

  private func readFile(filePath: String) -> String? {
    let fileURL = URL(fileURLWithPath: filePath)

    do {
      let content = try String(contentsOf: fileURL, encoding: .utf8)
      return content
    } catch {
      print("Error reading file: \(error)")
      return nil
    }
  }

  private func getDirectoryDetails(directoryPath: String, recursive: Bool) -> [[String: Any]]? {
    let dirURL = URL(fileURLWithPath: directoryPath)

    do {
      var result: [[String: Any]] = []
      try getDirectoryDetailsRecursive(url: dirURL, basePath: directoryPath, currentPath: "", result: &result, recursive: recursive)
      return result
    } catch {
      print("Error getting directory details: \(error)")
      return nil
    }
  }

  private func getDirectoryDetailsRecursive(url: URL, basePath: String, currentPath: String, result: inout [[String: Any]], recursive: Bool) throws {
    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [
      .isDirectoryKey,
      .fileSizeKey,
      .contentModificationDateKey
    ], options: [])

    for itemURL in contents {
      let fileName = itemURL.lastPathComponent
      let fullPath = currentPath.isEmpty ? fileName : "\(currentPath)/\(fileName)"
      let absolutePath = "\(basePath)/\(fullPath)"

      let resourceValues = try itemURL.resourceValues(forKeys: [
        .isDirectoryKey,
        .fileSizeKey,
        .contentModificationDateKey
      ])

      let isDirectory = resourceValues.isDirectory ?? false
      let fileSize = resourceValues.fileSize ?? 0
      let lastModified = resourceValues.contentModificationDate?.timeIntervalSince1970 ?? 0

      let details: [String: Any] = [
        "name": fileName,
        "path": isDirectory ? itemURL.path : absolutePath,
        "isDirectory": isDirectory,
        "size": isDirectory ? 0 : fileSize,
        "lastModified": Int64(lastModified * 1000) // Convert to milliseconds
      ]

      result.append(details)

      if recursive && isDirectory {
        try getDirectoryDetailsRecursive(url: itemURL, basePath: basePath, currentPath: fullPath, result: &result, recursive: true)
      }
    }
  }
}
