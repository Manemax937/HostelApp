import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hostelapp/models/notice_model.dart';

class NoticeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createNotice({
    required String title,
    required String description,
    required NoticePriority priority,
    required String createdBy,
    required String createdByName,
    String? residenceName,
  }) async {
    final notice = Notice(
      id: '',
      title: title,
      description: description,
      priority: priority,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      createdByName: createdByName,
      residenceName: residenceName,
    );

    await _firestore.collection('notices').add(notice.toMap());
    notifyListeners();
  }

  Future<void> updateNotice({
    required String noticeId,
    required String title,
    required String description,
    required NoticePriority priority,
  }) async {
    await _firestore.collection('notices').doc(noticeId).update({
      'title': title,
      'description': description,
      'priority': priority.toString().split('.').last,
    });
    notifyListeners();
  }

  /// Get all notices (for backward compatibility)
  Stream<List<Notice>> getNotices() {
    return _firestore
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Notice.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get notices for a specific residence
  Stream<List<Notice>> getNoticesByResidence(String residenceName) {
    return _firestore
        .collection('notices')
        .where('residenceName', isEqualTo: residenceName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Notice.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> deleteNotice(String noticeId) async {
    await _firestore.collection('notices').doc(noticeId).delete();
    notifyListeners();
  }
}
