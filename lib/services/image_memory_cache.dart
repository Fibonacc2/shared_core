/*


// lib/services/image_memory_cache.dart
import 'package:flutter/widgets.dart';
import 'dart:collection';

class ImageMemoryCache {
  static final LinkedHashMap<String, ImageProvider> _cache = LinkedHashMap();
  static const int _maxSize = 200; // Max 200 resim memory'de tutulsun

  static ImageProvider? get(String url) {
    if (_cache.containsKey(url)) {
      // LRU cache - kullanılanı en başa taşı
      final imageProvider = _cache.remove(url);
      _cache[url] = imageProvider!;
      debugPrint('🎯 Memory Cache HIT: $url');
      return imageProvider;
    }
    debugPrint('❌ Memory Cache MISS: $url');
    return null;
  }

  static void put(String url, ImageProvider imageProvider) {
    if (_cache.length >= _maxSize) {
      // En eski elemanı sil (LRU)
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
      debugPrint('🧹 Removed from cache: $firstKey');
    }
    _cache[url] = imageProvider;
    debugPrint('💾 Memory Cache STORED: $url (Total: ${_cache.length})');
  }

  static void clear() {
    _cache.clear();
    debugPrint('🗑️ Memory Cache CLEARED');
  }

  static int get size => _cache.length;
}

*/

// lib/services/image_memory_cache.dart

import 'package:flutter/widgets.dart';
import 'dart:collection';

class ImageMemoryCache {
  static final LinkedHashMap<String, ImageProvider> _cache = LinkedHashMap();
  static const int _maxSize = 10; // Max 100 resim (daha az memory)
  static const int _cleanupThreshold = 3; // Temizleme eşiği

  static ImageProvider? get(String url) {
    if (_cache.containsKey(url)) {
      // LRU cache - kullanılanı en başa taşı
      final imageProvider = _cache.remove(url);
      _cache[url] = imageProvider!;
      return imageProvider;
    }
    return null;
  }

  static void put(String url, ImageProvider imageProvider) {
    // Cache boyut kontrolü
    if (_cache.length >= _maxSize) {
      // En eski elemanları sil (ilk %20'sini temizle)
      final keysToRemove = _cache.keys.take((_maxSize * 0.2).floor()).toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }

    _cache[url] = imageProvider;
  }

  static void cleanup() {
    // Periyodik temizlik - ilk %30'unu temizle
    if (_cache.length > _cleanupThreshold) {
      final keysToRemove = _cache.keys
          .take((_cache.length * 0.3).floor())
          .toList();
      for (final key in keysToRemove) {
        _cache.remove(key);
      }
    }
  }

  static void clear() {
    _cache.clear();
  }

  static int get size => _cache.length;

  // Debug için cache durumu
  static void printCacheStatus() {
    debugPrint('📊 Memory Cache Status: ${_cache.length}/$_maxSize items');
  }
}
