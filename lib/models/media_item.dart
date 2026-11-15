class MediaItem {
  final String id;
  final String fileType;
  final String creationDate;
  final String? imageURL;
  final String? imageWebp;
  final String? imageWebpMini;
  final String? videoURL;
  final String? videoPoster;
  final String uploadDate;
  final String fileSize;

  MediaItem({
    required this.id,
    required this.fileType,
    required this.creationDate,
    this.imageURL,
    this.imageWebp,
    this.imageWebpMini,
    this.videoURL,
    this.videoPoster,
    required this.uploadDate,
    required this.fileSize,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] ?? '',
      fileType: json['file_type'] ?? '',
      creationDate: json['creationDate'] ?? '',
      imageURL: json['imageURL'],
      imageWebp: json['imageWebp'],
      imageWebpMini: json['imageWebpMini'],
      videoURL: json['videoURL'],
      videoPoster: json['videoPoster'],
      uploadDate: json['uploadDate'] ?? '',
      fileSize: json['file_Size'] ?? '',
    );
  }

  // copyWith metodu eklenmeli
  MediaItem copyWith({
    String? id,
    String? fileType,
    String? creationDate,
    String? imageURL,
    String? imageWebp,
    String? imageWebpMini,
    String? videoURL,
    String? videoPoster,
    String? uploadDate,
    String? fileSize,
  }) {
    return MediaItem(
      id: id ?? this.id,
      fileType: fileType ?? this.fileType,
      creationDate: creationDate ?? this.creationDate,
      imageURL: imageURL ?? this.imageURL,
      imageWebp: imageWebp ?? this.imageWebp,
      imageWebpMini: imageWebpMini ?? this.imageWebpMini,
      videoURL: videoURL ?? this.videoURL,
      videoPoster: videoPoster ?? this.videoPoster,
      uploadDate: uploadDate ?? this.uploadDate,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  // toString metodu (debug için faydalı)
  @override
  String toString() {
    return 'MediaItem(id: $id, fileType: $fileType, creationDate: $creationDate)';
  }

  // equality kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
