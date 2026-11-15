// packages/shared_core/lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/notifiers.dart';
import '../models/media_group.dart';

class ApiService {
  // Mostromo Images için doğru klasör yolu
  static const String baseUrl = "https://mostromo.com/connect/myImages";

  static Future<List<MediaGroup>> fetchGroupedMedia(
    int page,
    int userID,
  ) async {
    // 🌟 DÜZELTME 1: getImages.php olarak güncellendi ve userID parametresi sabitlendi
    final url = "$baseUrl/getImages_android.php?page=$page&userID=$userID";
    debugPrint("📡 API İstek URL: $url");

    final response = await http.get(Uri.parse(url));

    debugPrint("📥 API Yanıt Kodu: ${response.statusCode}");
    debugPrint("📥 API Yanıt Body: ${response.body}");

    if (response.statusCode == 200) {
      // PHP'nin X-Total-Count başlığından tüm kullanıcı medyalarının sayısını al.
      // Eski backend sürümleriyle geçici uyumluluk için başlık yoksa null kalır.
      totalMediaCountNotifier.value =
          int.tryParse(response.headers['x-total-count'] ?? '');

      // Eğer PHP boş dizi [] döndürürse hata vermemesi için kontrol
      if (response.body.trim() == "[]" || response.body.trim().isEmpty) {
        return [];
      }

      final Map<String, dynamic> data = json.decode(response.body);
      List<MediaGroup> groups = [];
      data.forEach((date, items) {
        groups.add(MediaGroup.fromJson(date, items));
      });
      return groups;
    } else {
      throw Exception("Medya yüklenemedi (Kod: ${response.statusCode})");
    }
  }

  static Future<void> fetchAndCacheGroupedMedia({
    required int userId, // Parametre adı dışarıdan gelenle uyumlu
    int page = 1,
    bool loadMore = false,
  }) async {
    if (isLoadingMediaNotifier.value) return;

    try {
      isLoadingMediaNotifier.value = true;
      mediaErrorNotifier.value = null;

      // 🌟 DÜZELTME 2: userId, büyük harfli userID'ye hatasız aktarılıyor
      final newGroups = await fetchGroupedMedia(page, userId);

      if (loadMore && cachedMediaGroupsNotifier.value != null) {
        final existingList = List<MediaGroup>.from(
          cachedMediaGroupsNotifier.value!,
        );

        for (var newGroup in newGroups) {
          final existingGroupIndex = existingList.indexWhere(
            (g) => g.date == newGroup.date,
          );
          if (existingGroupIndex != -1) {
            existingList[existingGroupIndex].items.addAll(newGroup.items);
          } else {
            existingList.add(newGroup);
          }
        }
        cachedMediaGroupsNotifier.value = existingList;
      } else {
        cachedMediaGroupsNotifier.value = newGroups;
      }
    } catch (e) {
      debugPrint("❌ fetchAndCacheGroupedMedia Hatası: $e");
      mediaErrorNotifier.value = e.toString();
      rethrow;
    } finally {
      isLoadingMediaNotifier.value = false;
    }
  }
}
