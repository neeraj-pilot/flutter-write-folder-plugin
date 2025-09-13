import Flutter
import UIKit
import UniformTypeIdentifiers

public class EnteDirectoryPickerPlugin: NSObject, FlutterPlugin {
  private var pendingResult: FlutterResult?
  private var selectedDirectoryURL: URL?
  private var viewController: UIViewController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ente_directory_picker", binaryMessenger: registrar.messenger())
    let instance = EnteDirectoryPickerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // Get the root view controller from the first connected scene
    if #available(iOS 13.0, *) {
      if let windowScene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first,
         let window = windowScene.windows.first {
        instance.viewController = window.rootViewController
      }
    } else {
      if let window = UIApplication.shared.windows.first {
        instance.viewController = window.rootViewController
      }
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
      
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
    guard let viewController = self.viewController else {
      result(nil)
      return
    }
    
    let documentPicker: UIDocumentPickerViewController
    
    if #available(iOS 14.0, *) {
      documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
    } else {
      documentPicker = UIDocumentPickerViewController(documentTypes: ["public.folder"], in: .open)
    }
    
    documentPicker.allowsMultipleSelection = false
    if #available(iOS 13.0, *) {
      documentPicker.shouldShowFileExtensions = true
    }
    documentPicker.delegate = self
    
    self.pendingResult = result
    
    DispatchQueue.main.async {
      viewController.present(documentPicker, animated: true)
    }
  }
  
  private func hasPermission(directoryPath: String) -> Bool {
    guard let url = URL(string: directoryPath) else { return false }
    
    // Check if we can start accessing the security scoped resource
    let isSecurityScoped = url.startAccessingSecurityScopedResource()
    
    if isSecurityScoped {
      let hasAccess = FileManager.default.isWritableFile(atPath: url.path)
      url.stopAccessingSecurityScopedResource()
      return hasAccess
    }
    
    return false
  }
  
  private func requestPermission(directoryPath: String) -> Bool {
    // For iOS, permissions are handled through the document picker
    // This method is mainly for compatibility with other platforms
    return hasPermission(directoryPath: directoryPath)
  }
  
  private func writeFile(directoryPath: String, fileName: String, content: String) -> Bool {
    guard let dirURL = URL(string: directoryPath) else { return false }

    let isSecurityScoped = dirURL.startAccessingSecurityScopedResource()

    defer {
      if isSecurityScoped {
        dirURL.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let fileURL = dirURL.appendingPathComponent(fileName)
      let data = content.data(using: .utf8) ?? Data()

      try data.write(to: fileURL)
      return true
    } catch {
      print("Error writing file: \(error)")
      return false
    }
  }

  private func listDirectory(directoryPath: String, recursive: Bool) -> [String]? {
    guard let dirURL = URL(string: directoryPath) else { return nil }

    let isSecurityScoped = dirURL.startAccessingSecurityScopedResource()

    defer {
      if isSecurityScoped {
        dirURL.stopAccessingSecurityScopedResource()
      }
    }

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
    guard let fileURL = URL(string: filePath) else { return nil }

    let isSecurityScoped = fileURL.startAccessingSecurityScopedResource()

    defer {
      if isSecurityScoped {
        fileURL.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let content = try String(contentsOf: fileURL, encoding: .utf8)
      return content
    } catch {
      print("Error reading file: \(error)")
      return nil
    }
  }

  private func getDirectoryDetails(directoryPath: String, recursive: Bool) -> [[String: Any]]? {
    guard let dirURL = URL(string: directoryPath) else { return nil }

    let isSecurityScoped = dirURL.startAccessingSecurityScopedResource()

    defer {
      if isSecurityScoped {
        dirURL.stopAccessingSecurityScopedResource()
      }
    }

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
        "path": isDirectory ? itemURL.absoluteString : absolutePath,
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

// MARK: - UIDocumentPickerDelegate
extension EnteDirectoryPickerPlugin: UIDocumentPickerDelegate {
  public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else {
      pendingResult?(nil)
      pendingResult = nil
      return
    }
    
    // Save the selected directory for future use
    selectedDirectoryURL = url
    
    // Return the URL string
    pendingResult?(url.absoluteString)
    pendingResult = nil
  }
  
  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingResult?(nil)
    pendingResult = nil
  }
}
