// lib/services/media_downloader.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/download_progress.dart';
import 'package:common_ui/views/widgets/download_progress_dialog.dart';

class MediaDownloader {
  /// isVideo true ise Movies/Mostromo, false ise Pictures/Mostromo
  static Future<void> downloadMedia({
    required BuildContext context,
    required String url,
    required bool isVideo,
  }) async {
    // İzin kontrolü
    if (!await _checkPermission(context)) return;

    // Hedef klasör
    final Directory targetDir = isVideo
        ? Directory("/storage/emulated/0/Movies/Mostromo")
        : Directory("/storage/emulated/0/Pictures/Mostromo");

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final controller = StreamController<DownloadProgress>();

    // Progress dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DownloadProgressDialog(downloadStream: controller.stream),
    );

    double progressValue = 0;
    final fileName = url.split('/').last;

    FileDownloader.downloadFile(
      url: url,
      name: fileName,
      downloadDestination: DownloadDestinations.publicDownloads,
      onProgress: (fileName, progress) {
        progressValue = progress;
        controller.add(
          DownloadProgress(
            progress: progressValue,
            bytesDownloaded: (progressValue * 100).toInt(),
            totalBytes: 100,
          ),
        );
      },
      onDownloadCompleted: (path) async {
        try {
          final File downloaded = File(path);
          final File finalFile = await downloaded.copy(
            "${targetDir.path}/$fileName",
          );

          controller.add(
            DownloadProgress(
              progress: 1.0,
              bytesDownloaded: 100,
              totalBytes: 100,
              isCompleted: true,
              filePath: finalFile.path,
            ),
          );
          controller.close();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("İndirme tamamlandı: ${finalFile.path}")),
          );
        } catch (e) {
          controller.close();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Dosya kaydedilemedi: $e")));
        }
      },
      onDownloadError: (error) {
        controller.close();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("İndirme hatası: $error")));
      },
    );
  }

  static Future<bool> _checkPermission(BuildContext context) async {
    if (await Permission.manageExternalStorage.isGranted) return true;

    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Depolama izni reddedildi")));
    return false;
  }
}
