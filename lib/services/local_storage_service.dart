import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_model.dart';
import '../models/folder_model.dart'; // ✅ YENİ: Klasör modelini import et

// ✅ YENİ: Hem klasörleri hem dosyaları bir arada tutan yardımcı sınıf
class SyncedData {
  final List<FolderItem> folders;
  final List<FileItem> files;

  SyncedData({
    this.folders = const [], // Varsayılan olarak boş liste
    this.files = const [], // Varsayılan olarak boş liste
  });
}

class LocalStorageService {
  // ✅ GÜNCELLENDİ: Anahtarın adını "local_all_data" olarak değiştirdim
  static const String _localDataKey = 'local_all_data';
  static const String _lastSyncKey = 'last_sync';

  // ✅ GÜNCELLENDİ: Artık 'List<FileItem>' yerine 'SyncedData' döndürüyor
  static Future<SyncedData> loadLocalData() async {
    try {
      if (kDebugMode) {
        print('📱 Local storage yükleniyor...');
      }
      final prefs = await SharedPreferences.getInstance();
      // Yeni anahtarı oku
      final dataJson = prefs.getString(_localDataKey);

      if (dataJson != null) {
        // ✅ GÜNCELLENDİ: Artık 'List' yerine 'Map' olarak decode ediyoruz
        final Map<String, dynamic> dataMap = json.decode(dataJson);

        final List<dynamic> foldersList = dataMap['folders'] ?? [];
        final List<dynamic> filesList = dataMap['files'] ?? [];

        if (kDebugMode) {
          print(
            '📱 Local storage: ${foldersList.length} klasör, ${filesList.length} dosya bulundu',
          );
        }

        // SyncedData nesnesi olarak döndür
        return SyncedData(
          folders: foldersList
              .map((item) => FolderItem.fromJson(item))
              .toList(),
          files: filesList.map((item) => FileItem.fromJson(item)).toList(),
        );
      } else {
        if (kDebugMode) {
          print('📱 Local storage: Veri bulunamadı');
        }
        return SyncedData(); // Boş veri döndür
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Local storage yükleme hatası: $e');
      }
      return SyncedData(); // Hata durumunda boş veri döndür
    }
  }

  // ✅ GÜNCELLENDİ: Artık 'List<FileItem>' yerine 'SyncedData' alıyor
  static Future<void> saveLocalData(SyncedData data) async {
    try {
      if (kDebugMode) {
        print(
          '💾 Local storage kaydediliyor: ${data.folders.length} klasör, ${data.files.length} dosya',
        );
      }
      final prefs = await SharedPreferences.getInstance();

      // ✅ GÜNCELLENDİ: Veriyi 'Map' olarak hazırla
      final dataMap = {
        'folders': data.folders.map((folder) => folder.toJson()).toList(),
        'files': data.files.map((file) => file.toJson()).toList(),
      };

      // Map'i JSON string'ine çevir
      final dataJson = json.encode(dataMap);

      await prefs.setString(_localDataKey, dataJson); // Yeni anahtara kaydet
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

      if (kDebugMode) {
        print('💾 Local storage başarıyla kaydedildi');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Local storage kaydetme hatası: $e');
      }
      throw e;
    }
  }

  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_lastSyncKey);
      return lastSync != null ? DateTime.parse(lastSync) : null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Last sync time hatası: $e');
      }
      return null;
    }
  }
}
