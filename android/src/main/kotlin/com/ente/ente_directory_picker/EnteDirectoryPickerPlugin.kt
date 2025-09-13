package com.ente.ente_directory_picker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** EnteDirectoryPickerPlugin */
class EnteDirectoryPickerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private var context: Context? = null
  private var pendingResult: Result? = null
  private var requestCode = 0

  companion object {
    private const val REQUEST_CODE_SELECT_DIRECTORY = 1001
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ente_directory_picker")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "selectDirectory" -> {
        selectDirectory(result)
      }
      "hasPermission" -> {
        val directoryPath = call.argument<String>("directoryPath")
        result.success(hasPermission(directoryPath))
      }
      "requestPermission" -> {
        val directoryPath = call.argument<String>("directoryPath")
        result.success(requestPermission(directoryPath))
      }
      "writeFile" -> {
        val directoryPath = call.argument<String>("directoryPath")
        val fileName = call.argument<String>("fileName")
        val content = call.argument<String>("content")
        if (directoryPath != null && fileName != null && content != null) {
          result.success(writeFile(directoryPath, fileName, content))
        } else {
          result.success(false)
        }
      }
      "listDirectory" -> {
        val directoryPath = call.argument<String>("directoryPath")
        val recursive = call.argument<Boolean>("recursive") ?: false
        if (directoryPath != null) {
          result.success(listDirectory(directoryPath, recursive))
        } else {
          result.success(null)
        }
      }
      "readFile" -> {
        val filePath = call.argument<String>("filePath")
        if (filePath != null) {
          result.success(readFile(filePath))
        } else {
          result.success(null)
        }
      }
      "getDirectoryDetails" -> {
        val directoryPath = call.argument<String>("directoryPath")
        val recursive = call.argument<Boolean>("recursive") ?: false
        if (directoryPath != null) {
          result.success(getDirectoryDetails(directoryPath, recursive))
        } else {
          result.success(null)
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun selectDirectory(result: Result) {
    if (activity == null) {
      result.success(null)
      return
    }

    try {
      val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
        flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
               Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
               Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
      }
      
      pendingResult = result
      requestCode = REQUEST_CODE_SELECT_DIRECTORY
      activity?.startActivityForResult(intent, REQUEST_CODE_SELECT_DIRECTORY)
    } catch (e: Exception) {
      result.success(null)
    }
  }

  private fun hasPermission(directoryPath: String?): Boolean {
    if (directoryPath == null || context == null) return false
    
    return try {
      val uri = Uri.parse(directoryPath)
      val documentFile = DocumentFile.fromTreeUri(context!!, uri)
      documentFile?.exists() == true && documentFile.canWrite()
    } catch (e: Exception) {
      false
    }
  }

  private fun requestPermission(directoryPath: String?): Boolean {
    // For SAF, permissions are handled through the directory selection process
    // This method is mainly for compatibility with other platforms
    return hasPermission(directoryPath)
  }

  private fun writeFile(directoryPath: String, fileName: String, content: String): Boolean {
    if (context == null) return false

    return try {
      val uri = Uri.parse(directoryPath)
      val documentFile = DocumentFile.fromTreeUri(context!!, uri) ?: return false
      
      if (!documentFile.canWrite()) return false

      // Check if file already exists, if so delete it first
      val existingFile = documentFile.findFile(fileName)
      existingFile?.delete()

      // Create new file
      val newFile = documentFile.createFile("text/plain", fileName) ?: return false
      
      context!!.contentResolver.openOutputStream(newFile.uri)?.use { outputStream ->
        outputStream.write(content.toByteArray())
        outputStream.flush()
      }
      
      true
    } catch (e: Exception) {
      false
    }
  }

  private fun listDirectory(directoryPath: String, recursive: Boolean): List<String>? {
    if (context == null) return null

    return try {
      val uri = Uri.parse(directoryPath)
      val documentFile = DocumentFile.fromTreeUri(context!!, uri) ?: return null
      
      val result = mutableListOf<String>()
      listDirectoryRecursive(documentFile, "", result, recursive)
      result
    } catch (e: Exception) {
      null
    }
  }

  private fun listDirectoryRecursive(directory: DocumentFile, currentPath: String, result: MutableList<String>, recursive: Boolean) {
    directory.listFiles().forEach { file ->
      val fileName = file.name ?: "unknown"
      val fullPath = if (currentPath.isEmpty()) fileName else "$currentPath/$fileName"
      
      result.add(fullPath)
      
      if (recursive && file.isDirectory) {
        listDirectoryRecursive(file, fullPath, result, true)
      }
    }
  }

  private fun readFile(filePath: String): String? {
    if (context == null) return null

    return try {
      val uri = Uri.parse(filePath)
      context!!.contentResolver.openInputStream(uri)?.use { inputStream ->
        inputStream.bufferedReader().use { reader ->
          reader.readText()
        }
      }
    } catch (e: Exception) {
      null
    }
  }

  private fun getDirectoryDetails(directoryPath: String, recursive: Boolean): List<HashMap<String, Any>>? {
    if (context == null) return null

    return try {
      val uri = Uri.parse(directoryPath)
      val documentFile = DocumentFile.fromTreeUri(context!!, uri) ?: return null
      
      val result = mutableListOf<HashMap<String, Any>>()
      getDirectoryDetailsRecursive(documentFile, directoryPath, "", result, recursive)
      result
    } catch (e: Exception) {
      null
    }
  }

  private fun getDirectoryDetailsRecursive(
    directory: DocumentFile, 
    basePath: String,
    currentPath: String, 
    result: MutableList<HashMap<String, Any>>, 
    recursive: Boolean
  ) {
    directory.listFiles().forEach { file ->
      val fileName = file.name ?: "unknown"
      val fullPath = if (currentPath.isEmpty()) fileName else "$currentPath/$fileName"
      val absolutePath = "$basePath/$fullPath"
      
      val details = hashMapOf<String, Any>(
        "name" to fileName,
        "path" to if (file.isDirectory) file.uri.toString() else absolutePath,
        "isDirectory" to file.isDirectory,
        "size" to file.length(),
        "lastModified" to file.lastModified()
      )
      
      result.add(details)
      
      if (recursive && file.isDirectory) {
        getDirectoryDetailsRecursive(file, basePath, fullPath, result, true)
      }
    }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode == REQUEST_CODE_SELECT_DIRECTORY && pendingResult != null) {
      if (resultCode == Activity.RESULT_OK && data?.data != null) {
        val uri = data.data!!
        
        // Take persistable permission
        try {
          context?.contentResolver?.takePersistableUriPermission(
            uri, 
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
          )
          pendingResult?.success(uri.toString())
        } catch (e: Exception) {
          pendingResult?.success(null)
        }
      } else {
        pendingResult?.success(null)
      }
      
      pendingResult = null
      return true
    }
    return false
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
