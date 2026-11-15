// lib/services/media_api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MediaApiService {
  static const String baseUrl = 'https://mostromo.com/connect/myImages';

  static Future<bool> updateCreationDate({
    required String mediaItemId,
    required DateTime newDate,
  }) async {
    try {
      // Tarihi doğru ISO8601 formatına çevir (Zulu time olmadan)
      final isoDate = _formatDateForApi(newDate);

      if (kDebugMode) {
        print('Gönderilen tarih: $isoDate');
      } // Debug için

      final response = await http.post(
        Uri.parse('$baseUrl/update_creationDate_android.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'media_id': mediaItemId, 'creation_date': isoDate}),
      );

      if (kDebugMode) {
        print('API Response: ${response.statusCode} - ${response.body}');
      } // Debug için

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] == true;
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        if (kDebugMode) {
          print('Client hatası: ${error['error']}');
        }
        return false;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('API hatası: $e');
      }
      rethrow;
    }
  }

  // Tarihi PHP'nin anlayacağı ISO8601 formatına çevir
  static String _formatDateForApi(DateTime date) {
    // YYYY-MM-DDTHH:mm:ss formatında (Zulu time olmadan)
    String year = date.year.toString().padLeft(4, '0');
    String month = date.month.toString().padLeft(2, '0');
    String day = date.day.toString().padLeft(2, '0');
    String hour = date.hour.toString().padLeft(2, '0');
    String minute = date.minute.toString().padLeft(2, '0');
    String second = date.second.toString().padLeft(2, '0');

    return '$year-$month-${day}T$hour:$minute:$second';
  }
}
