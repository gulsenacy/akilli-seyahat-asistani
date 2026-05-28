import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';

class GooglePlacesService {
  static const String apiKey = "AIzaSyAbclSR-M23Z9MZZBXaTreBZIednbJXGgc";
  static final Map<String, Map<String, dynamic>> _memoryCache = {};

  // 🔥 SENKRON ÖNBELLEK OKUMA (Ekranda pırpır yapmayı engeller)
  static Map<String, dynamic>? getCachedData(String placeName) {
    return _memoryCache[placeName];
  }

  // 🔥 RESMİ TELEFONA KAYDEDEN FONKSİYON
  static Future<String> _saveImageLocally(String url, String placeName, int index) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = "${placeName.replaceAll(' ', '_').toLowerCase()}_$index.jpg";
      final filePath = p.join(directory.path, fileName);
      final file = File(filePath);

      if (await file.exists()) return filePath; // Zaten varsa indirme

      final response = await http.get(Uri.parse(url));
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (e) {
      return "";
    }
  }

  // 🔥 HOME SCREEN İÇİN TEKLİ FOTOĞRAF
  static Future<String> getSinglePlacePhoto(String placeName) async {
    final data = await getGooglePlaceData(placeName);
    if ((data['photos'] as List).isNotEmpty) {
      return data['photos'].first.toString();
    }
    return "https://via.placeholder.com/600x400?text=Konya";
  }

  // 🔥 GÜNCEL VERİ ÇEKME MANTIĞI (ÖNCE LOKALE BAKAR)
  static Future<Map<String, dynamic>> getGooglePlaceData(String placeName) async {
    if (_memoryCache.containsKey(placeName)) return _memoryCache[placeName]!;

    final directory = await getApplicationDocumentsDirectory();
    final baseFileName = placeName.replaceAll(' ', '_').toLowerCase();
    List<String> localPaths = [];

    // Önce hafızada bu mekana ait resim var mı diye bak (5 tane resim için)
    for (int i = 0; i < 5; i++) {
      final file = File(p.join(directory.path, "${baseFileName}_$i.jpg"));
      if (await file.exists()) {
        localPaths.add(file.path);
      }
    }

    // Eğer hafızada resimler varsa, API'ye hiç gitme!
    if (localPaths.isNotEmpty) {
      final result = {'photos': localPaths, 'isLocal': true}; // 🔥 BURADAKİ SAHTE 4.5'i SİLDİK
      _memoryCache[placeName] = result;
      return result;
    }

    // Hafızada yoksa Google'dan çek ve kaydet
    Map<String, dynamic> result = {'photos': <String>[], 'isLocal': false}; // 🔥 DEFAULT 0.0'ı SİLDİK
    try {
      final searchUrl = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${Uri.encodeComponent("$placeName Konya")}&inputtype=textquery&fields=place_id&key=$apiKey";
      final searchRes = await http.get(Uri.parse(searchUrl));
      final searchData = json.decode(searchRes.body);

      if (searchData['candidates'] != null && searchData['candidates'].isNotEmpty) {
        final placeId = searchData['candidates'][0]['place_id'];
        final detailsUrl = "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=photos,rating&key=$apiKey";
        final detailsRes = await http.get(Uri.parse(detailsUrl));
        final detailsData = json.decode(detailsRes.body);

        if (detailsData['result'] != null) {
          result['rating'] = (detailsData['result']['rating'] ?? "0.0").toString();
          if (detailsData['result']['photos'] != null) {
            List<dynamic> photos = detailsData['result']['photos'];
            List<String> savedPaths = [];
            for (int i = 0; i < (photos.length > 5 ? 5 : photos.length); i++) {
              final url = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photos[i]['photo_reference']}&key=$apiKey";
              final localPath = await _saveImageLocally(url, placeName, i);
              if (localPath.isNotEmpty) savedPaths.add(localPath);
            }
            result['photos'] = savedPaths;
          }
        }
      }
    } catch (e) { print("API Hatası: $e"); }

    _memoryCache[placeName] = result;
    return result;
  }

  // 🔥 RESMİ GÖSTERİRKEN (Network mü yoksa Local Dosya mı?)
  static Widget buildPlaceImage(String path, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (path.isEmpty) {
      return Container(width: width, height: height, color: Colors.grey.shade200, child: const Icon(Icons.image, color: Colors.grey));
    }
    if (path.startsWith('http')) {
      return Image.network(path, width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: Colors.grey)));
    } else {
      return Image.file(File(path), width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, color: Colors.grey)));
    }
  }
}
