/***
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/file_model.dart';
import '../models/folder_model.dart'; // ✅ YENİ: Klasör modelini import et
// ✅ YENİ: 'SyncedData' sınıfını kullanmak için
import 'local_storage_service.dart';

class FileApiService {
  static const String baseUrl =
      'https://mostromo.com/connect'; // Kendi domain'iniz

  // ✅ GÜNCELLENDİ: Artık 'List<FileItem>' yerine 'SyncedData' döndürüyor
  static Future<SyncedData> fetchFilesFromDatabase() async {
    try {
      print('🔗 API: Database bağlantısı kuruluyor...');

      // ✅ GÜNCELLENDİ: PHP betiğinin yolu
      final response = await http
          .get(
            Uri.parse('$baseUrl/android/get_all_data.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          // ✅ GÜNCELLENDİ: Hem klasörleri hem dosyaları parse et
          final List<dynamic> foldersData = data['folders'] ?? [];
          final List<dynamic> filesData = data['files'] ?? [];

          print(
            '✅ API: ${foldersData.length} klasör, ${filesData.length} dosya başarıyla alındı',
          );

          // SyncedData nesnesi olarak döndür
          return SyncedData(
            folders: foldersData
                .map((item) => FolderItem.fromJson(item))
                .toList(),
            files: filesData.map((item) => FileItem.fromJson(item)).toList(),
          );
        } else {
          final errorMessage = data['message'] ?? 'Bilinmeyen API hatası';
          print('❌ API Hatası: $errorMessage');
          throw Exception('API hatası: $errorMessage');
        }
      } else {
        print('❌ HTTP Hatası: ${response.statusCode}');
        throw Exception(
          'HTTP hatası: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Database bağlantı hatası: $e');
      throw e;
    }
  }
}
*/
// lib/services/file_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/file_model.dart';
import '../models/folder_model.dart';
import 'local_storage_service.dart';

class FileApiService {
  static const String baseUrl = 'https://mostromo.com/connect';

  static Future<SyncedData> fetchFilesFromDatabase({
    required int userId,
  }) async {
    try {
      if (kDebugMode) print('🔗 API: Veriler Çekiliyor... (UserID: $userId)');

      if (userId == 0) {
        if (kDebugMode) print('❌ API: userId 0 olduğu için istek atılmadı.');
        return SyncedData(folders: [], files: []);
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/android/get_all_data.php'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('📡 API Yanıt Kodu: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          // 🌟 SİHİRLİ DOKUNUŞ BURADA: PHP'den gelen listeleri güvenli şekilde alıyoruz
          final List<dynamic> rawFolders = data['folders'] ?? [];
          final List<dynamic> rawFiles = data['files'] ?? [];

          // 🌟 DART İÇİN TİP ZORLAMASI YAPIYORUZ (List.from)
          return SyncedData(
            folders: List<FolderItem>.from(
              rawFolders.map(
                (item) => FolderItem.fromJson(item as Map<String, dynamic>),
              ),
            ),
            files: List<FileItem>.from(
              rawFiles.map(
                (item) => FileItem.fromJson(item as Map<String, dynamic>),
              ),
            ),
          );
        } else {
          throw Exception('${data['message']}');
        }
      } else {
        throw Exception('HTTP hatası: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('❌ API Fırlatılan Hata: $e');
      throw e;
    }
  }
}
