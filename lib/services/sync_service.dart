/*

// lib/features/storage/services/sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import 'local_storage_service.dart';
import 'file_api_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final bool hasChanges;
  final List<FolderItem> folders;
  final List<FileItem> files;

  SyncResult({
    required this.success,
    required this.message,
    required this.hasChanges,
    this.folders = const [],
    this.files = const [],
  });
}

class SyncService {
  static Stream<String> get syncStatusStream => _syncController.stream;
  static final StreamController<String> _syncController =
      StreamController<String>.broadcast();
  static bool _isControllerClosed = false;

  static Future<bool> checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  static Future<SyncResult> syncFiles() async {
    SyncedData localData = SyncedData();
    SyncedData apiData = SyncedData();

    try {
      _addSyncStatus('🔄 Sync başlatılıyor...');
      final hasConnection = await checkInternetConnection();
      if (!hasConnection) {
        _addSyncStatus('❌ İnternet bağlantısı yok');
        localData = await LocalStorageService.loadLocalData();
        return SyncResult(
          success: false,
          message: 'İnternet bağlantısı yok',
          hasChanges: false,
          folders: localData.folders,
          files: localData.files,
        );
      }

      localData = await LocalStorageService.loadLocalData();
      apiData = await FileApiService.fetchFilesFromDatabase();

      if (_hasChanges(localData, apiData)) {
        await LocalStorageService.saveLocalData(apiData);
        _addSyncStatus('✅ Veriler güncellendi ✓');
        return SyncResult(
          success: true,
          message: 'Senkronize edildi',
          hasChanges: true,
          folders: apiData.folders,
          files: apiData.files,
        );
      } else {
        _addSyncStatus('✅ Veriler güncel ✓');
        return SyncResult(
          success: true,
          message: 'Zaten güncel',
          hasChanges: false,
          folders: localData.folders,
          files: localData.files,
        );
      }
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Hata: $e',
        hasChanges: false,
        folders: localData.folders,
        files: localData.files,
      );
    }
  }

  // 🌟 PARÇALI YÜKLEME MOTORU (0 Byte Hatası Çözüldü)
  static Future<bool> uploadFileInChunks({
    required File file,
    required int folderId,
    required Function(double) onProgress,
  }) async {
    const int chunkSize = 2 * 1024 * 1024;
    final int fileSize = await file.length();

    // 🌟 SİHİRLİ DOKUNUŞ: Dosya boyutu 0 ise bile döngü 1 kere çalışır!
    final int totalChunks = fileSize == 0 ? 1 : (fileSize / chunkSize).ceil();
    final String fileName = path.basename(file.path);
    final String uploadId =
        DateTime.now().millisecondsSinceEpoch.toString() +
        "_" +
        fileName.replaceAll(" ", "_");

    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSize;
      final int end = (start + chunkSize > fileSize)
          ? fileSize
          : start + chunkSize;

      List<int> chunkBytes = [];

      // Dosyanın içi boş değilse RAM'e oku
      if (fileSize > 0) {
        final stream = file.openRead(start, end);
        chunkBytes = await stream.expand((x) => x).toList();
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://mostromo.com/connect/android/upload_chunk.php"),
      );
      request.fields['folder_id'] = folderId.toString();
      request.fields['file_name'] = fileName;
      request.fields['chunk_index'] = i.toString();
      request.fields['total_chunks'] = totalChunks.toString();
      request.fields['upload_id'] = uploadId;

      request.files.add(
        http.MultipartFile.fromBytes(
          'chunk_data',
          chunkBytes,
          filename: 'chunk_$i',
        ),
      );

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          double progress = (i + 1) / totalChunks;
          onProgress(progress);
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  static const String _deleteEndpoint =
      "https://mostromo.com/connect/android/delete_file.php";
  static Future<bool> deleteFile(FileItem file) async {
    String relativeFileUrl = file.fileUrl.replaceFirst(API_BASE_URL, '');
    try {
      final response = await http.post(
        Uri.parse(_deleteEndpoint),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_url': relativeFileUrl,
          'webp_url': file.webpUrl?.replaceFirst(API_BASE_URL, ''),
          'webp_extra_url': file.webpExtraUrl?.replaceFirst(API_BASE_URL, ''),
        }),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['success'] == true;
      return false;
    } catch (e) {
      return false;
    }
  }

  static const String _createFolderEndpoint =
      "https://mostromo.com/connect/android/create_folder.php";
  static Future<FolderItem?> createFolder(
    String folderName,
    int parentId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_createFolderEndpoint),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({'folder_name': folderName, 'parent_id': parentId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['new_folder'] != null) {
          return FolderItem.fromJson(data['new_folder']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> deleteFolder(FolderItem folder) async {
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/delete_folder.php"),
        body: {'folder_id': folder.folderId.toString()},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return null;
        return data['message'] ?? "Sunucu klasörü silemedi.";
      }
      return "HTTP Hatası: ${response.statusCode}";
    } catch (e) {
      return "Bağlantı hatası oluştu. Klasör silinemedi.";
    }
  }

  static const String _renameFolderEndpoint =
      "https://mostromo.com/connect/android/rename_folder.php";
  static Future<FolderItem?> renameFolder(
    FolderItem folder,
    String newName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_renameFolderEndpoint),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'folder_id': folder.folderId,
          'new_folder_name': newName,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true)
          return FolderItem(
            folderId: folder.folderId,
            folderName: newName,
            parentId: folder.parentId,
          );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static const String _moveItemsEndpoint =
      "https://mostromo.com/connect/android/move_items.php";
  static Future<String?> moveItems({
    required List<FolderItem> folders,
    required List<FileItem> files,
    required int targetFolderId,
  }) async {
    final List<String> fileUrls = files
        .map((file) => file.fileUrl.replaceFirst(API_BASE_URL, ''))
        .toList();
    final List<int> folderIds = folders
        .map((folder) => folder.folderId)
        .toList();
    try {
      final response = await http.post(
        Uri.parse(_moveItemsEndpoint),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_urls': fileUrls,
          'folder_ids': folderIds,
          'target_folder_id': targetFolderId,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return null;
        return data['message'];
      }
      return "Sunucu hatası";
    } catch (e) {
      return "Bağlantı hatası";
    }
  }

  static const String _renameFileEndpoint =
      "https://mostromo.com/connect/android/rename_file.php";
  static Future<FileItem?> renameFile(FileItem file, String newName) async {
    try {
      final response = await http.post(
        Uri.parse(_renameFileEndpoint),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_url': file.fileUrl.replaceFirst(API_BASE_URL, ''),
          'new_file_name': newName,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true)
          return file.copyWith(
            fileName: newName,
            fileExtension: newName.split('.').last,
          );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==========================================================================
  // 🌟 GERİ DÖNÜŞÜM KUTUSU İŞLEMLERİ (TRASH & RESTORE)
  // ==========================================================================
  static const String _trashItemsEndpoint =
      "https://mostromo.com/connect/android/trash_items.php";

  // Çöpe atar
  static Future<bool> trashItems({
    required List<FolderItem> folders,
    required List<FileItem> files,
  }) async {
    _addSyncStatus('Geri dönüşüme taşınıyor...');
    final fileUrls = files
        .map((f) => f.fileUrl.replaceFirst(API_BASE_URL, ''))
        .toList();
    final folderIds = folders.map((f) => f.folderId).toList();

    try {
      final response = await http.post(
        Uri.parse(_trashItemsEndpoint),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_urls': fileUrls,
          'folder_ids': folderIds,
          'action': 'trash',
        }),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['success'] == true;
      return false;
    } catch (e) {
      return false;
    }
  }

  // Çöpten çıkartır (Geri Yükler)
  static Future<bool> restoreItems({
    required List<FolderItem> folders,
    required List<FileItem> files,
  }) async {
    _addSyncStatus('Öğeler geri yükleniyor...');
    final fileUrls = files
        .map((f) => f.fileUrl.replaceFirst(API_BASE_URL, ''))
        .toList();
    final folderIds = folders.map((f) => f.folderId).toList();

    try {
      final response = await http.post(
        Uri.parse(_trashItemsEndpoint),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_urls': fileUrls,
          'folder_ids': folderIds,
          'action': 'restore',
        }),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['success'] == true;
      return false;
    } catch (e) {
      return false;
    }
  }

  static void _addSyncStatus(String status) {
    if (!_isControllerClosed && !_syncController.isClosed)
      _syncController.add(status);
  }

  static bool _hasChanges(SyncedData localData, SyncedData apiData) {
    if (!setEquals(localData.folders.toSet(), apiData.folders.toSet()))
      return true;
    if (!setEquals(localData.files.toSet(), apiData.files.toSet())) return true;
    return false;
  }

  static void dispose() {
    if (!_isControllerClosed) {
      _isControllerClosed = true;
      if (!_syncController.isClosed) _syncController.close();
    }
  }
}
*/

