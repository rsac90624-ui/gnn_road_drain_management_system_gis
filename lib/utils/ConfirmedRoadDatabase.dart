import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ConfirmedRoadDatabase {
  static final ConfirmedRoadDatabase instance = ConfirmedRoadDatabase._init();
  static Database? _database;

  ConfirmedRoadDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('confirmed_Kanpur_road.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(path, version: 2, onCreate: _createDB);
  }

  // Future _createDB(Database db, int version) async {
  //   await db.execute('''
  //     CREATE TABLE confirmed_roads (
  //       id INTEGER PRIMARY KEY AUTOINCREMENT,
  //       road_id TEXT,
  //       road_name TEXT,
  //       zone_name TEXT,
  //       ward_no TEXT,
  //       category TEXT,
  //       length_met REAL,
  //       condition TEXT,
  //       year_of_co TEXT,
  //       hospital TEXT,
  //       bank_atm TEXT,
  //       educationa TEXT,
  //     )
  //   ''');
  // }

  // Future _createDB(Database db, int version) async {
  //   await db.execute('''
  //   CREATE TABLE confirmed_roads (
  //     road_id TEXT PRIMARY KEY,
  //     road_name TEXT,
  //     zone_name TEXT,
  //     ward_no TEXT,
  //     category TEXT,
  //     length_met REAL,
  //     condition TEXT,
  //     year_of_co TEXT,
  //     hospital TEXT,
  //     bank_atm TEXT,
  //     educationa TEXT,
  //     wkt_geom TEXT  -- 🧠 Optional: Store geometry WKT for redraw/export
  //   )
  // ''');
  // }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE confirmed_roads (
      gid INTEGER,
      id REAL,
      objectid INTEGER,
      road_id TEXT PRIMARY KEY,
      gis_id REAL,
      zone_no TEXT,
      zone_name TEXT,
      ward_no TEXT,
      ward_name TEXT,
      ownership TEXT,
      own_subcla TEXT,
      road_name TEXT,
      row_meter REAL,
      row_as_per REAL,
      rowcls TEXT,
      carriage_w REAL,
      carriage_m TEXT,
      material_c TEXT,
      length_met REAL,
      length_km REAL,
      type TEXT,
      category TEXT,
      condition TEXT,
      year_of_co TEXT,
      cus TEXT,
      start_lat REAL,
      start_long REAL,
      end_lat REAL,
      end_long REAL,
      major_land TEXT,
      fothpath TEXT,
      manhole TEXT,
      median TEXT,
      drain TEXT,
      drain_type TEXT,
      drain_mtrl TEXT,
      transforme TEXT,
      r_m_u TEXT,
      electric_p TEXT,
      street__so TEXT,
      handpump_w TEXT,
      government TEXT,
      educationa TEXT,
      bank_atm TEXT,
      hospital TEXT,
      stadium TEXT,
      park TEXT,
      religious TEXT,
      graveyard TEXT,
      transport TEXT,
      remark TEXT,
      cus_subcl TEXT,
      name TEXT
    )
  ''');
  }




  // Future<void> insertRoad(Map<String, dynamic> road) async {
  //   final db = await instance.database;
  //   await db.insert('confirmed_roads', road, conflictAlgorithm: ConflictAlgorithm.replace);
  // }

  // Future<void> insertRoad(Map<String, dynamic> roadData) async {
  //   final db = await instance.database;
  //
  //   final filtered = {
  //     'road_id': roadData['road_id']?.toString(),
  //     'road_name': roadData['road_name']?.toString(),
  //     'zone_name': roadData['zone_name']?.toString(),
  //     'ward_no': roadData['ward_no']?.toString(),
  //     'category': roadData['category']?.toString(),
  //     'length_met': roadData['length_met'] is num
  //         ? roadData['length_met']
  //         : double.tryParse(roadData['length_met']?.toString() ?? '0'),
  //     'condition': roadData['condition']?.toString(),
  //     'year_of_co': roadData['year_of_co']?.toString(),
  //     'hospital': roadData['hospital']?.toString(),
  //     'bank_atm': roadData['bank_atm']?.toString(),
  //     'educationa': roadData['educationa']?.toString(),
  //   };
  //
  //   await db.insert(
  //     'confirmed_roads',
  //     filtered,
  //     conflictAlgorithm: ConflictAlgorithm.replace,
  //   );
  // }

  Future<void> insertRoad(Map<String, dynamic> roadData) async {
    final db = await instance.database;

    // Only include valid fields and convert them if needed
    final filtered = Map<String, dynamic>.fromEntries(
      roadData.entries.where((entry) => _isSupportedColumn(entry.key)),
    );

    await db.insert(
      'confirmed_roads',
      filtered,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  bool _isSupportedColumn(String columnName) {
    const supportedColumns = {
      'gid', 'id', 'objectid', 'road_id', 'gis_id',
      'zone_no', 'zone_name', 'ward_no', 'ward_name',
      'ownership', 'own_subcla', 'road_name', 'row_meter',
      'row_as_per', 'rowcls', 'carriage_w', 'carriage_m',
      'material_c', 'length_met', 'length_km', 'type',
      'category', 'condition', 'year_of_co', 'cus',
      'start_lat', 'start_long', 'end_lat', 'end_long',
      'major_land', 'fothpath', 'manhole', 'median', 'drain',
      'drain_type', 'drain_mtrl', 'transforme', 'r_m_u',
      'electric_p', 'street__so', 'handpump_w', 'government',
      'educationa', 'bank_atm', 'hospital', 'stadium',
      'park', 'religious', 'graveyard', 'transport',
      'remark', 'cus_subcl', 'name',
    };
    return supportedColumns.contains(columnName);
  }




  Future<List<Map<String, dynamic>>> getAllRoads() async {
    final db = await instance.database;
    return await db.query('confirmed_roads');
  }

  Future<void> clearAllRoads() async {
    final db = await instance.database;
    await db.delete('confirmed_roads');
  }
}
