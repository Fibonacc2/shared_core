import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_group.dart';
import '../models/media_item.dart';

// Sayfa seçimi için
//final ValueNotifier<int> selectedPageNotifier = ValueNotifier<int>(1);
final ValueNotifier<bool> namimi = ValueNotifier<bool>(false);

// Tema ID tutucu
final ValueNotifier<int> selectedTheme = ValueNotifier<int>(0);

// Diğer notifiers
final ValueNotifier<MediaItem?> selectedImageNotifier =
    ValueNotifier<MediaItem?>(null);

final ValueNotifier<List<MediaGroup>?> cachedMediaGroupsNotifier =
    ValueNotifier<List<MediaGroup>?>(null);

final ValueNotifier<bool> isLoadingMediaNotifier = ValueNotifier<bool>(false);
final ValueNotifier<String?> mediaErrorNotifier = ValueNotifier<String?>(null);

// SharedPreferences anahtarı
const _themeKey = 'selectedThemeId';

// Tema kaydet
Future<void> saveSelectedTheme(int id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_themeKey, id);
}

// Tema yükle
Future<void> loadSelectedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getInt(_themeKey) ?? 0;
  selectedTheme.value = id;
}

// Değişiklikleri otomatik kaydet
void initThemeListener() {
  selectedTheme.addListener(() {
    saveSelectedTheme(selectedTheme.value);
  });
}
