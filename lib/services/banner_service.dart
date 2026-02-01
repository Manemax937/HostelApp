import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class BannerImage {
  final String id;
  final String imageUrl;
  final String? title;
  final String? description;
  final int order;
  final DateTime createdAt;
  final bool isActive;

  BannerImage({
    required this.id,
    required this.imageUrl,
    this.title,
    this.description,
    required this.order,
    required this.createdAt,
    this.isActive = true,
  });

  factory BannerImage.fromMap(Map<String, dynamic> map, String id) {
    return BannerImage(
      id: id,
      imageUrl: map['imageUrl'] ?? '',
      title: map['title'],
      description: map['description'],
      order: map['order'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'description': description,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}

class BannerService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _bannersCollection =>
      _firestore.collection('banners');

  /// Stream all active banners ordered by 'order' field
  Stream<List<BannerImage>> streamBanners() {
    return _bannersCollection
        .snapshots()
        .map((snapshot) {
          final banners = snapshot.docs
              .map(
                (doc) => BannerImage.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .where((banner) => banner.isActive)
              .toList();
          // Sort by order client-side to avoid index requirement
          banners.sort((a, b) => a.order.compareTo(b.order));
          return banners;
        });
  }

  /// Stream all banners (including inactive) for admin
  Stream<List<BannerImage>> streamAllBanners() {
    return _bannersCollection.orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) =>
                BannerImage.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    });
  }

  /// Add a new banner image
  Future<String> addBanner({
    required File imageFile,
    String? title,
    String? description,
  }) async {
    try {
      // Get the next order number
      final snapshot = await _bannersCollection
          .orderBy('order', descending: true)
          .limit(1)
          .get();
      int nextOrder = 0;
      if (snapshot.docs.isNotEmpty) {
        nextOrder =
            (snapshot.docs.first.data() as Map<String, dynamic>)['order'] + 1;
      }

      // Upload image to Firebase Storage
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('banners/$fileName');

      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      // Create banner document
      final banner = BannerImage(
        id: '',
        imageUrl: imageUrl,
        title: title,
        description: description,
        order: nextOrder,
        createdAt: DateTime.now(),
        isActive: true,
      );

      final docRef = await _bannersCollection.add(banner.toMap());
      notifyListeners();
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding banner: $e');
      rethrow;
    }
  }

  /// Update banner details
  Future<void> updateBanner({
    required String bannerId,
    String? title,
    String? description,
    bool? isActive,
    int? order,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (isActive != null) updates['isActive'] = isActive;
    if (order != null) updates['order'] = order;

    await _bannersCollection.doc(bannerId).update(updates);
    notifyListeners();
  }

  /// Delete a banner
  Future<void> deleteBanner(String bannerId) async {
    try {
      // Get the banner to delete its image from storage
      final doc = await _bannersCollection.doc(bannerId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final imageUrl = data['imageUrl'] as String?;

        // Delete from storage if URL exists
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
            debugPrint('Error deleting image from storage: $e');
          }
        }
      }

      // Delete the document
      await _bannersCollection.doc(bannerId).delete();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting banner: $e');
      rethrow;
    }
  }

  /// Reorder banners
  Future<void> reorderBanners(List<BannerImage> banners) async {
    final batch = _firestore.batch();
    for (int i = 0; i < banners.length; i++) {
      batch.update(_bannersCollection.doc(banners[i].id), {'order': i});
    }
    await batch.commit();
    notifyListeners();
  }

  /// Toggle banner active status
  Future<void> toggleBannerActive(String bannerId, bool isActive) async {
    await _bannersCollection.doc(bannerId).update({'isActive': isActive});
    notifyListeners();
  }
}
