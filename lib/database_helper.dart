import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Owns the database connection and schema (v1 Part I table + v2 folders/cards).
/// Part I CRUD methods are unchanged. New Part II SQL lives in
/// lib/repository/card_repository.dart, which uses [database].
class DatabaseHelper {
  // Same filename as Part I: renaming it would orphan existing data.
  static const _databaseName = 'MyDatabase.db';
  // Raised by exactly one: 1 -> 2.
  static const _databaseVersion = 2;
  static const table = 'my_table';

  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  static const foldersTable = 'folders';
  static const cardsTable = 'cards';

  late Database _db;

  /// Exposed so the repository (the only other SQL-aware class) can use it.
  Database get database => _db;

  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = join(documentsDirectory.path, _databaseName);

    _db = await openDatabase(
      dbPath,
      version: _databaseVersion,
      // Foreign keys are only enforced if switched on per connection.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      // Fresh install: build the COMPLETE schema (Part I table + new tables).
      onCreate: (db, version) async {
        await db.transaction((txn) async {
          await _createPartOneTable(txn);
          await _createPartTwoSchema(txn);
        });
      },
      // Existing v1 database: ADD the new tables only. my_table and its
      // rows are never touched, dropped, or recreated.
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.transaction((txn) async {
          if (oldVersion < 2) {
            await _createPartTwoSchema(txn);
          }
        });
      },
    );
  }

  Future<void> _createPartOneTable(DatabaseExecutor db) async {
    await db.execute("""
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    """);
  }

  Future<void> _createPartTwoSchema(DatabaseExecutor db) async {
    await db.execute("""
      CREATE TABLE $foldersTable (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    """);
    await db.execute("""
      CREATE TABLE $cardsTable (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        title     TEXT NOT NULL,
        suit      TEXT NOT NULL,
        notes     TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES $foldersTable(id) ON DELETE CASCADE
      )
    """);
    await db.execute(
      'CREATE INDEX idx_cards_folder_id ON $cardsTable(folder_id)',
    );
    // No seed data: nothing can duplicate on relaunch.
  }

  // ---- Part I methods (unchanged) ----

  Future<int> insert(Map<String, dynamic> row) => _db.insert(table, row);

  Future<List<Map<String, dynamic>>> queryAllRows() {
    return _db.query(table, orderBy: '$columnId ASC');
  }

  Future<int> queryRowCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM $table',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> update(Map<String, dynamic> row) async {
    final id = row[columnId];
    if (id is! int) {
      throw ArgumentError('Update requires an integer _id.');
    }
    return _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) {
    return _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }
}

// ================= Models =================

class Folder {
  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  final int? id;
  final String name;
  final String createdAt;

  /// Computed by a COUNT join; not a stored column.
  final int cardCount;

  factory Folder.fromMap(Map<String, dynamic> map) => Folder(
        id: map['id'] as int,
        name: map['name'] as String,
        createdAt: map['created_at'] as String,
        cardCount: (map['card_count'] as int?) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'created_at': createdAt,
      };
}

/// Named CardItem (not Card) to avoid clashing with Flutter's Material Card widget.
class CardItem {
  const CardItem({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  final int? id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  static const suits = ['spades', 'hearts', 'diamonds', 'clubs'];

  static const suitSymbols = {
    'spades': '♠',
    'hearts': '♥',
    'diamonds': '♦',
    'clubs': '♣',
  };

  static bool isValidSuit(String? s) => s != null && suits.contains(s);

  String get symbol => suitSymbols[suit] ?? '?';

  factory CardItem.fromMap(Map<String, dynamic> map) => CardItem(
        id: map['id'] as int,
        title: map['title'] as String,
        suit: map['suit'] as String,
        notes: (map['notes'] as String?) ?? '',
        imageRef: map['image_ref'] as String?,
        folderId: map['folder_id'] as int,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'suit': suit,
        'notes': notes,
        'image_ref': imageRef,
        'folder_id': folderId,
      };
}

// ================= Repository (all Part II SQL) =================

/// The only place (besides DatabaseHelper) that contains SQL.
/// All values are bound with whereArgs / args, never concatenated.
class CardRepository {
  CardRepository(this._helper);
  final DatabaseHelper _helper;

  Database get _db => _helper.database;

  // ---- Folders ----

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders f
      LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id
      ORDER BY f.name COLLATE NOCASE ASC
    ''');
    return rows.map(Folder.fromMap).toList();
  }

  Future<Folder?> getFolder(int id) async {
    final rows = await _db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Folder.fromMap(rows.first);
  }

  /// Returns the new row ID (from the insert, never assumed).
  Future<int> insertFolder(String name) {
    return _db.insert('folders', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Returns rows affected. With foreign keys ON, child cards are
  /// removed by ON DELETE CASCADE.
  Future<int> deleteFolder(int id) {
    return _db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Cards ----

  Future<List<CardItem>> getCards(int folderId) async {
    final rows = await _db.query(
      'cards',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return rows.map(CardItem.fromMap).toList();
  }

  Future<CardItem?> getCard(int id) async {
    final rows = await _db.query(
      'cards',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CardItem.fromMap(rows.first);
  }

  Future<int> insertCard(CardItem card) {
    final map = card.toMap()..remove('id');
    return _db.insert('cards', map);
  }

  /// Returns rows affected; 0 means the card no longer exists.
  Future<int> updateCard(CardItem card) {
    final id = card.id;
    if (id == null) {
      throw ArgumentError('updateCard requires a card with an id.');
    }
    final map = card.toMap()..remove('id');
    return _db.update('cards', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCard(int id) {
    return _db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }
}
