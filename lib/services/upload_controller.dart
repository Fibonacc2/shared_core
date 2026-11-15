// packages/shared_core/lib/services/upload_controller.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart'; // 🌟 YENİ: Güçlü ve stabil HTTP motoru

class UploadController extends ChangeNotifier {
  final String uploadUrl;
  final Map<String, String> additionalFields;

  final List<PlatformFile> _selectedFiles = [];
  bool _isUploading = false;
  double _currentProgress = 0.0;
  bool _isDisposed = false;

  UploadController({required this.uploadUrl, this.additionalFields = const {}});

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  List<PlatformFile> get selectedFiles => _selectedFiles;
  bool get isUploading => _isUploading;
  double get currentProgress => _currentProgress;

  Future<int> pickFiles() async {
    if (_isUploading) return 0;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result != null) {
        _selectedFiles.addAll(result.files);
        _safeNotifyListeners();
        return result.files.length;
      }
      return 0;
    } catch (e) {
      debugPrint("Dosya seçme hatası: $e");
      return 0;
    }
  }

  Future<void> addFilesFromPaths(List<String> filePaths) async {
    if (_isUploading) return;
    for (final path in filePaths) {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        final name = path.split(Platform.pathSeparator).last;
        _selectedFiles.add(PlatformFile(name: name, size: size, path: path));
      }
    }
    _safeNotifyListeners();
  }

  void clearAll() {
    if (_isUploading) return;
    _selectedFiles.clear();
    _safeNotifyListeners();
  }

  void removeFileAt(int index) {
    if (_isUploading) return;
    if (index >= 0 && index < _selectedFiles.length) {
      _selectedFiles.removeAt(index);
      _safeNotifyListeners();
    }
  }

  String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const units = ["B", "KB", "MB", "GB", "TB"];
    final digitGroups = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, digitGroups)).toStringAsFixed(1)} ${units[digitGroups]}";
  }

  // ==========================================================================
  // 🌟 "CHUNKED" DİO UPLOAD MOTORU (Web'deki upload.php ile %100 Uyumlu)
  // ==========================================================================
  Future<void> uploadFiles() async {
    if (_selectedFiles.isEmpty || _isUploading) return;

    _isUploading = true;
    _currentProgress = 0.0;
    _safeNotifyListeners();

    try {
      final dio = Dio();
      const int chunkSize =
          2 * 1024 * 1024; // Web tarafındaki gibi 2 MB'lık parçalar
      int totalFiles = _selectedFiles.length;
      int completedFiles = 0;

      for (var file in _selectedFiles.toList()) {
        if (file.path == null) continue;

        final File localFile = File(file.path!);
        final int fileSize = await localFile.length();

        final int totalChunks = fileSize == 0
            ? 1
            : (fileSize / chunkSize).ceil();
        final String fileName = file.name;

        for (int i = 0; i < totalChunks; i++) {
          final int start = i * chunkSize;
          final int end = (start + chunkSize > fileSize)
              ? fileSize
              : start + chunkSize;

          final stream = localFile.openRead(start, end);
          final List<int> chunkBytes = await stream.expand((x) => x).toList();

          final formDataMap = {
            "name": fileName,
            "chunk": i,
            "chunks": totalChunks,
            "file": MultipartFile.fromBytes(chunkBytes, filename: fileName),
          };

          additionalFields.forEach((key, value) {
            formDataMap[key] = value.toString();
          });

          final formData = FormData.fromMap(formDataMap);

          final response = await dio.post(
            uploadUrl,
            data: formData,
            options: Options(
              responseType: ResponseType
                  .plain, // 🌟 YENİ: Dio'nun otomatik parse işlemini durdur
            ),
            onSendProgress: (int sent, int total) {
              if (total > 0) {
                double chunkProgress = (i + (sent / total)) / totalChunks;
                _currentProgress =
                    (completedFiles + chunkProgress) / totalFiles;
                _safeNotifyListeners();
              }
            },
          );

          // 🌟 YENİ: Manuel Parse ve Hata Yakalama Zırhı
          String rawData = response.data.toString();
          Map<String, dynamic> responseData;

          try {
            responseData = jsonDecode(rawData) as Map<String, dynamic>;
          } on FormatException catch (_) {
            // PHP gizli bir hata (HTML vs) gönderdiyse terminale bas!
            debugPrint(
              "🔥 PHP'DEN GELEN RAW HATA (GÖRÜNMEZ KARAKTER VEYA KOD HATASI):",
            );
            debugPrint(rawData);
            throw Exception("Sunucudan geçersiz JSON yanıtı geldi.");
          }

          if (response.statusCode == 200 && responseData['success'] == true) {
            if (i == totalChunks - 1) {
              debugPrint("✅ Dosya sunucuda başarıyla birleşti: $fileName");
              _selectedFiles.remove(file);
            } else {
              debugPrint("⏳ Parça yüklendi: ${i + 1}/$totalChunks - $fileName");
            }
          } else {
            debugPrint("❌ Sunucu hatası veya reddi: $rawData");
            throw Exception("Parça yüklenemedi: $fileName");
          }
        }

        completedFiles++;
        _currentProgress = completedFiles / totalFiles;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Yükleme Hatası (Chunked Dio): $e");
    } finally {
      _isUploading = false;
      _currentProgress = 1.0;
      _safeNotifyListeners();
    }
  }
}
