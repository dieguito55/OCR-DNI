import '../models/persona.dart';

class DniTextParser {
  const DniTextParser._();

  static Persona parse(String text, String imagePath) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final mrz = _extractMrz(lines);
    final inferredNames = _inferNamesFromLayout(lines, mrz);
    final printedApellidoPaterno = _extractNameSection(lines, [
      'PRIMER APELLIDO',
      'APELLIDO PATERNO',
      'APALDO',
      'PIMO ABELDO',
      'PRIMER APELHDO',
      'RIMER APETHOO',
    ]);
    final printedApellidoMaterno = _extractNameSection(lines, [
      'SEGUNDO APELLIDO',
      'APELLIDO MATERNO',
      'SOGINCLO APELLIDO',
      'SEGUNTO APELIO',
      'SEGUNTO APELLIDO',
      'SEGUNDO APELIDO',
      'SEGUNO APELG',
      'SEGUNDO APEL',
      'EGUNDD APETID',
      'EGUNDO APETID',
      'SUNAD APED',
    ]);
    final printedNombres = _extractNameSection(lines, [
      'PRE NOMBRES',
      'PRENOMBRES',
      'PRE-NOMBRES',
      'NOMBRES',
      'PRUNONBROD',
      'PRU NOBROD',
      'PE NAMBRES',
      'PE NAMBRAS',
    ]);
    final apellidoPaterno = _normalizeSurnamePhrase(
      mrz.apellidoPaterno.isNotEmpty
          ? mrz.apellidoPaterno
          : _chooseSurname(
              printedApellidoPaterno,
              inferredNames.apellidoPaterno,
            ),
    );
    final nombres = _removeSurnameFromGivenNames(
      apellidoPaterno,
      mrz.nombres.isNotEmpty
          ? mrz.nombres
          : _chooseName(printedNombres, inferredNames.nombres),
    );

