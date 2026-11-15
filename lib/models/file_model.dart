// lib/models/file_model.dart

// Sunucunuzun ana adresini (kök URL) buraya yazın
const String API_BASE_URL = "https://mostromo.com/connect/";

class FileItem {
  final String fileName;
  final String fileType;
  final String fileUrl; // Bu her zaman tam URL olacak
  final String createdAt;
  final String? lastUpdated;
  final String? webpUrl;
  final String? webpExtraUrl;
  final int fileSize;
  final String fileExtension;
  final int folderId;

  // 🌟 YENİ: Çöp Kutusu Durumu
  final bool isTrashed;

  FileItem({
    required this.fileName,
    required this.fileType,
    required this.fileUrl,
    required this.createdAt,
    this.lastUpdated,
    this.webpUrl,
    this.webpExtraUrl,
    required this.fileSize,
    required this.fileExtension,
    required this.folderId,
    this.isTrashed = false, // 🌟 Varsayılan olarak çöpte değil
  });

  /// Nesneyi kopyalayıp sadece bazı alanlarını değiştirmek için kullanılır.
  FileItem copyWith({
    String? fileName,
    String? fileType,
    String? fileUrl,
    String? createdAt,
    String? lastUpdated,
    String? webpUrl,
    String? webpExtraUrl,
    int? fileSize,
    String? fileExtension,
    int? folderId,
    bool? isTrashed, // 🌟 Eklendi
  }) {
    return FileItem(
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      webpUrl: webpUrl ?? this.webpUrl,
      webpExtraUrl: webpExtraUrl ?? this.webpExtraUrl,
      fileSize: fileSize ?? this.fileSize,
      fileExtension: fileExtension ?? this.fileExtension,
      folderId: folderId ?? this.folderId,
      isTrashed: isTrashed ?? this.isTrashed, // 🌟 Eklendi
    );
  }

  /// API'den gelen JSON verisini FileItem nesnesine dönüştürür.
  factory FileItem.fromJson(Map<String, dynamic> json) {
    /// Göreceli URL'yi tam (absolute) URL'ye çeviren yardımcı fonksiyon.
    String makeAbsolute(String? relativeUrl) {
      if (relativeUrl == null || relativeUrl.isEmpty) {
        return '';
      }
      if (relativeUrl.startsWith('http')) {
        return relativeUrl;
      }
      if (relativeUrl.startsWith('/')) {
        relativeUrl = relativeUrl.substring(1);
      }
      return API_BASE_URL + relativeUrl;
    }

    return FileItem(
      fileName: json['file_Name'] ?? '',
      fileType: json['file_Type'] ?? 'other',

      fileUrl: makeAbsolute(json['file_URL']),
      webpUrl: json['webp_URL'] != null ? makeAbsolute(json['webp_URL']) : null,
      webpExtraUrl: json['webp_extra_URL'] != null
          ? makeAbsolute(json['webp_extra_URL'])
          : null,

      createdAt: json['createdDate'] ?? '',
      lastUpdated: json['lastUpdated'],

      fileSize: int.tryParse(json['file_Size']?.toString() ?? '0') ?? 0,
      fileExtension: json['file_Extension'] ?? '',
      folderId: int.tryParse(json['folder_id']?.toString() ?? '0') ?? 0,

      // 🌟 YENİ: PHP'den gelen is_trashed verisini (1, "1" veya true) güvenle Bool'a çevir
      isTrashed:
          json['is_trashed'] == 1 ||
          json['is_trashed'] == true ||
          json['is_trashed'] == "1",
    );
  }

  /// FileItem nesnesini (lokal veritabanı için) JSON'a dönüştürür.
  Map<String, dynamic> toJson() {
    return {
      'file_Name': fileName,
      'file_Type': fileType,
      'file_URL': fileUrl,
      'createdDate': createdAt,
      'lastUpdated': lastUpdated,
      'webp_URL': webpUrl,
      'webp_extra_URL': webpExtraUrl,
      'file_Size': fileSize,
      'file_Extension': fileExtension,
      'folder_id': folderId,
      'is_trashed': isTrashed ? 1 : 0, // 🌟 JSON'a Eklendi
    };
  }

  // Eşitlik kontrolü (Set yapısında doğru çalışması için önemli)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileItem &&
          runtimeType == other.runtimeType &&
          fileUrl == other.fileUrl &&
          fileName == other.fileName &&
          folderId == other.folderId &&
          lastUpdated == other.lastUpdated &&
          isTrashed == other.isTrashed; // 🌟 Karşılaştırmaya Eklendi

  @override
  int get hashCode =>
      fileUrl.hashCode ^
      fileName.hashCode ^
      folderId.hashCode ^
      lastUpdated.hashCode ^
      isTrashed.hashCode; // 🌟 Hash'e Eklendi
}
