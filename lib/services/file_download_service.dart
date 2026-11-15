// services/file_download_service.dart

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';

// FileItem modelinizin yolunu import edin
import '../models/file_model.dart';

class FileDownloadService {
  /// Gerekli izinleri (Tüm Dosyalara Erişim ve Bildirim) ister.
  static Future<bool> _requestPermissions() async {
    // 1. ADIM: Bildirim İzni
    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        debugPrint("Bildirim izni verilmedi (yine de indirme denenecek).");
      }
    }

    // 2. ADIM: "Tüm Dosyalara Erişim" İzni
    final storageStatus = await Permission.manageExternalStorage.request();
    if (!storageStatus.isGranted) {
      debugPrint("MANAGE_EXTERNAL_STORAGE (Tüm Dosyalar) izni reddedildi.");
      return false; // Depolama izni olmadan devam edilemez.
    }

    return true;
  }

  // ❌ 'path_provider' kullanan _getDownloadDirectoryPath fonksiyonu SİLİNDİ.

  /// Bir indirme görevini başlatmak için sıraya alır.
  static Future<String?> requestDownload(FileItem file) async {
    // 1. ADIM: İzinleri iste.
    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      return "Depolama izni (Tüm Dosyalara Erişim) verilmediği için indirme başlatılamadı.";
    }

    // 2. ADIM: SABİT İNDİRME YOLUNU BELİRLE (path_provider'sız)
    // 'flutter_downloader' bu yolun var olmasını bekler.
    const String downloadPath = "/storage/emulated/0/Download";

    try {
      final Directory downloadDir = Directory(downloadPath);
      // Bu klasörün var olduğundan EMİN OL (yoksa 'savedDir does not exist' hatası alırsın)
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint("İndirme klasörü oluşturulamadı: $e");
      return "İndirme klasörüne erişilemedi (path: $downloadPath)";
    }

    // 3. ADIM: URL'nin tam olduğundan emin ol. (Bu zaten çalışıyordu)
    if (!file.fileUrl.startsWith('http')) {
      final errorMessage =
          'İndirme URL\'si geçersiz. Tam bir URL (http://...) gereklidir. Gelen URL: ${file.fileUrl}';
      debugPrint(errorMessage);
      return errorMessage;
    }

    // 4. ADIM: flutter_downloader ile indirme görevini sıraya al.
    try {
      final taskId = await FlutterDownloader.enqueue(
        url: file.fileUrl,
        savedDir: downloadPath, // Artık '/storage/emulated/0/Download'
        fileName: file.fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );

      if (taskId != null) {
        debugPrint(
          'İndirme sıraya alındı. Görev ID: $taskId, Kayıt Yolu: $downloadPath/${file.fileName}',
        );
        return null; // Başarılı
      } else {
        return 'İndirme görevi sıraya alınamadı (görev ID\'si alınamadı).';
      }
    } catch (e) {
      debugPrint('flutter_downloader.enqueue hatası: $e');
      return 'İndirme sırasında bir hata oluştu: $e';
    }
  }
}
