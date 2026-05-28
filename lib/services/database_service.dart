import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Firestore'daki 'places' koleksiyonunu dinleyen fonksiyon
  Stream<QuerySnapshot> getPlaces() {
    return _db.collection('places').snapshots();
  }
}