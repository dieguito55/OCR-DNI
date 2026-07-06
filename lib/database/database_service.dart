import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/app_stats.dart';
import '../models/persona.dart';
import '../models/sede.dart';

class DuplicateDniException implements Exception {
  DuplicateDniException(this.existing);

  final Persona existing;
}

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'xiomi.db');
    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeToV3(db);
        }
        if (oldVersion < 4) {
          await _upgradeToV4(db);
        }
      },
    );
    return _db!;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE sedes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        codigo TEXT NOT NULL DEFAULT '',
        descripcion TEXT NOT NULL DEFAULT '',
        fecha_creacion TEXT NOT NULL DEFAULT '',
        fecha_actualizacion TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
          CREATE TABLE personas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sede_id INTEGER,
            numero INTEGER,
            apellido_paterno TEXT NOT NULL DEFAULT '',
            apellido_materno TEXT NOT NULL DEFAULT '',
            nombres TEXT NOT NULL DEFAULT '',
            dni TEXT NOT NULL DEFAULT '',
            sexo TEXT NOT NULL DEFAULT '',
            fecha_nacimiento TEXT NOT NULL DEFAULT '',
            imagen_dni_path TEXT NOT NULL DEFAULT '',
            texto_ocr TEXT NOT NULL DEFAULT '',
            estado_revision TEXT NOT NULL DEFAULT 'pendiente',
            fecha_creacion TEXT NOT NULL DEFAULT '',
            fecha_actualizacion TEXT NOT NULL DEFAULT ''
          )
        ''');
    await db.execute(
      'CREATE INDEX idx_personas_sede_dni ON personas(sede_id, dni)',
    );
    await db.execute(
      'CREATE INDEX idx_personas_sede_busqueda ON personas(sede_id, nombres, apellido_paterno, apellido_materno)',
    );
    await db.execute('CREATE INDEX idx_sedes_nombre ON sedes(nombre)');
  }

  Future<void> _upgradeToV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sedes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        codigo TEXT NOT NULL DEFAULT '',
        descripcion TEXT NOT NULL DEFAULT '',
        fecha_creacion TEXT NOT NULL DEFAULT '',
        fecha_actualizacion TEXT NOT NULL DEFAULT ''
      )
    ''');

    final now = DateTime.now().toIso8601String();
    final sedeId = await db.insert('sedes', {
      'nombre': 'Sede general',
      'codigo': 'GENERAL',
      'descripcion': 'Registros existentes antes de separar por sede.',
      'fecha_creacion': now,
      'fecha_actualizacion': now,
    });

    final columns = await db.rawQuery('PRAGMA table_info(personas)');
    final hasSedeId = columns.any((column) => column['name'] == 'sede_id');
    if (!hasSedeId) {
      await db.execute('ALTER TABLE personas ADD COLUMN sede_id INTEGER');
    }
    await db.update('personas', {'sede_id': sedeId}, where: 'sede_id IS NULL');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_personas_sede_dni ON personas(sede_id, dni)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_personas_sede_busqueda ON personas(sede_id, nombres, apellido_paterno, apellido_materno)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sedes_nombre ON sedes(nombre)',
    );
  }

  Future<void> _upgradeToV3(Database db) async {
    // Drop old indexes
    await db.execute('DROP INDEX IF EXISTS idx_personas_sede_dni');
    await db.execute('DROP INDEX IF EXISTS idx_personas_sede_busqueda');

    // Create a temporary table with the new schema
    await db.execute('''
          CREATE TABLE personas_v3 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sede_id INTEGER,
            numero INTEGER,
            apellido_paterno TEXT NOT NULL DEFAULT '',
            apellido_materno TEXT NOT NULL DEFAULT '',
            nombres TEXT NOT NULL DEFAULT '',
            dni TEXT NOT NULL DEFAULT '',
            sexo TEXT NOT NULL DEFAULT '',
            fecha_nacimiento TEXT NOT NULL DEFAULT '',
            direccion TEXT NOT NULL DEFAULT '',
            imagen_dni_path TEXT NOT NULL DEFAULT '',
            texto_ocr TEXT NOT NULL DEFAULT '',
            estado_revision TEXT NOT NULL DEFAULT 'pendiente',
            fecha_creacion TEXT NOT NULL DEFAULT '',
            fecha_actualizacion TEXT NOT NULL DEFAULT ''
          )
        ''');

    // Copy data over
    await db.execute('''
      INSERT INTO personas_v3 (
        id, sede_id, numero, apellido_paterno, apellido_materno, nombres, dni, sexo,
        fecha_nacimiento, direccion, imagen_dni_path, texto_ocr, estado_revision,
        fecha_creacion, fecha_actualizacion
      )
      SELECT 
        id, sede_id, numero, apellido_paterno, apellido_materno, nombres, dni, sexo,
        fecha_nacimiento, direccion, imagen_dni_path, texto_ocr, estado_revision,
        fecha_creacion, fecha_actualizacion
      FROM personas
    ''');

    // Drop old table and rename new table
    await db.execute('DROP TABLE personas');
    await db.execute('ALTER TABLE personas_v3 RENAME TO personas');

    // Recreate indexes
    await db.execute(
      'CREATE INDEX idx_personas_sede_dni ON personas(sede_id, dni)',
    );
    await db.execute(
      'CREATE INDEX idx_personas_sede_busqueda ON personas(sede_id, nombres, apellido_paterno, apellido_materno)',
    );
  }

  Future<void> _upgradeToV4(Database db) async {
    // Drop old indexes
    await db.execute('DROP INDEX IF EXISTS idx_personas_sede_dni');
    await db.execute('DROP INDEX IF EXISTS idx_personas_sede_busqueda');

    // Create a temporary table with the new schema without direccion
    await db.execute('''
          CREATE TABLE personas_v4 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sede_id INTEGER,
            numero INTEGER,
            apellido_paterno TEXT NOT NULL DEFAULT '',
            apellido_materno TEXT NOT NULL DEFAULT '',
            nombres TEXT NOT NULL DEFAULT '',
            dni TEXT NOT NULL DEFAULT '',
            sexo TEXT NOT NULL DEFAULT '',
            fecha_nacimiento TEXT NOT NULL DEFAULT '',
            imagen_dni_path TEXT NOT NULL DEFAULT '',
            texto_ocr TEXT NOT NULL DEFAULT '',
            estado_revision TEXT NOT NULL DEFAULT 'pendiente',
            fecha_creacion TEXT NOT NULL DEFAULT '',
            fecha_actualizacion TEXT NOT NULL DEFAULT ''
          )
        ''');

    // Copy data over explicitly leaving out 'direccion'
    await db.execute('''
      INSERT INTO personas_v4 (
        id, sede_id, numero, apellido_paterno, apellido_materno, nombres, dni, sexo,
        fecha_nacimiento, imagen_dni_path, texto_ocr, estado_revision,
        fecha_creacion, fecha_actualizacion
      )
      SELECT 
        id, sede_id, numero, apellido_paterno, apellido_materno, nombres, dni, sexo,
        fecha_nacimiento, imagen_dni_path, texto_ocr, estado_revision,
        fecha_creacion, fecha_actualizacion
      FROM personas
    ''');

    // Drop old table and rename new table
    await db.execute('DROP TABLE personas');
    await db.execute('ALTER TABLE personas_v4 RENAME TO personas');

    // Recreate indexes
    await db.execute(
      'CREATE INDEX idx_personas_sede_dni ON personas(sede_id, dni)',
    );
    await db.execute(
      'CREATE INDEX idx_personas_sede_busqueda ON personas(sede_id, nombres, apellido_paterno, apellido_materno)',
    );
  }

  Future<List<Sede>> allSedes() async {
    final db = await database;
    final rows = await db.query('sedes', orderBy: 'nombre ASC');
    return rows.map(Sede.fromMap).toList();
  }

  Future<Sede?> findSede(int id) async {
    final db = await database;
    final rows = await db.query('sedes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Sede.fromMap(rows.first);
  }

  Future<Sede> saveSede(Sede sede) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final clean = sede.copyWith(
      nombre: sede.nombre.trim(),
      codigo: sede.codigo.trim().toUpperCase(),
      fechaCreacion: sede.fechaCreacion.isEmpty ? now : sede.fechaCreacion,
      fechaActualizacion: now,
    );
    final data = clean.toMap()..remove('id');
    if (sede.id == null) {
      final id = await db.insert('sedes', data);
      return clean.copyWith(id: id);
    }
    await db.update('sedes', data, where: 'id = ?', whereArgs: [sede.id]);
    return clean;
  }

  Future<void> deleteSede(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('personas', where: 'sede_id = ?', whereArgs: [id]);
      await txn.delete('sedes', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> savePersona(Persona persona) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final cleanDni = persona.dni.trim();
    final sedeId = persona.sedeId;
    if (sedeId == null) {
      throw StateError('Selecciona una sede antes de guardar.');
    }

    if (cleanDni.isNotEmpty) {
      final existing = await findByDni(cleanDni, sedeId: sedeId);
      if (existing != null && existing.id != persona.id) {
        throw DuplicateDniException(existing);
      }
    }

    final status = persona.estaCompleto ? 'revisado' : 'incompleto';
    final numero = persona.id == null && persona.numero == null
        ? await nextNumero(sedeId)
        : persona.numero;
    final data =
        persona
            .copyWith(
              sedeId: sedeId,
              numero: numero,
              dni: cleanDni,
              estadoRevision: status,
              fechaCreacion: persona.fechaCreacion.isEmpty
                  ? now
                  : persona.fechaCreacion,
              fechaActualizacion: now,
            )
            .toMap()
          ..remove('id');

    if (persona.id == null) {
      return db.insert('personas', data);
    }

    await db.update('personas', data, where: 'id = ?', whereArgs: [persona.id]);
    return persona.id!;
  }

  Future<int> nextNumero(int sedeId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(numero), 0) + 1 AS next FROM personas WHERE sede_id = ?',
      [sedeId],
    );
    return Sqflite.firstIntValue(rows) ?? 1;
  }

  Future<Persona?> findByDni(String dni, {required int sedeId}) async {
    final db = await database;
    final rows = await db.query(
      'personas',
      where: 'sede_id = ? AND dni = ?',
      whereArgs: [sedeId, dni.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Persona.fromMap(rows.first);
  }

  Future<List<Persona>> searchPersonas(
    String query, {
    required int sedeId,
  }) async {
    final db = await database;
    final normalized = query.trim();
    final rows = normalized.isEmpty
        ? await db.query(
            'personas',
            where: 'sede_id = ?',
            whereArgs: [sedeId],
            orderBy: 'numero DESC, id DESC',
          )
        : await db.query(
            'personas',
            where: '''
              sede_id = ? AND (
                dni LIKE ? OR nombres LIKE ? OR apellido_paterno LIKE ?
                OR apellido_materno LIKE ?
              )
            ''',
            whereArgs: [sedeId, ...List.filled(4, '%$normalized%')],
            orderBy: 'numero DESC, id DESC',
          );
    return rows.map(Persona.fromMap).toList();
  }

  Future<List<Persona>> allPersonas({required int sedeId}) async {
    final db = await database;
    final rows = await db.query(
      'personas',
      where: 'sede_id = ?',
      whereArgs: [sedeId],
      orderBy: 'numero ASC, id ASC',
    );
    return rows.map(Persona.fromMap).toList();
  }

  Future<Persona?> lastPersona({required int sedeId}) async {
    final db = await database;
    final rows = await db.query(
      'personas',
      where: 'sede_id = ?',
      whereArgs: [sedeId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Persona.fromMap(rows.first);
  }

  Future<void> deletePersona(int id) async {
    final db = await database;
    await db.delete('personas', where: 'id = ?', whereArgs: [id]);
  }

  Future<AppStats> stats({required int sedeId}) async {
    final db = await database;
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM personas WHERE sede_id = ?', [
            sedeId,
          ]),
        ) ??
        0;
    final duplicadosRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cantidad
      FROM (
        SELECT dni FROM personas
        WHERE sede_id = ? AND dni <> ''
        GROUP BY dni
        HAVING COUNT(*) > 1
      )
    ''',
      [sedeId],
    );
    final duplicados = Sqflite.firstIntValue(duplicadosRows) ?? 0;
    final rows = await db.query(
      'personas',
      where: 'sede_id = ?',
      whereArgs: [sedeId],
    );
    final personas = rows.map(Persona.fromMap).toList();
    final completos = personas.where((persona) => persona.estaCompleto).length;
    final pendientes = personas
        .where((persona) => !persona.estaCompleto)
        .length;
    final listos = personas
        .where(
          (persona) =>
              persona.estaCompleto && persona.estadoRevision != 'exportado',
        )
        .length;
    return AppStats(
      total: total,
      completos: completos,
      pendientes: pendientes,
      duplicados: duplicados,
      listosExportar: listos,
    );
  }
}