// lib/features/storage/services/sync_service.dart

// lib/features/storage/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart';
import 'local_storage_service.dart';
import 'file_api_service.dart';

class SyncResult {
  final bool success;
  final String message;
  final bool hasChanges;
  final List<FolderItem> folders;
  final List<FileItem> files;

  SyncResult({
    required this.success,
    required this.message,
    required this.hasChanges,
    this.folders = const [],
    this.files = const [],
  });
}

class SyncService {
  static Stream<String> get syncStatusStream => _syncController.stream;
  static final StreamController<String> _syncController =
      StreamController<String>.broadcast();
  static bool _isControllerClosed = false;

  static Future<bool> checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  static Future<SyncResult> syncFiles({required int userId}) async {
    SyncedData localData = SyncedData();
    SyncedData apiData = SyncedData();

    try {
      _addSyncStatus('🔄 Sync başlatılıyor...');
      final hasConnection = await checkInternetConnection();
      if (!hasConnection) {
        _addSyncStatus('❌ İnternet bağlantısı yok');
        localData = await LocalStorageService.loadLocalData();
        return SyncResult(
          success: false,
          message: 'İnternet bağlantısı yok',
          hasChanges: false,
          folders: localData.folders,
          files: localData.files,
        );
      }

      localData = await LocalStorageService.loadLocalData();

      // 🌟 API'ye userId gidiyor!
      apiData = await FileApiService.fetchFilesFromDatabase(userId: userId);

      if (_hasChanges(localData, apiData)) {
        await LocalStorageService.saveLocalData(apiData);
        _addSyncStatus('✅ Veriler güncellendi ✓');
        return SyncResult(
          success: true,
          message: 'Senkronize edildi',
          hasChanges: true,
          folders: apiData.folders,
          files: apiData.files,
        );
      } else {
        _addSyncStatus('✅ Veriler güncel ✓');
        return SyncResult(
          success: true,
          message: 'Zaten güncel',
          hasChanges: false,
          folders: localData.folders,
          files: localData.files,
        );
      }
    } catch (e) {
      // 🌟 Hata varsa ekrana yansıtmak için mesajı döndürüyoruz!
      return SyncResult(
        success: false,
        message: '$e',
        hasChanges: false,
        folders: localData.folders,
        files: localData.files,
      );
    }
  }

