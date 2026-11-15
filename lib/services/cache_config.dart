// lib/services/cache_config.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'image_memory_cache.dart';

class CacheConfig {
  static final CustomCacheManager _cacheManager = CustomCacheManager();

  static void setup() {
    CachedNetworkImage.logLevel =
        CacheManagerLogLevel.warning; // Debug yerine warning
  }

  static Widget cachedImage({
    required String imageUrl,
    required BuildContext context,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    bool isThumbnail = false,
  }) {
    // Önce memory cache'den kontrol et
    final cachedImageProvider = ImageMemoryCache.get(imageUrl);
    if (cachedImageProvider != null) {
      return Image(
        image: cachedImageProvider,
        fit: fit,
        width: width,
        height: height,
        filterQuality: FilterQuality.low, // Kaliteyi düşür
      );
    }

    // Thumbnail için boyutları optimize et
    final int? memCacheWidth = isThumbnail ? 200 : null; // Daha küçük thumbnail
    final int? memCacheHeight = isThumbnail ? 200 : null;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxHeightDiskCache: isThumbnail ? 400 : null, // Disk cache'i sınırla
      maxWidthDiskCache: isThumbnail ? 400 : null,
      cacheManager: _cacheManager,
      cacheKey: _generateCacheKey(imageUrl, isThumbnail),
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      imageBuilder: (context, imageProvider) {
        // Resim yüklendikten sonra memory cache'e kaydet
        if (isThumbnail) {
          ImageMemoryCache.put(imageUrl, imageProvider);
        }
        return Image(
          image: imageProvider,
          fit: fit,
          width: width,
          height: height,
          filterQuality: FilterQuality.low, // Kaliteyi düşür
        );
      },
    );
  }

  static Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ),
    );
  }

  static Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.broken_image, size: 24, color: Colors.red),
    );
  }

  static String _generateCacheKey(String url, bool isThumbnail) {
    final uri = Uri.parse(url);
    final thumbnailSuffix = isThumbnail ? '_thumb' : '_full';
    return '${uri.path}_${uri.query}$thumbnailSuffix';
  }

  // Cache temizleme metodu
  static Future<void> clearCache() async {
    await _cacheManager.emptyCache();
    ImageMemoryCache.clear();
  }
}

// Özel Cache Manager
class CustomCacheManager extends CacheManager {
  static const key = 'customImageCache';
  static const Duration maxAgeCache = Duration(days: 7); // Cache süresini azalt
  static const int maxNrOfCacheObjects = 100; // Cache objesi sayısını sınırla

  CustomCacheManager()
    : super(
        Config(
          key,
          stalePeriod: maxAgeCache,
          maxNrOfCacheObjects: maxNrOfCacheObjects,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ),
      );
}



/*

// lib/services/cache_config.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import './image_memory_cache.dart';

class CacheConfig {
  static void setup() {
    CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;
  }

  static Widget cachedImage({
    required String imageUrl,
    required BuildContext context,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    bool isThumbnail = true,
  }) {
    // Önce memory cache'den kontrol et
    final cachedImageProvider = ImageMemoryCache.get(imageUrl);

    if (cachedImageProvider != null) {
      return Image(
        image: cachedImageProvider,
        fit: fit,
        width: width,
        height: height,
      );
    }

    // Memory cache'de yoksa CachedNetworkImage kullan
    final cacheWidth = isThumbnail ? 300 : null;
    final cacheHeight = isThumbnail ? 300 : null;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: cacheWidth,
      memCacheHeight: cacheHeight,
      maxHeightDiskCache: cacheHeight,
      maxWidthDiskCache: cacheWidth,
      cacheKey: _generateCacheKey(imageUrl),
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[200],
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
      imageBuilder: (context, imageProvider) {
        // Resim yüklendikten sonra memory cache'e kaydet
        ImageMemoryCache.put(imageUrl, imageProvider);
        return Image(
          image: imageProvider,
          fit: fit,
          width: width,
          height: height,
        );
      },
    );
  }

  static String _generateCacheKey(String url) {
    final uri = Uri.parse(url);
    return '${uri.path}_${uri.query}';
  }
}
*/