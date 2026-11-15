// lib/models/folder_model.dart

class FolderItem {
  final int folderId;
  final String folderName;
  final int parentId; // Bu klasörün "üst" klasörünün ID'si (0 = Ana Dizin)

  // 🌟 YENİ: Çöp Kutusu Durumu
  final bool isTrashed;

  FolderItem({
    required this.folderId,
    required this.folderName,
    required this.parentId,
    this.isTrashed = false, // 🌟 Varsayılan olarak çöpte değil
  });

  /// Nesneyi kopyalayıp sadece bazı alanlarını değiştirmek için kullanılır.
  FolderItem copyWith({
    int? folderId,
    String? folderName,
    int? parentId,
    bool? isTrashed,
  }) {
    return FolderItem(
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      parentId: parentId ?? this.parentId,
      isTrashed: isTrashed ?? this.isTrashed,
    );
  }

  /// PHP'den veya SQLite'tan gelen JSON verisini FolderItem'a dönüştürür
  factory FolderItem.fromJson(Map<String, dynamic> json) {
    return FolderItem(
      // GÜVENLİ PARSE: Gelen veri int de olsa String de olsa güvenle çevrilir.
      folderId: int.tryParse(json['folder_id']?.toString() ?? '0') ?? 0,
      folderName: json['folder_name']?.toString() ?? 'İsimsiz Klasör',
      parentId: int.tryParse(json['parent_id']?.toString() ?? '0') ?? 0,

      // 🌟 YENİ: PHP'den gelen is_trashed verisini parse et
      isTrashed:
          json['is_trashed'] == 1 ||
          json['is_trashed'] == true ||
          json['is_trashed'] == "1",
    );
  }

  /// Lokal depolama veya veritabanı (Map) için dönüştürür
  Map<String, dynamic> toJson() {
    return {
      'folder_id': folderId,
      'folder_name': folderName,
      'parent_id': parentId,
      'is_trashed': isTrashed ? 1 : 0, // 🌟 JSON'a Eklendi
    };
  }

  // Set ve List içinde doğru karşılaştırma yapabilmek için
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderItem &&
          runtimeType == other.runtimeType &&
          folderId == other.folderId &&
          folderName == other.folderName &&
          parentId == other.parentId &&
          isTrashed == other.isTrashed; // 🌟 Karşılaştırmaya Eklendi

  @override
  int get hashCode =>
      folderId.hashCode ^
      folderName.hashCode ^
      parentId.hashCode ^
      isTrashed.hashCode; // 🌟 Hash'e Eklendi
}
