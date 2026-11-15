import 'media_item.dart';

class MediaGroup {
  final String date; // ör: "22 Eylül 2025 Pazartesi"
  final List<MediaItem> items;

  MediaGroup({required this.date, required this.items});

  factory MediaGroup.fromJson(String date, List<dynamic> jsonList) {
    return MediaGroup(
      date: date,
      items: jsonList.map((e) => MediaItem.fromJson(e)).toList(),
    );
  }
}
