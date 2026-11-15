class DownloadProgress {
  final double progress;
  final int bytesDownloaded;
  final int totalBytes;
  final bool isCompleted;
  final String? filePath;

  DownloadProgress({
    required this.progress,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.isCompleted = false,
    this.filePath,
  });
}
