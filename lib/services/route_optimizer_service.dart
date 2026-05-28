import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Rota optimizasyon servisi.
/// Nearest Neighbor (Greedy TSP) + 2-opt iyileştirme algoritması kullanır.
/// Mesafe hesabı için Haversine formülü uygulanır (API gerektirmez).
/// 2-opt artık doğrudan indeks listesi üzerinde çalışır — koordinat eşleştirme
/// hatası riski tamamen ortadan kaldırılmıştır.
class RouteOptimizerService {
  /// İki koordinat arasındaki kuş uçuşu mesafeyi km cinsinden hesaplar.
  static double haversineDistance(LatLng a, LatLng b) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _toRad(b.latitude - a.latitude);
    final double dLon = _toRad(b.longitude - a.longitude);

    final double sinDLat = sin(dLat / 2);
    final double sinDLon = sin(dLon / 2);

    final double h = sinDLat * sinDLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLon * sinDLon;

    return 2 * earthRadiusKm * asin(sqrt(h));
  }

  static double _toRad(double deg) => deg * pi / 180.0;

  /// Toplam rota mesafesini hesaplar.
  static double totalDistance(List<LatLng> route) {
    double total = 0;
    for (int i = 0; i < route.length - 1; i++) {
      total += haversineDistance(route[i], route[i + 1]);
    }
    return total;
  }

  /// Nearest Neighbor (En Yakın Komşu) TSP algoritması.
  /// [startPoint] varsa oradan başlar; yoksa [points] listesindeki ilk noktadan başlar.
  /// Döndürülen liste, [points] dizisinin optimize edilmiş indeks sıralamasıdır.
  static List<int> nearestNeighborTSP(LatLng? startPoint, List<LatLng> points) {
    if (points.isEmpty) return [];
    if (points.length == 1) return [0];

    final List<bool> visited = List.filled(points.length, false);
    final List<int> order = [];

    LatLng current = startPoint ?? points[0];

    // Eğer startPoint yoksa, ilk noktayı zaten başlangıç say
    if (startPoint == null) {
      visited[0] = true;
      order.add(0);
      if (points.length == 1) return order;
      current = points[0];
    }

    // Tüm noktalar ziyaret edilene kadar devam et
    while (order.length < points.length) {
      int nearestIndex = -1;
      double nearestDist = double.infinity;

      for (int i = 0; i < points.length; i++) {
        if (visited[i]) continue;
        final double dist = haversineDistance(current, points[i]);
        if (dist < nearestDist) {
          nearestDist = dist;
          nearestIndex = i;
        }
      }

      if (nearestIndex == -1) break;
      visited[nearestIndex] = true;
      order.add(nearestIndex);
      current = points[nearestIndex];
    }

    return order;
  }

  /// 2-opt iyileştirme algoritması — indeks listesi üzerinde çalışır.
  ///
  /// [order]      : Nearest Neighbor algoritmasından gelen indeks sırası.
  /// [points]     : Ziyaret edilecek mekânların koordinat listesi.
  /// [startPoint] : Varsa başlangıç noktası (indeks -1 olarak temsil edilir).
  ///
  /// ✅ Koordinat → indeks dönüştürme adımı yoktur; aynı koordinatlı iki
  ///    farklı mekân olsa bile algoritma doğru indeksleri korur.
  static List<int> _twoOptImproveByIndex(
    List<int> order,
    List<LatLng> points,
    LatLng? startPoint,
  ) {
    if (order.length < 3) return order;

    // Yardımcı: -1 = startPoint, 0..n-1 = points[i]
    LatLng _coord(int idx) => idx < 0 ? startPoint! : points[idx];

    // startPoint varsa başına -1 ekleyerek çalışıyoruz
    List<int> working = startPoint != null ? [-1, ...order] : List.from(order);

    bool improved = true;
    while (improved) {
      improved = false;
      for (int i = 0; i < working.length - 1; i++) {
        for (int j = i + 2; j < working.length; j++) {
          // Mevcut maliyet: edge(i→i+1) + edge(j→j+1)
          final double d1 =
              haversineDistance(_coord(working[i]), _coord(working[i + 1])) +
                  (j + 1 < working.length
                      ? haversineDistance(
                          _coord(working[j]), _coord(working[j + 1]))
                      : 0.0);

          // Yeni maliyet: edge(i→j) + edge(i+1→j+1)
          final double d2 =
              haversineDistance(_coord(working[i]), _coord(working[j])) +
                  (j + 1 < working.length
                      ? haversineDistance(
                          _coord(working[i + 1]), _coord(working[j + 1]))
                      : 0.0);

          if (d2 < d1 - 1e-10) {
            // Segment [i+1 .. j] ters çevrilir
            final reversed = working.sublist(i + 1, j + 1).reversed.toList();
            working.replaceRange(i + 1, j + 1, reversed);
            improved = true;
          }
        }
      }
    }

    // Başlangıç noktası işaretçisini (-1) çıkar
    if (startPoint != null) {
      working.removeAt(0);
    }

    return working;
  }

  /// Ana optimizasyon metodu.
  /// [startPoint]: Başlangıç konumu (varsa).
  /// [points]:     Ziyaret edilecek mekânların koordinatları.
  ///
  /// Döndürülen değer: optimize edilmiş [points] indeks listesi.
  static OptimizationResult optimizeRoute({
    required LatLng? startPoint,
    required List<LatLng> points,
  }) {
    if (points.isEmpty) {
      return OptimizationResult(orderedIndices: [], totalKm: 0);
    }
    if (points.length == 1) {
      return OptimizationResult(orderedIndices: [0], totalKm: 0);
    }

    // 1) Nearest Neighbor ile ilk sırayı belirle
    final List<int> nnOrder = nearestNeighborTSP(startPoint, points);

    // 2) 2-opt iyileştirmesi — indeks tabanlı, koordinat eşleştirme yok
    final List<int> finalOrder =
        _twoOptImproveByIndex(nnOrder, points, startPoint);

    // 3) Toplam mesafeyi hesapla
    final List<LatLng> optimizedCoords =
        finalOrder.map((i) => points[i]).toList();
    final List<LatLng> fullPath = startPoint != null
        ? [startPoint, ...optimizedCoords]
        : optimizedCoords;
    final double total = totalDistance(fullPath);

    return OptimizationResult(orderedIndices: finalOrder, totalKm: total);
  }

  /// Ardışık iki nokta arasındaki mesafeleri liste olarak döndürür.
  /// Her eleman, [i] ve [i+1] noktaları arasındaki km mesafesidir.
  static List<double> segmentDistances(
      LatLng? startPoint, List<LatLng> points) {
    if (points.isEmpty) return [];
    final List<double> dists = [];
    LatLng prev = startPoint ?? points[0];
    final int startIdx = startPoint == null ? 1 : 0;
    for (int i = startIdx; i < points.length; i++) {
      dists.add(haversineDistance(prev, points[i]));
      prev = points[i];
    }
    return dists;
  }
}

/// Optimizasyon sonucu modeli.
class OptimizationResult {
  /// [points] listesindeki optimize edilmiş indeks sırası.
  final List<int> orderedIndices;

  /// Toplam rota mesafesi (km).
  final double totalKm;

  const OptimizationResult({
    required this.orderedIndices,
    required this.totalKm,
  });
}
