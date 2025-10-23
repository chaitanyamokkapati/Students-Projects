import 'package:flutter/material.dart';
import '../models/note.dart';
import '../repositories/firebase_notes_repository.dart';
import 'edit_note_screen.dart';
import 'sync_settings_screen.dart'; // ADD THIS IMPORT

class HomeScreen extends StatefulWidget {
  final void Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseNotesRepository repo = FirebaseNotesRepository();
  String _query = '';
  Stream<List<Note>>? _notesStream;
  bool _isInitialized = false;
  bool _isSyncing = false;
  int _syncedDevices = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeRepo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh sync status when app resumes
      _updateSyncStatus();
    }
  }

  Future<void> _initializeRepo() async {
    await repo.initialize();
    setState(() {
      _isInitialized = true;
      _notesStream = repo.getNotesStream();
    });
    _updateSyncStatus();
  }

  Future<void> _updateSyncStatus() async {
    if (!_isInitialized) return;

    final stats = await repo.getSyncStats();
    setState(() {
      _syncedDevices = stats['devicesConnected'] ?? 1;
    });
  }

  void _filter(String query) {
    setState(() {
      _query = query;
      // Filtering happens in the build method
    });
  }

  Future<void> _addNote() async {
    final newNote = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => const EditNoteScreen()),
    );
    if (newNote != null) {
      setState(() => _isSyncing = true);
      try {
        await repo.addNote(newNote);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note added and synced'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing note: $e')),
          );
        }
      } finally {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _editNote(Note note) async {
    final updated = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => EditNoteScreen(note: note)),
    );
    if (updated != null) {
      setState(() => _isSyncing = true);
      try {
        await repo.updateNote(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note updated and synced'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error syncing note: $e')),
          );
        }
      } finally {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'This will delete the note from all synced devices. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isSyncing = true);
              try {
                await repo.deleteNote(note.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Note deleted from all devices'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting note: $e')),
                  );
                }
              } finally {
                setState(() => _isSyncing = false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleTheme() {
    widget.onThemeChanged(
      widget.currentTheme == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  Future<void> _openSyncSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SyncSettingsScreen(repository: repo),
      ),
    );

    if (result == true) {
      // Sync settings changed, reinitialize
      await _initializeRepo();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Notes"),
        centerTitle: true,
        actions: [
          // Sync indicator
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.cloud_sync),
                  if (_syncedDevices > 1)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_syncedDevices',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _openSyncSettings,
              tooltip: 'Sync Settings ($_syncedDevices devices)',
            ),
          IconButton(
            icon: Icon(
              widget.currentTheme == ThemeMode.dark
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
            ),
            onPressed: _toggleTheme,
            tooltip: 'Toggle Theme',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: "Search notes...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Note>>(
        stream: _notesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _initializeRepo,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data ?? [];

          // Apply local filtering
          final filteredNotes = _query.isEmpty
              ? notes
              : notes
                  .where((note) =>
                      note.title.toLowerCase().contains(_query.toLowerCase()) ||
                      note.content.toLowerCase().contains(_query.toLowerCase()))
                  .toList();

          if (filteredNotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_add,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _query.isEmpty ? "No notes yet" : "No notes found",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _query.isEmpty
                        ? "Tap + to create your first note"
                        : "Try a different search",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (_syncedDevices > 1) ...[
                    const SizedBox(height: 16),
                    Chip(
                      avatar: const Icon(Icons.sync, size: 18),
                      label: Text('Syncing with $_syncedDevices devices'),
                      backgroundColor: Colors.green[100],
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _updateSyncStatus,
            child: ListView.builder(
              itemCount: filteredNotes.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, i) {
                final note = filteredNotes[i];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      note.title.isEmpty ? "(Untitled)" : note.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          note.content.isEmpty ? "No content" : note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_done,
                              size: 14,
                              color: Colors.green[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(note.updatedAt),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _editNote(note),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red[400],
                      onPressed: () => _deleteNote(note),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNote,
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
