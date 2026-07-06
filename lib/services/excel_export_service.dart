import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/persona.dart';
import '../models/sede.dart';

class ExcelExportService {
  ExcelExportService._();

  static final ExcelExportService instance = ExcelExportService._();

  Future<File> exportPadron(
    List<Persona> personas, {
    required Sede sede,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = 'Registros';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    final headers = [
      'APELLIDO PATERNO',
      'APELLIDO MATERNO',
      'NOMBRE',
      'FECHA DE NACIMIENTO',
      'NÚMERO DE DNI',
      'SEXO',
    ];

    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .value = TextCellValue(
        headers[column],
      );
    }

    for (var index = 0; index < personas.length; index++) {
      final persona = personas[index];
      final row = index + 1;
      final values = <Object?>[
        persona.apellidoPaterno,
        persona.apellidoMaterno,
        persona.nombres,
        persona.fechaNacimiento,
        persona.dni,
        persona.sexo,
      ];

      for (var column = 0; column < values.length; column++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
            )
            .value = _cellValue(
          values[column],
        );
      }
    }

    final outputBytes = excel.encode();
    if (outputBytes == null) {
      throw StateError('No se pudo generar el archivo Excel.');
    }

    final directory = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final sedeSlug = _safeFilePart(sede.displayName);
    final file = File(
      p.join(directory.path, 'padron_xiomi_${sedeSlug}_$stamp.xlsx'),
    );
    await file.writeAsBytes(outputBytes, flush: true);
    return file;
  }

  Future<void> share(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Padrón exportado desde Xiomi',
      ),
    );
  }

  CellValue _cellValue(Object? value) {
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    return TextCellValue(value?.toString() ?? '');
  }

  String _safeFilePart(String value) {
    final clean = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return clean.isEmpty ? 'sede' : clean;
  }
}
