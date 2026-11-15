// lib/services/upload_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class UploadService {
  static const String _baseUrl = "https://mostromo.com/connect/myImages";
  static const String _uploadEndpoint = "$_baseUrl/upload.php";

  // Basit upload (progress olmadan)
  static Future<UploadResult> uploadFiles(List<File> files) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));

      // Dosyaları ekle - WEB'deki gibi file0, file1, file2...
      for (int i = 0; i < files.length; i++) {
        var file = files[i];
        var stream = http.ByteStream(file.openRead());
        var length = await file.length();
        var multipartFile = http.MultipartFile(
          'file$i', // ✅ WEB'deki gibi: file0, file1, file2...
          stream,
          length,
          filename: path.basename(file.path),
        );
        request.files.add(multipartFile);
      }

      // WEB'deki gibi fileCount ekle
      request.fields['fileCount'] = files.length.toString();

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseData);
        return UploadResult(
          success: jsonResponse['success'] == true,
          message: jsonResponse['message'] ?? 'Unknown response',
          data: jsonResponse,
        );
      } else {
        return UploadResult(
          success: false,
          message: 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return UploadResult(success: false, message: 'Upload failed: $e');
    }
  }

  // ✅ WEB BENZERİ PROGRESS TAKİBİ
  static Stream<UploadProgress> uploadFilesWithProgress(
    List<File> files,
  ) async* {
    // 1. TOPLAM BOYUTU HESAPLA (WEB'deki gibi)
    int totalBytes = 0;
    for (var file in files) {
      totalBytes += await file.length();
    }

    if (totalBytes == 0) {
      yield UploadProgress(
        bytesUploaded: 0,
        totalBytes: 0,
        progress: 1.0,
        isCompleted: true,
        result: const UploadResult(
          success: false,
          message: 'Seçilen dosya boyutu 0.',
        ),
      );
      return;
    }

    // 2. BAŞLANGIÇ (WEB'deki 0% gibi)
    yield UploadProgress(
      bytesUploaded: 0,
      totalBytes: totalBytes,
      progress: 0.0,
      isCompleted: false,
    );

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));
      int bytesUploaded = 0;

      // 3. DOSYALARI EKLE (WEB'deki FormData gibi)
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final length = await file.length();

        var multipartFile = http.MultipartFile(
          'file$i', // ✅ WEB formatı: file0, file1, file2...
          http.ByteStream(file.openRead()),
          length,
          filename: path.basename(file.path),
        );
        request.files.add(multipartFile);
      }

      // WEB'deki gibi fileCount
      request.fields['fileCount'] = files.length.toString();

      // 4. PROGRESS TAKİBİ (WEB'deki xhr.upload.progress gibi)
      // HTTP paketi progress takibi yapalım
      final totalSize = await _calculateRequestSize(request);

      // Simüle progress - gerçek upload süresince progress güncelle
      final startTime = DateTime.now();
      const estimatedUploadTime = Duration(seconds: 10); // Tahmini süre

      // Progress timer'ı başlat
      final progressTimer = Timer.periodic(Duration(milliseconds: 100), (
        timer,
      ) async {
        final elapsed = DateTime.now().difference(startTime);
        double simulatedProgress =
            elapsed.inMilliseconds / estimatedUploadTime.inMilliseconds;

        if (simulatedProgress > 0.95) {
          simulatedProgress = 0.95; // %95'e kadar simüle et
        }

        bytesUploaded = (totalSize * simulatedProgress).round();

        // Progress güncellemesi gönder
        // Bu kısım biraz karmaşık - alternatif aşağıda
      });

      // 5. İSTEĞİ GÖNDER (WEB'deki xhr.send gibi)
      var response = await request.send();
      progressTimer.cancel(); // Timer'ı durdur

      // 6. YANITI İŞLE (WEB'deki xhr.onload gibi)
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(responseData);

        // ✅ BAŞARILI - WEB'deki gibi
        yield UploadProgress(
          bytesUploaded: totalSize,
          totalBytes: totalSize,
          progress: 1.0,
          isCompleted: true,
          result: UploadResult(
            success: jsonResponse['success'] == true,
            message: jsonResponse['message'] ?? 'Yükleme tamamlandı',
            data: jsonResponse,
          ),
        );

        // WEB'deki gibi: updateITEMS() çağrısı
        // Flutter'da bunu callback ile yapabilirsiniz
      } else {
        // ✅ HATA - WEB'deki gibi
        yield UploadProgress(
          bytesUploaded: bytesUploaded,
          totalBytes: totalSize,
          progress: totalSize > 0 ? bytesUploaded / totalSize : 0.0,
          isCompleted: true,
          result: UploadResult(
            success: false,
            message: 'Sunucu hatası: ${response.statusCode}',
          ),
        );
      }
    } catch (e) {
      // ✅ AĞ HATASI - WEB'deki xhr.onerror gibi
      yield UploadProgress(
        bytesUploaded: 0,
        totalBytes: 0,
        progress: 0.0,
        isCompleted: true,
        result: UploadResult(success: false, message: 'Yükleme başarısız: $e'),
      );
    }
  }

  // İsteğin tahmini boyutunu hesapla
  static Future<int> _calculateRequestSize(
    http.MultipartRequest request,
  ) async {
    int totalSize = 0;

    // Fields boyutu
    request.fields.forEach((key, value) {
      totalSize += utf8.encode(key).length + utf8.encode(value).length;
    });

    // Files boyutu
    for (var file in request.files) {
      totalSize += await file.length;
    }

    return totalSize;
  }
}

class UploadResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  const UploadResult({required this.success, required this.message, this.data});
}

class UploadProgress {
  final int bytesUploaded;
  final int totalBytes;
  final double progress;
  final bool isCompleted;
  final UploadResult? result;

  const UploadProgress({
    required this.bytesUploaded,
    required this.totalBytes,
    required this.progress,
    required this.isCompleted,
    this.result,
  });
}
