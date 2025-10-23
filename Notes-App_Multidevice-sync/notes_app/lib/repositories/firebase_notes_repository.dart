import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import '../services/sync_service.dart';

class FirebaseNotesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentSyncId;
  String? _deviceId;

  // Initialize with sync ID
  Future<void> initialize() async {
    _currentSyncId = await SyncService.getSyncId();
    _deviceId = await SyncService.getDeviceId();
  }

  // SIMPLIFIED: Use root notes collection with syncId field
  CollectionReference<Map<String, dynamic>> get notesCollection {
    return _firestore.collection('notes');
  }

  // Get real-time stream of notes with sync
  Stream<List<Note>> getNotesStream() {
    if (_currentSyncId == null) {
      return Stream.value([]);
    }

    // Filter by syncId
    return notesCollection
        .where('syncId', isEqualTo: _currentSyncId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Note.fromJson(data);
      }).toList();
    });
  }

  // Add note with sync metadata
  Future<void> addNote(Note note) async {
    try {
      final noteData = note.toJson();
      noteData['syncId'] = _currentSyncId;
      noteData['lastEditedBy'] = _deviceId;
      noteData['syncedAt'] = FieldValue.serverTimestamp();

      await notesCollection.doc(note.id).set(noteData);
    } catch (e) {
      print('Error adding note: $e');
      rethrow;
    }
  }

  // Update note with conflict resolution
  Future<void> updateNote(Note note) async {
    try {
      final docRef = notesCollection.doc(note.id);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          // Note doesn't exist, create it
          transaction.set(docRef, {
            ...note.toJson(),
            'syncId': _currentSyncId,
            'lastEditedBy': _deviceId,
            'syncedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Update existing note
          transaction.update(docRef, {
            'title': note.title,
            'content': note.content,
            'updatedAt': note.updatedAt.toIso8601String(),
            'syncId': _currentSyncId,
            'lastEditedBy': _deviceId,
            'syncedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error updating note: $e');
      rethrow;
    }
  }

  // Delete note
  Future<void> deleteNote(String noteId) async {
    try {
      await notesCollection.doc(noteId).delete();
    } catch (e) {
      print('Error deleting note: $e');
      rethrow;
    }
  }

  // Change sync group
  Future<void> changeSyncId(String newSyncId) async {
    await SyncService.setSyncId(newSyncId);
    _currentSyncId = newSyncId;
  }

  // Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      if (_currentSyncId == null) {
        return {
          'totalNotes': 0,
          'devicesConnected': 1,
          'syncId': _currentSyncId,
          'currentDevice': _deviceId,
        };
      }

      final snapshot = await notesCollection
          .where('syncId', isEqualTo: _currentSyncId)
          .get();

      final devices = <String>{};

      for (var doc in snapshot.docs) {
        final deviceId = doc.data()['lastEditedBy'];
        if (deviceId != null) {
          devices.add(deviceId);
        }
      }

      return {
        'totalNotes': snapshot.size,
        'devicesConnected': devices.length,
        'syncId': _currentSyncId,
        'currentDevice': _deviceId,
      };
    } catch (e) {
      print('Error getting sync stats: $e');
      return {
        'totalNotes': 0,
        'devicesConnected': 1,
        'syncId': _currentSyncId,
        'currentDevice': _deviceId,
      };
    }
  }
}
