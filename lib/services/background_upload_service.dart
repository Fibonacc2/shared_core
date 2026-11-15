// packages/shared_core/lib/services/background_upload_service.dart

import 'dart:io';
import 'dart:async';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

class BackgroundUploadService {
  // Singleton Yapısı
  static final BackgroundUploadService _instance =
      BackgroundUploadService._internal();
  factory BackgroundUploadService() => _instance;

  BackgroundUploadService._internal() {
    _init();
  }

  // İlerlemeyi ve Durumu dışarıya (Controller'a) duyurmak için Stream'ler
  final _progressController = StreamController<TaskProgressUpdate>.broadcast();
  Stream<TaskProgressUpdate> get progressStream => _progressController.stream;

  final _statusController = StreamController<TaskStatusUpdate>.broadcast();
  Stream<TaskStatusUpdate> get statusStream => _statusController.stream;

  void _init() {
    // Yapılandırma (Timeout vb.)
    FileDownloader().configure(
      globalConfig: [
        (
          Config.requestTimeout,
          const Duration(seconds: 600),
        ), // 10 dakika timeout
      ],
    );

    // Global dinleyici
    FileDownloader().updates.listen((update) {
      if (update is TaskStatusUpdate) {
        _statusController.add(update);
        if (kDebugMode)
          print('📦 Durum: ${update.status} (Task: ${update.task.taskId})');
      } else if (update is TaskProgressUpdate) {
        _progressController.add(update);
        // İlerleme logunu çok sık basmamak için kDebugMode kontrolü
        // if (kDebugMode) print('🚀 İlerleme: ${(update.progress * 100).toInt()}%');
      }
    });
  }

  /// Dosyaları yükleme kuyruğuna ekler.
  /// [files]: Yüklenecek dosyaların listesi
  /// [url]: Yüklemenin yapılacağı API adresi (Drive veya Images için farklı olabilir)
  /// [fields]: Sunucuya gönderilecek ek parametreler (folder_id, vb.)
  Future<List<String>> enqueueUploads({
    required List<File> files,
    required String url,
    required Map<String, String> fields,
  }) async {
    List<String> taskIds = [];

    for (var file in files) {
      final fileName = file.path.split(Platform.pathSeparator).last;

      // Her dosya için benzersiz bir ID oluştur
      final taskId = "${fileName}_${DateTime.now().millisecondsSinceEpoch}";

      final task = UploadTask(
        taskId: taskId,
        url: url, // ✅ Dinamik URL
        filename: fileName,
        baseDirectory:
            BaseDirectory.root, // Tam dosya yolu kullanacağımız için root
        directory: file.parent.path, // Dosyanın bulunduğu klasör
        updates: Updates.statusAndProgress, // Hem durum hem ilerleme bildir
        // ✅ GÜNCELLENMİŞ PARAMETRELER (v9+)
        httpRequestMethod: 'POST',

        // Sunucuya gidecek ek veriler (folder_id vb.)
        fields: fields,

        // PHP tarafındaki $_FILES['files'] karşılığı
        fileField: 'files[]',

        priority: 10,
      );

      // Görevi kuyruğa ekle
      final enqueued = await FileDownloader().enqueue(task);

      if (enqueued) {
        taskIds.add(taskId);
        if (kDebugMode) print("✅ Görev kuyruğa alındı: $taskId -> $url");
      } else {
        if (kDebugMode) print("❌ Görev kuyruğa alınamadı: $fileName");
      }
    }
    return taskIds;
  }

  /// Tüm aktif ve bekleyen görevleri iptal eder
  Future<void> cancelAll() async {
    // ✅ GÜNCELLENMİŞ METOD (v9+)
    await FileDownloader().cancelAll();
  }
}
