// lib/services/upload_file_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // kDebugMode için

// Sonucun ne olduğunu tanımlayan sınıf (değişiklik yok)
class UploadFileResult {
  final bool success;
  final String message;
  final List<String>? uploadedUrls;

  UploadFileResult({
    required this.success,
    required this.message,
    this.uploadedUrls,
  });
}

class UploadFileService {
  static const String _uploadEndpoint =
      "https://mostromo.com/connect/android/upload.php";

  // ✅ DÜZELTME 1: 'folderId' parametresi buraya eklendi
  static Future<UploadFileResult> uploadFilesWithProgress(
    List<File> files, {
    String uploadLocation = "myStorage",
    int folderId = 0, // Varsayılan olarak Ana Dizin (0)
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (files.isEmpty) {
        return UploadFileResult(
          success: false,
          message: "Yüklenecek dosya yok.",
        );
      }

      var dio = Dio();
      List<MultipartFile> multipartFiles = [];
      for (var file in files) {
        multipartFiles.add(
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        );
      }

      // ✅ DÜZELTME 2: 'folder_id' FormData'ya eklendi
      var formData = FormData.fromMap({
        "files[]": multipartFiles,
        "uploadLocation": uploadLocation,
        "folder_id": folderId, // PHP'nin beklediği anahtar
      });

      var response = await dio.post(
        _uploadEndpoint,
        data: formData,
        onSendProgress: (int sent, int total) {
          if (total > 0 && onProgress != null) {
            double progress = (sent / total).clamp(0.0, 1.0);
            onProgress(progress);
          }
        },
        options: Options(responseType: ResponseType.json),
      );

      // Yanıt işleme (değişiklik yok)
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData;
        if (response.data is String) {
          responseData = json.decode(response.data) as Map<String, dynamic>;
        } else {
          responseData = response.data as Map<String, dynamic>;
        }
        return UploadFileResult(
          success: responseData['success'] ?? false,
          message: responseData['message'] ?? 'Bilinmeyen yanıt.',
          uploadedUrls: (responseData['uploadedUrls'] as List<dynamic>?)
              ?.map((url) => url.toString())
              .toList(),
        );
      } else {
        if (kDebugMode) {
          print("Sunucu hatası: ${response.statusCode} - ${response.data}");
        }
        return UploadFileResult(
          success: false,
          message: "Sunucu hatası: ${response.statusCode}",
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Yükleme Servisi Hatası: $e");
      }
      return UploadFileResult(success: false, message: "Hata: $e");
    }
  }
}