  static Future<bool> uploadFileInChunks({
    required File file,
    required int folderId,
    required int userId,
    required Function(double) onProgress,
  }) async {
    if (userId == 0) return false;
    const int chunkSize = 2 * 1024 * 1024;
    final int fileSize = await file.length();
    final int totalChunks = fileSize == 0 ? 1 : (fileSize / chunkSize).ceil();
    final String fileName = path.basename(file.path);
    final String uploadId =
        DateTime.now().millisecondsSinceEpoch.toString() +
        "_" +
        fileName.replaceAll(" ", "_");

    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSize;
      final int end = (start + chunkSize > fileSize)
          ? fileSize
          : start + chunkSize;
      List<int> chunkBytes = [];

      if (fileSize > 0) {
        final stream = file.openRead(start, end);
        chunkBytes = await stream.expand((x) => x).toList();
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://mostromo.com/connect/android/upload_chunk.php"),
      );
      request.fields['folder_id'] = folderId.toString();
      request.fields['file_name'] = fileName;
      request.fields['chunk_index'] = i.toString();
      request.fields['total_chunks'] = totalChunks.toString();
      request.fields['upload_id'] = uploadId;
      request.fields['user_id'] = userId.toString();

      request.files.add(
        http.MultipartFile.fromBytes(
          'chunk_data',
          chunkBytes,
          filename: 'chunk_$i',
        ),
      );

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          double progress = (i + 1) / totalChunks;
          onProgress(progress);
        } else {
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  static Future<bool> deleteFile(FileItem file, {required int userId}) async {
    String relativeFileUrl = file.fileUrl.replaceFirst(API_BASE_URL, '');
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/delete_file.php"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_url': relativeFileUrl,
          'webp_url': file.webpUrl?.replaceFirst(API_BASE_URL, ''),
          'webp_extra_url': file.webpExtraUrl?.replaceFirst(API_BASE_URL, ''),
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['success'] == true;
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<FolderItem?> createFolder(
    String folderName,
    int parentId, {
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/create_folder.php"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'folder_name': folderName,
          'parent_id': parentId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['new_folder'] != null) {
          return FolderItem.fromJson(data['new_folder']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> deleteFolder(
    FolderItem folder, {
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/delete_folder.php"),
        body: {
          'folder_id': folder.folderId.toString(),
          'user_id': userId.toString(),
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return null;
        return data['message'] ?? "Sunucu klasörü silemedi.";
      }
      return "HTTP Hatası: ${response.statusCode}";
    } catch (e) {
      return "Bağlantı hatası oluştu.";
    }
  }

  static Future<FolderItem?> renameFolder(
    FolderItem folder,
    String newName, {
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/rename_folder.php"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'folder_id': folder.folderId,
          'new_folder_name': newName,
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return FolderItem(
            folderId: folder.folderId,
            folderName: newName,
            parentId: folder.parentId,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> moveItems({
    required List<FolderItem> folders,
    required List<FileItem> files,
    required int targetFolderId,
    required int userId,
  }) async {
    final List<String> fileUrls = files
        .map((file) => file.fileUrl.replaceFirst(API_BASE_URL, ''))
        .toList();
    final List<int> folderIds = folders
        .map((folder) => folder.folderId)
        .toList();
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/move_items.php"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_urls': fileUrls,
          'folder_ids': folderIds,
          'target_folder_id': targetFolderId,
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) return null;
        return data['message'];
      }
      return "Sunucu hatası";
    } catch (e) {
      return "Bağlantı hatası";
    }
  }

  static Future<FileItem?> renameFile(
    FileItem file,
    String newName, {
    required int userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/rename_file.php"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_url': file.fileUrl.replaceFirst(API_BASE_URL, ''),
          'new_file_name': newName,
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return file.copyWith(
            fileName: newName,
            fileExtension: newName.split('.').last,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> trashItems({
    required List<FolderItem> folders,
    required List<FileItem> files,
    required int userId,
  }) async {
    _addSyncStatus('Geri dönüşüme taşınıyor...');
    final fileUrls = files
        .map((f) => f.fileUrl.replaceFirst(API_BASE_URL, ''))
        .toList();
    final folderIds = folders.map((f) => f.folderId).toList();

    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/trash_items.php"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_urls': fileUrls,
          'folder_ids': folderIds,
          'action': 'trash',
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['success'] == true;
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> restoreItems({
    required List<FolderItem> folders,
    required List<FileItem> files,
    required int userId,
  }) async {
    _addSyncStatus('Öğeler geri yükleniyor...');
    final fileUrls = files
        .map((f) => f.fileUrl.replaceFirst(API_BASE_URL, ''))
        .toList();
    final folderIds = folders.map((f) => f.folderId).toList();

    try {
      final response = await http.post(
        Uri.parse("https://mostromo.com/connect/android/trash_items.php"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: json.encode({
          'file_urls': fileUrls,
          'folder_ids': folderIds,
          'action': 'restore',
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200)
        return json.decode(response.body)['success'] == true;
      return false;
    } catch (e) {
      return false;
    }
  }

  static void _addSyncStatus(String status) {
    if (!_isControllerClosed && !_syncController.isClosed)
      _syncController.add(status);
  }

  static bool _hasChanges(SyncedData localData, SyncedData apiData) {
    if (!setEquals(localData.folders.toSet(), apiData.folders.toSet()))
      return true;
    if (!setEquals(localData.files.toSet(), apiData.files.toSet())) return true;
    return false;
  }

  static void dispose() {
    if (!_isControllerClosed) {
      _isControllerClosed = true;
      if (!_syncController.isClosed) _syncController.close();
    }
  }
}
