import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class OfflineQueue {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  Future<void> addToDeleteQueue(String expenseId, String imageUrl) async {
    final db = await database;
    await db.insert('delete_queue', {
      'expenseId': expenseId,
      'imageUrl': imageUrl,
    });
  }

  Future<List<Map<String, dynamic>>> getDeleteQueue() async {
    final db = await database;
    return await db.query('delete_queue');
  }

  Future<void> clearDeleteQueue(int id) async {
    final db = await database;
    await db.delete('delete_queue', where: 'id = ?', whereArgs: [id]);
  }Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'offline_queue.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT,
          amount TEXT,
          category TEXT,
          filePath TEXT,
          submissionDate TEXT,
          cloudinaryUploaded INTEGER DEFAULT 0,
          cloudinaryUrl TEXT
        )
      ''');
        await db.execute('''
        CREATE TABLE delete_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          expenseId TEXT,
          imageUrl TEXT
        )
      ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE queue ADD COLUMN cloudinaryUrl TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('''
          CREATE TABLE delete_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            expenseId TEXT,
            imageUrl TEXT
          )
        ''');
        }
      },
    );
  }
  Future<void> addToQueue(Map<String, dynamic> data) async {
    final db = await database;
    data['cloudinaryUploaded'] = 0;
    await db.insert('queue', data);
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final db = await database;
    return await db.query('queue');
  }

  Future<void> clearQueue(int id) async {
    final db = await database;
    await db.delete('queue', where: 'id = ?', whereArgs: [id]);
  }
}