    return Persona(
      dni: mrz.dni.isNotEmpty ? mrz.dni : _extractDni(lines, normalized),
      apellidoPaterno: apellidoPaterno,
      apellidoMaterno: _normalizeSurnamePhrase(
        printedApellidoMaterno ?? inferredNames.apellidoMaterno,
      ),
      nombres: nombres,
      sexo: mrz.sexo.isNotEmpty ? mrz.sexo : _extractSex(normalized),
      fechaNacimiento: mrz.fechaNacimiento.isNotEmpty
          ? mrz.fechaNacimiento
          : _extractBirthDate(normalized),
      imagenDniPath: imagePath,
      textoOcr: text,
      estadoRevision: 'pendiente',
    );
  }

  static String _extractDni(List<String> lines, String normalized) {
    // 1. Direct Regex with strict boundary matching Peruvian DNI patterns
    final labeledPatterns = [
      RegExp(r'\bDNI\s*[:\-\s]?\s*([0-9]{8})\b', caseSensitive: false),
      RegExp(
        r'\b(?:CUI|C\.U\.I)\s*[:\-\s]?\s*([0-9]{8})[-\s]?[0-9]?\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\bDOCUMENTO\s*DE\s*IDENTIDAD\s*([0-9]{8})\b',
        caseSensitive: false,
      ),
      RegExp(r'\bNRO[.\s]*([0-9]{8})\b', caseSensitive: false),
    ];
    for (final pattern in labeledPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) return match.group(1) ?? '';
    }

    // 2. Looks exactly like DNI
    for (final line in lines) {
      final direct = line.trim();
      if (RegExp(r'^[0-9]{8}$').hasMatch(direct) &&
          !_looksLikeBirthOrMrzNumber(direct)) {
        return direct;
      }
    }

    for (final line in lines) {
      final digits = _digitsFromOcr(line);
      if (RegExp(r'^[0-9]{8}$').hasMatch(digits) &&
          !_looksLikeBirthOrMrzNumber(digits)) {
        return digits;
      }
    }

    final candidates = RegExp(r'\b[0-9OQIlS]{8,9}\b').allMatches(normalized);
    for (final match in candidates) {
      final digits = _digitsFromOcr(match.group(0)!);
      if (digits.length < 8) continue;
      final dni = digits.substring(0, 8);
      if (!_looksLikeBirthOrMrzNumber(dni)) return dni;
    }
    return '';
  }

  static String _extractBirthDate(String normalized) {
    // Date formats specific to Peruvian DNI e.g. 14 02 1990 or 14/02/1990
    final slashDate = RegExp(
      r'\b([0-3]?\d)[/-\s]+([01]?\d)[/-\s]+((?:19|20)\d{2})\b',
    ).firstMatch(normalized);

    if (slashDate != null) {
      return _formatDate(
        slashDate.group(1)!,
        slashDate.group(2)!,
        slashDate.group(3)!,
      );
    }

    final nacimientoIndex = normalized.toUpperCase().indexOf('NACIMIENTO');
    final searchArea = nacimientoIndex == -1
        ? normalized
        : normalized.substring(nacimientoIndex);
    final spacedDate = RegExp(
      r'\b([0-3]?\d)\s+([01]?\d)\s+((?:19|20)\d{2})\b',
    ).firstMatch(searchArea);
    if (spacedDate != null) {
      return _formatDate(
        spacedDate.group(1)!,
        spacedDate.group(2)!,
        spacedDate.group(3)!,
      );
    }

    if (nacimientoIndex != -1) {
      final compactDate = RegExp(
        r'\b([0-3]\d)([01]\d)((?:19|20)\d{2})\b',
      ).firstMatch(searchArea);
      if (compactDate != null) {
        return _formatDate(
          compactDate.group(1)!,
          compactDate.group(2)!,
          compactDate.group(3)!,
        );
      }
    }
    return '';
  }

  static String _extractSex(String normalized) {
    final match = RegExp(
      r'\b(M|F|MASCULINO|FEMENINO)\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    final value = match?.group(0)?.toUpperCase() ?? '';
    if (value == 'MASCULINO' || value == 'M') return 'M';
    if (value == 'FEMENINO' || value == 'F') return 'F';

    // fallback with MRZ
    final mrzLike = RegExp(r'[0-9]{6}[0-9A-Z]?([MF])').firstMatch(normalized);
    return mrzLike?.group(1) ?? '';
  }

  static _MrzData _extractMrz(List<String> lines) {
    final compactLines = lines
        .map((line) => line.toUpperCase().replaceAll(RegExp(r'\s+'), ''))
        .toList();
    final all = compactLines.join('\n');

    final dniMatch =
        RegExp(r'(?:I|1)<PER([0-9]{8})').firstMatch(all) ??
        RegExp(r'PER([0-9]{8})').firstMatch(all);
    final dni = dniMatch?.group(1) ?? '';

    final nameLineIndex = _findMrzNameLineIndex(compactLines, dni);
    final birthCandidate = _findMrzBirthCandidate(
      compactLines,
      nameLineIndex: nameLineIndex,
    );
    final fecha = birthCandidate == null
        ? ''
        : _dateFromMrz(birthCandidate.yymmdd);
    final sexo = birthCandidate?.sex ?? '';

    var apellidoPaterno = '';
    var nombres = '';
    if (nameLineIndex != null) {
      final parsedNames = _parseMrzNameLine(compactLines[nameLineIndex]);
      apellidoPaterno = parsedNames.apellidoPaterno;
      nombres = parsedNames.nombres;
    }

    return _MrzData(
      dni: dni,
      fechaNacimiento: fecha,
      sexo: sexo,
      apellidoPaterno: apellidoPaterno,
      nombres: nombres,
    );
  }

  static _NameData _inferNamesFromLayout(List<String> lines, _MrzData mrz) {
    final candidates = <String>[];
    for (final line in lines) {
      final candidate = _cleanNameCandidate(line);
      if (candidate == null) continue;
      if (_isNearDuplicate(candidate, candidates)) continue;
      candidates.add(candidate);
    }

    var apellidoPaterno = mrz.apellidoPaterno;
    var nombres = mrz.nombres;
    var apellidoMaterno = '';

    if (apellidoPaterno.isEmpty && candidates.isNotEmpty) {
      apellidoPaterno = _bestSurnameCandidate(candidates) ?? candidates.first;
    }
    if (nombres.isEmpty) {
      nombres =
          _bestGivenNameCandidate(
            candidates
                .where(
                  (candidate) => !_samePersonValue(candidate, apellidoPaterno),
                )
                .toList(),
          ) ??
          (candidates.length >= 3 ? candidates[2] : '');
    }

    for (final candidate in candidates) {
      if (_samePersonValue(candidate, apellidoPaterno)) continue;
      if (_samePersonValue(candidate, nombres)) continue;
      if (apellidoPaterno.isNotEmpty && candidate.contains(apellidoPaterno)) {
        continue;
      }
      if (nombres.isNotEmpty && candidate.contains(nombres)) continue;
      apellidoMaterno = candidate;
      break;
    }

    if (apellidoMaterno.isEmpty && candidates.length >= 2) {
      apellidoMaterno = candidates[1];
    }

    return _NameData(
      apellidoPaterno: apellidoPaterno,
      apellidoMaterno: apellidoMaterno,
      nombres: nombres,
    );
  }

  static int? _findMrzNameLineIndex(List<String> compactLines, String dni) {
    for (var index = compactLines.length - 1; index >= 0; index--) {
      if (_looksLikeMrzNameLine(compactLines[index], dni)) return index;
    }
    return null;
  }

  static _NameData _parseMrzNameLine(String line) {
    final separator = line.indexOf('<<');
    if (separator == -1) {
      return const _NameData(
        apellidoPaterno: '',
        apellidoMaterno: '',
        nombres: '',
      );
    }

    // MRZ DNI rule: left side of "<<" is paternal surname; right side
    // contains given names separated by single "<" characters.
    final apellido = _cleanMrzSurnameValue(line.substring(0, separator));
    final nameArea = line
        .substring(separator + 2)
        .replaceAll(RegExp(r'<+$'), '');
    final nombres = nameArea
        .split('<')
        .where((part) => part.trim().isNotEmpty)
        .map(_cleanMrzNameValue)
        .expand(_splitMrzGivenNamePart)
        .where((part) => part.isNotEmpty && !_looksLikeMrzFiller(part))
        .join(' ');

    final cleanNombres = _removeSurnameFromGivenNames(apellido, nombres);

    return _NameData(
      apellidoPaterno: apellido,
      apellidoMaterno: '',
      nombres: cleanNombres,
    );
  }

  static String _cleanMrzNameValue(String value) {
    return _normalizeKnownNameNoise(
      _cleanFieldValue(value.replaceAll('<', ' '))
          .replaceAll(RegExp(r'[^A-ZÑ ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    );
  }

  static String _cleanMrzSurnameValue(String value) {
    final clean = _cleanFieldValue(value.replaceAll('<', ' '))
        .replaceAll(RegExp(r'[^A-ZÑ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final tokens = clean
        .split(' ')
        .where((token) => token.isNotEmpty)
        .map(_normalizeSurnameToken)
        .toList();
    return tokens.join(' ');
  }

  static String _normalizeSurnamePhrase(String value) {
    final tokens = value
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .map(_normalizeSurnameToken)
        .toList();
    return tokens.join(' ');
  }

  static String _normalizeSurnameToken(String token) {
    if (_nameParticles.contains(token)) return token;

    final structuralFixed = _fixSpanishNamePatterns(
      _normalizeNameDigits(token),
    );
    final canonical = _canonicalPersonValue(structuralFixed);
    if (canonical.isEmpty) return token;
    if (canonical == 'OENTE' ||
        canonical == 'OENTEND' ||
        canonical == 'OENTSNO' ||
        canonical == 'OENENO') {
      return 'GESTEJO';
    }
    if (_surnameLexicon.contains(canonical)) return canonical;
    if (canonical.startsWith('DE') &&
        canonical.length > 2 &&
        _surnameLexicon.contains(canonical.substring(2))) {
      return 'DE ${canonical.substring(2)}';
    }
    if (canonical.startsWith('VDADE') &&
        canonical.length > 5 &&
        _surnameLexicon.contains(canonical.substring(5))) {
      return 'VDA DE ${canonical.substring(5)}';
    }

    String? best;
    var bestDistance = 99;
    for (final expected in _surnameLexicon) {
      final distance = _levenshtein(canonical, expected);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = expected;
      }
    }
    if (best != null && bestDistance <= 1) return best;
    return structuralFixed;
  }

  static _MrzBirthCandidate? _findMrzBirthCandidate(
    List<String> compactLines, {
    int? nameLineIndex,
  }) {
    final candidates = <_MrzBirthCandidate>[];
    for (var index = 0; index < compactLines.length; index++) {
      final line = compactLines[index];
      if (line.startsWith(RegExp(r'[I1L]<'))) continue;
      final distanceToName = nameLineIndex == null
          ? null
          : (nameLineIndex - index).abs();
      candidates.addAll(
        _mrzBirthCandidatesFromLine(line, distanceToName: distanceToName),
      );
    }
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.score >= 20 ? candidates.first : null;
  }

  static List<_MrzBirthCandidate> _mrzBirthCandidatesFromLine(
    String line, {
    int? distanceToName,
  }) {
    final candidates = <_MrzBirthCandidate>[];
    final matches = RegExp(
      r'(?<![0-9])([0-9]{6})([0-9A-Z]?)([MF]?)',
    ).allMatches(line);
    for (final match in matches) {
      final yymmdd = match.group(1)!;
      if (!_looksLikeMrzBirth(yymmdd)) continue;

      final sex = match.group(3) ?? '';
      var score = 10;
      if (distanceToName == 1) score += 14;
      if (distanceToName == 2) score += 5;
      if (match.start == 0) score += 8;
      if (line.length >= 14) score += 7;
      if (line.contains('PER')) score += 8;
      if (sex == 'M' || sex == 'F') score += 5;
      if (RegExp(r'^[0-9]{6}[0-9]').hasMatch(line)) {
        score += 8;
      } else {
        score -= 8;
      }
      if (_looksLikePrintedDatePrefix(line)) score -= 10;
      if (RegExp(r'[<]{2,}').hasMatch(line)) score += 2;
      if (RegExp(r'[^0-9A-Z<]').hasMatch(line)) score -= 2;

      candidates.add(
        _MrzBirthCandidate(yymmdd: yymmdd, sex: sex, score: score),
      );
    }
    return candidates;
  }

  static bool _looksLikeMrzNameLine(String line, String dni) {
    if (!line.contains('<<')) return false;
    if (line.contains('PER$dni')) return false;
    if (line.startsWith(RegExp(r'[0-9]'))) return false;
    if (line.contains('PER') && !line.contains('<<')) return false;
    final separator = line.indexOf('<<');
    final left = line.substring(0, separator).replaceAll('<', '');
    final right = line.substring(separator + 2).replaceAll('<', '');
    if (left.length < 3 || right.length < 3) return false;
    final clean = line.replaceAll('<', '');
    return RegExp(r'^[A-ZÑ]{3,}$').hasMatch(clean);
  }

  static String? _extractNameSection(
    List<String> lines,
    List<String> startLabels,
  ) {
    final fromLines = _valueBetweenLabels(lines, startLabels, _nameStopLabels);
    if (fromLines != null) return fromLines;

    final normalizedText = lines.join(' ');
    return _valueBetweenLabelsInText(
      normalizedText,
      startLabels,
      _nameStopLabels,
    );
  }

  static String? _valueBetweenLabels(
    List<String> lines,
    List<String> startLabels,
    List<String> stopLabels,
  ) {
    for (var index = 0; index < lines.length; index++) {
      final startMatch = _findLabelMatch(lines[index], startLabels);
      if (startMatch == null) continue;

      final sameLine = _cleanNameCandidate(
        lines[index].substring(startMatch.end),
      );
      if (sameLine != null) return sameLine;

      final candidates = <String>[];
      final maxLookAhead = (index + 7).clamp(0, lines.length);
      for (var next = index + 1; next < maxLookAhead; next++) {
        if (_containsAnyLabel(lines[next], stopLabels)) {
          final beforeStop = _cleanNameCandidate(lines[next]);
          if (beforeStop != null) candidates.add(beforeStop);
          break;
        }
        final candidate = _cleanNameCandidate(lines[next]);
        if (candidate != null) candidates.add(candidate);
      }
      final best = _bestPrintedNameCandidate(candidates);
      if (best != null) return best;
    }
    return null;
  }

  static String? _valueBetweenLabelsInText(
    String text,
    List<String> startLabels,
    List<String> stopLabels,
  ) {
    final startMatch = _findLabelMatch(text, startLabels);
    if (startMatch == null) return null;

    final from = startMatch.end;
    var to = text.length;
    for (final stopMatch in _findAllLabelMatches(text, stopLabels)) {
      if (stopMatch.start > from && stopMatch.start < to) {
        to = stopMatch.start;
      }
    }

    if (to > from) {
      final candidate = _cleanNameCandidate(text.substring(from, to));
      if (candidate != null) return candidate;
    }
    return null;
  }

  static bool _containsAnyLabel(String value, List<String> labels) {
    return _findLabelMatch(value, labels) != null;
  }

  static String _dateFromMrz(String yymmdd) {
    final yy = int.parse(yymmdd.substring(0, 2));
    final mm = yymmdd.substring(2, 4);
    final dd = yymmdd.substring(4, 6);
    final currentTwoDigitYear = DateTime.now().year % 100;
    final century = yy > currentTwoDigitYear ? 1900 : 2000;
    return _formatDate(dd, mm, '${century + yy}');
  }

  static String _formatDate(String day, String month, String year) {
    return '${day.padLeft(2, '0')}/${month.padLeft(2, '0')}/$year';
  }

  static String _cleanFieldValue(String value) {
    return value
        .replaceAll(RegExp(r'[:;|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
  }

  static String? _cleanNameCandidate(String value) {
    final rawSegment = _cutBeforeAnyLabel(value, _identityLabels);
    if (rawSegment.contains('<<') ||
        RegExp(r'\bPER\b', caseSensitive: false).hasMatch(rawSegment)) {
      return null;
    }
    if (RegExp(r'[0-9]{5,}').hasMatch(rawSegment)) return null;

    var clean = _cleanFieldValue(_normalizeNameDigits(rawSegment))
        .replaceAll(RegExp(r'[^A-ZÑ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return null;

    final tokens = clean
        .split(' ')
        .where((token) => token.length > 1 || token == 'Y')
        .toList();
    clean = tokens.join(' ');
    if (clean.isEmpty) return null;
    if (_looksLikeLabel(clean) || _looksLikeNonNameValue(clean)) return null;
    return _normalizeKnownNameNoise(clean);
  }

  static bool _looksLikeNonNameValue(String value) {
    final upper = value.toUpperCase();
    if (upper.contains('<<') || RegExp(r'\bPER\b').hasMatch(upper)) {
      return true;
    }
    if (RegExp(r'^[0-9 /-]+$').hasMatch(upper)) return true;
    if (RegExp(
      r'(DNI|CUI|FECHA|UBIGEO|NACIMIENTO|EMISION|CADUCIDAD)',
    ).hasMatch(upper)) {
      return true;
    }
    if (RegExp(
      r'\b(REPUBLICA|DOCUMENTO|IDENTIDAD|NACIONALIDAD|DOMICILIO)\b',
    ).hasMatch(upper)) {
      return true;
    }
    if (upper.length > 36) return true;
    return false;
  }

  static bool _isNearDuplicate(String value, List<String> candidates) {
    for (final candidate in candidates) {
      if (_samePersonValue(value, candidate)) return true;
    }
    return false;
  }

  static bool _samePersonValue(String left, String right) {
    if (left.isEmpty || right.isEmpty) return false;
    final a = _canonicalPersonValue(left);
    final b = _canonicalPersonValue(right);
    if (a == b) return true;
    if (a.length >= 5 && b.length >= 5) {
      return _levenshtein(a, b) <= 1;
    }
    return false;
  }

  static String _canonicalPersonValue(String value) {
    return _canonicalToken(value).replaceAll(RegExp(r'\s+'), '');
  }

  static String _chooseName(String? printed, String fallback) {
    final cleanPrinted = printed == null
        ? null
        : _normalizeKnownNameNoise(printed);
    if (cleanPrinted == null || cleanPrinted.isEmpty) return fallback;
    if (fallback.isEmpty) return cleanPrinted;
    if (_samePersonValue(cleanPrinted, fallback)) return fallback;
    if (_isExactNameLexicon(fallback) && !_isExactNameLexicon(cleanPrinted)) {
      return fallback;
    }
    if (_canonicalPersonValue(cleanPrinted).length <= 7 &&
        _levenshtein(
              _canonicalPersonValue(cleanPrinted),
              _canonicalPersonValue(fallback),
            ) >
            2) {
      return fallback;
    }
    return cleanPrinted;
  }

  static String _chooseSurname(String? printed, String fallback) {
    final cleanPrinted = printed == null
        ? null
        : _normalizeSurnamePhrase(printed);
    final cleanFallback = _normalizeSurnamePhrase(fallback);
    if (cleanPrinted == null || cleanPrinted.isEmpty) return cleanFallback;
    if (cleanFallback.isEmpty) return cleanPrinted;
    if (_samePersonValue(cleanPrinted, cleanFallback)) return cleanFallback;

    final printedTokens = cleanPrinted.split(' ');
    final fallbackTokens = cleanFallback.split(' ');
    if (printedTokens.any(_isMaternalOnlyParticle) &&
        fallbackTokens.length == 1 &&
        _surnameLexicon.contains(_canonicalPersonValue(cleanFallback))) {
      return cleanFallback;
    }

    final printedScore = _surnameChoiceScore(cleanPrinted);
    final fallbackScore = _surnameChoiceScore(cleanFallback);
    return fallbackScore > printedScore ? cleanFallback : cleanPrinted;
  }

  static int _surnameChoiceScore(String value) {
    final tokens = value
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();
    if (tokens.isEmpty) return -20;
    var score = 0;
    for (final token in tokens) {
      final canonical = _canonicalPersonValue(token);
      if (_nameParticles.contains(token)) {
        score += 1;
      } else if (_surnameLexicon.contains(canonical)) {
        score += 10;
      } else if (_looksLikeTextNoise(canonical)) {
        score -= 8;
      } else {
        score += 1;
      }
    }
    if (tokens.length == 1) score += 3;
    if (tokens.any(_isMaternalOnlyParticle)) score -= 4;
    return score;
  }

  static bool _isMaternalOnlyParticle(String token) {
    return token == 'VDA' || token == 'VIUDA' || token == 'DE';
  }

  static String _removeSurnameFromGivenNames(String apellido, String nombres) {
    final cleanNames = _normalizeKnownNameNoise(nombres);
    if (apellido.isEmpty || cleanNames.isEmpty) return cleanNames;

    final surnameTokens = apellido
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();
    final nameTokens = cleanNames
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();

    while (surnameTokens.isNotEmpty &&
        nameTokens.isNotEmpty &&
        _samePersonValue(nameTokens.first, surnameTokens.last)) {
      nameTokens.removeAt(0);
    }

    if (nameTokens.length >= 2 &&
        _samePersonValue(nameTokens.first, apellido)) {
      nameTokens.removeAt(0);
    }

    return nameTokens.join(' ');
  }

  static Iterable<String> _splitMrzGivenNamePart(String value) {
    if (value.isEmpty || _looksLikeMrzFiller(value)) return const [];
    final direct = _normalizeNameToken(value);
    if (_givenNameLexicon.contains(_canonicalPersonValue(direct))) {
      return [direct];
    }

    final compact = _canonicalPersonValue(value);
    for (var split = 3; split <= compact.length - 3; split++) {
      final left = compact.substring(0, split);
      final right = compact.substring(split);
      final leftName = _nearestLexiconName(left);
      final rightName = _nearestLexiconName(right);
      if (leftName != null && rightName != null) return [leftName, rightName];

      if (right.startsWith('K') && right.length > 3) {
        final rightWithoutFiller = _nearestLexiconName(right.substring(1));
        if (leftName != null && rightWithoutFiller != null) {
          return [leftName, rightWithoutFiller];
        }
      }
    }
    return [direct];
  }

  static bool _looksLikeMrzFiller(String value) {
    final compact = _canonicalPersonValue(value);
    if (compact.isEmpty) return true;
    if (RegExp(r'^[KX]+$').hasMatch(compact)) return true;
    if (compact.length <= 2 && !_givenNameLexicon.contains(compact)) {
      return true;
    }
    return false;
  }

  static String? _bestSurnameCandidate(List<String> candidates) {
    String? best;
    var bestScore = -1;
    for (final candidate in candidates) {
      final tokens = candidate.split(' ');
      if (tokens.length != 1) continue;
      final canonical = _canonicalPersonValue(candidate);
      var score = 0;
      if (_surnameLexicon.contains(canonical)) score += 20;
      if (_givenNameLexicon.contains(canonical)) score -= 6;
      if (candidate.length >= 4 && candidate.length <= 14) score += 2;
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return bestScore > 0 ? best : null;
  }

  static String? _bestGivenNameCandidate(List<String> candidates) {
    String? best;
    var bestScore = -999;
    for (final candidate in candidates) {
      final tokens = candidate
          .split(' ')
          .where((token) => token.trim().isNotEmpty)
          .toList();
      if (tokens.isEmpty || tokens.length > 4) continue;

      var score = 0;
      var knownGiven = 0;
      for (final token in tokens) {
        final canonical = _canonicalPersonValue(token);
        if (_givenNameLexicon.contains(canonical)) {
          knownGiven++;
          score += 12;
        } else if (_surnameLexicon.contains(canonical)) {
          score -= 7;
        } else if (_looksLikeTextNoise(canonical)) {
          score -= 9;
        } else {
          score += 1;
        }
      }
      if (knownGiven > 0) score += 6;
      if (tokens.length > 1) score += 2;
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return bestScore > 0 ? best : null;
  }

  static String? _bestPrintedNameCandidate(List<String> candidates) {
    String? best;
    var bestScore = -999;
    for (final candidate in candidates) {
      final score = _printedNameScore(candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return bestScore > 0 ? best : null;
  }

  static int _printedNameScore(String value) {
    final tokens = value
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty || tokens.length > 5) return -20;

    var score = 0;
    var strongTokens = 0;
    for (final token in tokens) {
      final canonical = _canonicalPersonValue(token);
      if (_nameParticles.contains(token)) {
        score += 1;
        continue;
      }
      if (canonical.length < 3) {
        score -= 3;
        continue;
      }
      if (_nameLexicon.contains(canonical)) {
        score += 8;
        strongTokens++;
      } else if (RegExp(r'^[A-ZÑ]{3,14}$').hasMatch(token)) {
        score += 3;
      } else {
        score -= 6;
      }
      if (_looksLikeTextNoise(canonical)) score -= 8;
    }
    if (strongTokens > 0) score += 4;
    if (tokens.length >= 2) score += 2;
    if (value.length > 34) score -= 8;
    return score;
  }

  static bool _looksLikeTextNoise(String canonical) {
    if (canonical.isEmpty) return true;
    if (RegExp(
      r'(NACIONAL|DOCUMENTO|IDENTIDAD|FECHA|UBIGEO|ESTADO|CIVIL)',
    ).hasMatch(canonical)) {
      return true;
    }
    final vowels = RegExp(r'[AEIOU]').allMatches(canonical).length;
    if (canonical.length >= 5 && vowels == 0) return true;
    return false;
  }

  static bool _isExactNameLexicon(String value) {
    final tokens = value.split(' ');
    if (tokens.isEmpty) return false;
    return tokens.every((token) {
      final canonical = _canonicalPersonValue(token);
      return _nameParticles.contains(token) || _nameLexicon.contains(canonical);
    });
  }

  static String _normalizeNameDigits(String value) {
    return value
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('2', 'Z')
        .replaceAll('5', 'S')
        .replaceAll('8', 'B');
  }

  static String _normalizeKnownNameNoise(String value) {
    final tokens = value.split(' ').map(_normalizeNameToken).toList();
    return tokens.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeNameToken(String token) {
    if (_nameParticles.contains(token)) return token;

    final digitFixed = _normalizeNameDigits(token);
    final structuralFixed = _fixSpanishNamePatterns(digitFixed);
    final canonical = _canonicalPersonValue(structuralFixed);
    if (canonical.isEmpty) return token;

    final lexiconMatch = _nearestLexiconName(canonical);
    return lexiconMatch ?? structuralFixed;
  }

  static String _fixSpanishNamePatterns(String token) {
    var fixed = token.toUpperCase();
    fixed = fixed.replaceAll(RegExp(r'[^A-ZÑ]'), '').replaceAll('VV', 'W');

    // DNI photocopies often compress "GUEZ" into "GBEZ"/"G8EZ".
    fixed = fixed.replaceAll(RegExp(r'G[BU8]EZ$'), 'GUEZ');
    fixed = fixed.replaceAll(RegExp(r'([A-Z])\1{2,}$'), r'$1');

    // OCR sometimes prefixes a dark stroke as S before short given names.
    if (fixed.startsWith('S') && fixed.length >= 5) {
      final withoutLeadingNoise = fixed.substring(1);
      final candidate = _nearestLexiconName(
        _canonicalPersonValue(withoutLeadingNoise),
        maxDistance: 2,
      );
      if (candidate != null) return candidate;
    }
    return fixed;
  }

  static String? _nearestLexiconName(String canonical, {int? maxDistance}) {
    String? best;
    var bestDistance = 99;
    for (final expected in _nameLexicon) {
      final distance = _levenshtein(canonical, expected);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = expected;
      }
    }
    if (best == null) return null;

    final allowedDistance =
        maxDistance ??
        (canonical.length <= 5
            ? 1
            : canonical.length <= 8
            ? 2
            : 2);
    if (bestDistance <= allowedDistance) return best;
    return null;
  }

  static String _digitsFromOcr(String value) {
    return value
        .toUpperCase()
        .replaceAll('O', '0')
        .replaceAll('Q', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('S', '5')
        .replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool _looksLikeBirthOrMrzNumber(String value) {
    if (value.length < 6) return false;
    final firstSix = value.substring(0, 6);
    return _looksLikeMrzBirth(firstSix) ||
        RegExp(r'^(19|20)[0-9]{2}').hasMatch(value);
  }

  static bool _looksLikeMrzBirth(String yymmdd) {
    if (yymmdd.length != 6) return false;
    final month = int.tryParse(yymmdd.substring(2, 4)) ?? 0;
    final day = int.tryParse(yymmdd.substring(4, 6)) ?? 0;
    return month >= 1 && month <= 12 && day >= 1 && day <= 31;
  }

  static bool _looksLikePrintedDatePrefix(String value) {
    if (value.length < 8) return false;
    final yearLike = value.substring(4, 8);
    return RegExp(r'^(19|20)[0-9]{2}$').hasMatch(yearLike);
  }

  static bool _looksLikeLabel(String value) {
    return _containsAnyLabel(value, _documentLabels);
  }

  static String _cutBeforeAnyLabel(String value, List<String> labels) {
    final match = _findLabelMatch(value, labels);
    if (match == null) return value;
    if (match.start <= 0) return '';
    return value.substring(0, match.start);
  }

  static _LabelMatch? _findLabelMatch(String value, List<String> labels) {
    final matches = _findAllLabelMatches(value, labels);
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return b.end.compareTo(a.end);
    });
    return matches.first;
  }

  static List<_LabelMatch> _findAllLabelMatches(
    String value,
    List<String> labels,
  ) {
    final tokens = _tokenize(value);
    if (tokens.isEmpty) return const [];

    final matches = <_LabelMatch>[];
    for (final label in labels) {
      final labelTokens = _tokenize(label);
      if (labelTokens.isEmpty) continue;
      final length = labelTokens.length;
      if (tokens.length < length) continue;

      for (var index = 0; index <= tokens.length - length; index++) {
        var ok = true;
        for (var offset = 0; offset < length; offset++) {
          if (!_tokensLookAlike(
            tokens[index + offset].canonical,
            labelTokens[offset].canonical,
          )) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        matches.add(
          _LabelMatch(tokens[index].start, tokens[index + length - 1].end),
        );
      }
    }
    return matches;
  }

  static List<_Token> _tokenize(String value) {
    return RegExp(r'[A-Za-z0-9Ññ]+')
        .allMatches(value)
        .map((match) {
          final raw = match.group(0)!;
          return _Token(
            canonical: _canonicalToken(raw),
            start: match.start,
            end: match.end,
          );
        })
        .where((token) => token.canonical.isNotEmpty)
        .toList();
  }

  static String _canonicalToken(String value) {
    return value
        .toUpperCase()
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('|', 'I')
        .replaceAll('5', 'S')
        .replaceAll('8', 'B')
        .replaceAll(RegExp(r'[^A-ZÑ]'), '');
  }

  static bool _tokensLookAlike(String value, String expected) {
    if (value == expected) return true;
    if (expected.length <= 3) return false;
    final distance = _levenshtein(value, expected);
    if (expected.length <= 5) return distance <= 1;
    return distance <= 2;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((min, value) => value < min ? value : min);
      }
      previous = current;
    }
    return previous.last;
  }

  static const _identityLabels = [
    'PRIMER APELLIDO',
    'APELLIDO PATERNO',
    'APALDO',
    'PIMO ABELDO',
    'PRIMER APELHDO',
    'RIMER APETHOO',
    'SEGUNDO APELLIDO',
    'APELLIDO MATERNO',
    'SOGINCLO APELLIDO',
    'SEGUNTO APELIO',
    'SEGUNTO APELLIDO',
    'SEGUNDO APELIDO',
    'SEGUNO APELG',
    'SEGUNDO APEL',
    'EGUNDD APETID',
    'EGUNDO APETID',
    'SUNAD APED',
    'PRE NOMBRES',
    'PRENOMBRES',
    'PRE-NOMBRES',
    'NOMBRES',
    'PRUNONBROD',
    'PRU NOBROD',
    'PE NAMBRES',
    'PE NAMBRAS',
    'SEXO',
    'ESTADO CIVIL',
    'NACIMIENTO',
    'NABIONTO',
    'FECHA',
    'UBIGEO',
    'DNI',
    'CUI',
    'DOMICILIO',
  ];

  static const _nameStopLabels = [
    'SEGUNDO APELLIDO',
    'APELLIDO MATERNO',
    'SOGINCLO APELLIDO',
    'SEGUNTO APELIO',
    'SEGUNTO APELLIDO',
    'SEGUNDO APELIDO',
    'SEGUNO APELG',
    'SEGUNDO APEL',
    'EGUNDD APETID',
    'EGUNDO APETID',
    'SUNAD APED',
    'PRE NOMBRES',
    'PRENOMBRES',
    'PRE-NOMBRES',
    'NOMBRES',
    'PRUNONBROD',
    'PRU NOBROD',
    'PE NAMBRES',
    'PE NAMBRAS',
    'SEXO',
    'ESTADO CIVIL',
    'NACIMIENTO',
    'NABIONTO',
    'UBIGEO',
    'DNI',
    'CUI',
    'DOMICILIO',
  ];

  static const _documentLabels = [
    ..._identityLabels,
    'REPUBLICA',
    'PERU',
    'DOCUMENTO',
    'NACIONAL',
    'IDENTIDAD',
    'NACIONALIDAD',
  ];

  static const _nameParticles = {
    'DE',
    'DEL',
    'LA',
    'LAS',
    'LOS',
    'SAN',
    'SANTA',
    'VDA',
    'VIUDA',
    'Y',
  };

  static const _nameLexicon = {..._givenNameLexicon, ..._surnameLexicon};

  static const _givenNameLexicon = {
    // Nombres frecuentes en padrones peruanos. Se usa solo como correccion
    // conservadora cuando el OCR queda a 1-2 ediciones del valor esperado.
    'ALICIA',
    'ANA',
    'ANDREA',
    'ANGELA',
    'ANTONIA',
    'ANTONIO',
    'BEATRIZ',
    'CARLOS',
    'CARMEN',
    'CESAR',
    'CLAUDIA',
    'DANIEL',
    'DIEGO',
    'ELENA',
    'ELIZABETH',
    'EMILIA',
    'ENRIQUE',
    'ERNESTO',
    'FELIX',
    'FERNANDO',
    'FRANCISCA',
    'GLORIA',
    'GUILLERMO',
    'HILDA',
    'ISABEL',
    'JAVIER',
    'JORGE',
    'JOSE',
    'JUAN',
    'JUANA',
    'JULIA',
    'JULIO',
    'LUIS',
    'LUISA',
    'MANUEL',
    'MARIA',
    'MARIO',
    'MARTIN',
    'MIGUEL',
    'NANCY',
    'OSCAR',
    'PATRICIA',
    'PEDRO',
    'RAFAEL',
    'ROSA',
    'SARA',
    'TERESA',
    'VICTOR',
  };

  static const _surnameLexicon = {
    // Apellidos frecuentes y terminaciones sensibles al OCR de fotocopias.
    'AGUILAR',
    'ALVAREZ',
    'ARIAS',
    'AYALA',
    'BENDEZU',
    'BRAVO',
    'CABRERA',
    'CACERES',
    'CALDERON',
    'CANAZA',
    'CASTILLO',
    'CHAVEZ',
    'CONDORI',
    'CRUZ',
    'DIAZ',
    'ESPINOZA',
    'FERNANDEZ',
    'FLORES',
    'GARCIA',
    'GOMEZ',
    'GONZALES',
    'GONZALEZ',
    'GESTEJO',
    'GUTIERREZ',
    'HERNANDEZ',
    'HUAMAN',
    'HUAMANI',
    'JIMENEZ',
    'LOPEZ',
    'MAMANI',
    'MARAZA',
    'MARTINEZ',
    'MEDINA',
    'MENDOZA',
    'MORALES',
    'NAVARRO',
    'NUNEZ',
    'ORTIZ',
    'PAUCARA',
    'PEREZ',
    'QUISPE',
    'RAMIREZ',
    'RAMOS',
    'REYES',
    'RIVERA',
    'RODRIGUEZ',
    'ROJAS',
    'ROMERO',
    'SALAZAR',
    'SANCHEZ',
    'SILVA',
    'SOTO',
    'TORRES',
    'VARGAS',
    'VASQUEZ',
    'VEGA',
    'VELASQUEZ',
    'ZAMBRANO',
  };
}

class _Token {
  const _Token({
    required this.canonical,
    required this.start,
    required this.end,
  });

  final String canonical;
  final int start;
  final int end;
}

class _LabelMatch {
  const _LabelMatch(this.start, this.end);

  final int start;
  final int end;
}

class _MrzData {
  const _MrzData({
    required this.dni,
    required this.fechaNacimiento,
    required this.sexo,
    required this.apellidoPaterno,
    required this.nombres,
  });

  final String dni;
  final String fechaNacimiento;
  final String sexo;
  final String apellidoPaterno;
  final String nombres;
}

class _MrzBirthCandidate {
  const _MrzBirthCandidate({
    required this.yymmdd,
    required this.sex,
    required this.score,
  });

  final String yymmdd;
  final String sex;
  final int score;
}

class _NameData {
  const _NameData({
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.nombres,
  });

  final String apellidoPaterno;
  final String apellidoMaterno;
  final String nombres;
}
