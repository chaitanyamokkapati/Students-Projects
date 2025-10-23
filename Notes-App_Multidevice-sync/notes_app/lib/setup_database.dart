import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;
  const uuid = Uuid();

  print('🗑️ Cleaning up old data...');

  // Delete all existing notes (optional)
  final existing = await db.collection('notes').get();
  for (var doc in existing.docs) {
    await doc.reference.delete();
  }
  print('✅ Cleaned ${existing.docs.length} old documents');

  // Create a proper sync group ID
  final syncId = uuid.v4();
  print('\n📱 New Sync ID: $syncId');
  print('   (Save this to test multi-device sync!)');

  // Create sample notes with proper structure
  final sampleNotes = [
    {
      'syncId': syncId,
      'title': 'Welcome to Notes App',
      'content': 'This app syncs your notes across all your devices!',
      'createdAt':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'updatedAt':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'lastEditedBy': 'device-setup',
    },
    {
      'syncId': syncId,
      'title': 'Shopping List',
      'content': '- Milk\n- Bread\n- Eggs\n- Cheese',
      'createdAt':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'updatedAt':
          DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
      'lastEditedBy': 'device-setup',
    },
    {
      'syncId': syncId,
      'title': 'Meeting Notes',
      'content': 'Discuss project timeline and deliverables',
      'createdAt':
          DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
      'updatedAt':
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'lastEditedBy': 'device-setup',
    },
  ];

  print('\n📝 Creating sample notes...');
  for (var i = 0; i < sampleNotes.length; i++) {
    final noteId = uuid.v4();
    await db.collection('notes').doc(noteId).set(sampleNotes[i]);
    print('   ✅ Created note ${i + 1}: ${sampleNotes[i]['title']}');
  }

  print('\n🔍 Verifying data...');

  // Test the query
  final testQuery = await db
      .collection('notes')
      .where('syncId', isEqualTo: syncId)
      .orderBy('updatedAt', descending: true)
      .get();

  print('✅ Query successful! Found ${testQuery.docs.length} notes:');
  for (var doc in testQuery.docs) {
    final data = doc.data();
    print('   📄 ${data['title']} (updated: ${data['updatedAt']})');
  }

  print('\n🎉 Database setup complete!');
  print('\n📋 Next steps:');
  print('1. Copy this Sync ID: $syncId');
  print('2. Run your app');
  print('3. Go to Sync Settings');
  print('4. Paste this Sync ID to connect');

  // Also save the sync ID to SharedPreferences for the app
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_id', syncId);
    print('\n✅ Sync ID saved to app preferences');
  } catch (e) {
    print('\n⚠️ Could not save to SharedPreferences (run in app context)');
  }
}
