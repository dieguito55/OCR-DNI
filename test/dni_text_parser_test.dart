import 'package:flutter_test/flutter_test.dart';
import 'package:xiomi/services/dni_text_parser.dart';

void main() {
  test('extrae DNI y nacimiento desde MRZ de DNI peruano', () {
    const text = '''
REPUBLICA DEL PERU
Primer Apellido
CANAZA
Segundo Apellido
PAUCARA
Pre Nombres
JUAN DIEGO
Nacimiento: Fecha y Ubigeo
10 06 2003 200901
Sexo Estado Civil
M S
I<PER75329710<2<<<<<<<<<<<<<<<<
0306104M2905121PER<<<<<<<<<<<<4
CANAZA<<JUAN<DIEGO<<<<<<<<<<<
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.dni, '75329710');
    expect(persona.fechaNacimiento, '10/06/2003');
    expect(persona.apellidoPaterno, 'CANAZA');
    expect(persona.apellidoMaterno, 'PAUCARA');
    expect(persona.nombres, 'JUAN DIEGO');
    expect(persona.sexo, 'M');
  });

  test('prioriza campos impresos por seccion antes que MRZ', () {
    const text = '''
REPUBLICA DEL PERU Documento Nacional de Identidad
Primer Apellido
CANAZA
Segundo Apellido
PAUCARA
Pre Nombres
JUAN DIEGO
Sexo Estado Civil
M S
Fecha de Nacimiento
10/06/2003
I<PER75329710<2<<<<<<<<<<<<<<<<
0306104M2905121PER<<<<<<<<<<<<4
CANAZA<<JUAN<DIEGO<<<<<<<<<<<
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.apellidoPaterno, 'CANAZA');
    expect(persona.apellidoMaterno, 'PAUCARA');
    expect(persona.nombres, 'JUAN DIEGO');
  });

  test('extrae nombres cuando OCR junta etiquetas en una sola linea', () {
    const text = '''
Primer Apellido CANAZA Segundo Apellido PAUCARA Pre Nombres JUAN DIEGO
Sexo M Fecha Nacimiento 10 06 2003
I<PER75329710<2<<<<<<<<<<<<<<<<
0306104M2905121PER<<<<<<<<<<<<4
CANAZA<<JUAN<DIEGO<<<<<<<<<<<
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.apellidoPaterno, 'CANAZA');
    expect(persona.apellidoMaterno, 'PAUCARA');
    expect(persona.nombres, 'JUAN DIEGO');
  });

  test('tolera etiquetas deformadas por OCR en campos del DNI', () {
    const text = '''
REPUBLICA DEL PERU
PR1MER APELL1DO
CANAZA
SEGUND0 APELL1D0
PAUCARA
PRE N0MBRES
JUAN DIEGO
SEXO ESTADO CIVIL
M S
FECHA NACIMIENTO
10 06 2003
DNI 75329710
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.apellidoPaterno, 'CANAZA');
    expect(persona.apellidoMaterno, 'PAUCARA');
    expect(persona.nombres, 'JUAN DIEGO');
    expect(persona.dni, '75329710');
    expect(persona.fechaNacimiento, '10/06/2003');
  });

  test('corta apellido paterno antes de la etiqueta segundo apellido', () {
    const text = '''
Primer Apellido
CANAZA Segundo Apellido
PAUCARA
Pre Nombres
JUAN DIEGO
DNI 75329710
Nacimiento 10/06/2003
Sexo M
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.apellidoPaterno, 'CANAZA');
    expect(persona.apellidoMaterno, 'PAUCARA');
    expect(persona.nombres, 'JUAN DIEGO');
  });

  test('no descarta apellidos que empiezan como PER', () {
    const text = '''
Primer Apellido
PEREZ
Segundo Apellido
QUISPE
Pre Nombres
ANA MARIA
DNI 75329710
Nacimiento 10/06/2003
Sexo F
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.apellidoPaterno, 'PEREZ');
    expect(persona.apellidoMaterno, 'QUISPE');
    expect(persona.nombres, 'ANA MARIA');
  });

  test('salta textos laterales entre etiqueta y apellido paterno', () {
    const text = '''
CUI
Primer Apellido
Fecha Inscripcion
CANAZA
18112010
FechaEmision
Segundo Apellido
12052021
PAUCARA
Fecha Caducidad
Pre Nombres
12062029
JUAN DIEGO
NacimientoFechayUbigeo
10062003
200901
Estado Civil
Sexo
M
S
I<PER75329710K2<<<
030610M2905121PER
CANAZA<<JUAN<DIEGO
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.apellidoPaterno, 'CANAZA');
    expect(persona.apellidoMaterno, 'PAUCARA');
    expect(persona.nombres, 'JUAN DIEGO');
    expect(persona.dni, '75329710');
    expect(persona.fechaNacimiento, '10/06/2003');
    expect(persona.sexo, 'M');
  });

  test('extrae campos desde caso real ruidoso con DNI antiguo', () {
    const text = '''
REPUBLICA DEL PERU DOCUMENTO NACIONAL DE IDENTIDAD DNI 01344111
Primer Apellido
GOMEZ
Segundo Apellido
VDA DE RODRIGUEZ
Pre Nombres
ALICIA
Nacimiento Fecha y Ubigeo
29 08 1959 200407
Sexo Estado Civil
F V
I<PER01344111<7<<<<<<<<<<<<
5908293F0001018PER<<<<<<<<<0
GOMEZ<<ALICIA<<<<<<<<<<<<<<
''';

    final persona = DniTextParser.parse(text, '/tmp/casoreal.jpg');

    expect(persona.dni, '01344111');
    expect(persona.apellidoPaterno, 'GOMEZ');
    expect(persona.apellidoMaterno, 'VDA DE RODRIGUEZ');
    expect(persona.nombres, 'ALICIA');
    expect(persona.fechaNacimiento, '29/08/1959');
    expect(persona.sexo, 'F');
  });

  test('normaliza salida real ruidosa de ML Kit y Paddle', () {
    const text = '''
0.1
coCNTO NAGiONALOSADlbNID344017
Apaldo
OUME22A
Soginclo Apellido.
VDA DE RODRIGbEZ
PruNonbrod
SALIGIA
Nabionto ch yUDigeo
O9 08;1959200407
KPERO1311
590823F000 V0 18PER
GOME ZKKATCtAR
o1344114
01344111
1959
59082930001018P
GOMEZ
ROORIGUE:
''';

    final persona = DniTextParser.parse(text, '/tmp/casoreal.jpg');

    expect(persona.dni, '01344111');
    expect(persona.apellidoPaterno, 'GOMEZ');
    expect(persona.apellidoMaterno, 'VDA DE RODRIGUEZ');
    expect(persona.nombres, 'ALICIA');
    expect(persona.fechaNacimiento, '29/08/1959');
    expect(persona.sexo, 'F');
  });

  test('prioriza nombres y primer apellido desde MRZ inferior', () {
    const text = '''
Primer Apellido
GOMFZ
Segundo Apellido
VDA DE RODRIGUEZ
Pre Nombres
SALTGIA
Nacimiento Fecha y Ubigeo
29 08 1959 200407
01344111
5908293F0001018PER<<<<<<<<<0
GOMEZ<<ALICIA<<<<<<<<<<<<<<
''';

    final persona = DniTextParser.parse(text, '/tmp/casoreal.jpg');

    expect(persona.apellidoPaterno, 'GOMEZ');
    expect(persona.apellidoMaterno, 'VDA DE RODRIGUEZ');
    expect(persona.nombres, 'ALICIA');
    expect(persona.fechaNacimiento, '29/08/1959');
  });

  test('elige fecha MRZ mas confiable cuando borde inferior trae ruido', () {
    const text = '''
Nacimiento Fecha y Ubigeo
09 08 1959 200407
590823F000V018PER
59082930001018PER<<<<<<<<<0
GOMEZ<<ALICIA<<<<<<<<<<<<<<
01344111
''';

    final persona = DniTextParser.parse(text, '/tmp/casoreal.jpg');

    expect(persona.fechaNacimiento, '29/08/1959');
    expect(persona.nombres, 'ALICIA');
  });

  test(
    'lee MRZ exacto con doble menor y nombres separados por menor simple',
    () {
      const text = '''
I<PER75329710<2<<<<<<<<<<<<<<<<
0306104M2905121PER<<<<<<<<<<<<4
CANAZA<<JUAN<DIEGO<<<<<<<<<<<
Primer Apellido
RUIDO
Pre Nombres
OTRO RUIDO
''';

      final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

      expect(persona.apellidoPaterno, 'CANAZA');
      expect(persona.nombres, 'JUAN DIEGO');
      expect(persona.fechaNacimiento, '10/06/2003');
      expect(persona.sexo, 'M');
    },
  );

  test(
    'usa la linea inmediatamente encima del MRZ de nombres para nacimiento',
    () {
      const text = '''
590823F000V018PER
I<PER01344111<7<<<<<<<<<<<<
5908293F0001018PER<<<<<<<<<0
GOMEZ<<ALICIA<MARIA<<<<<<<<
''';

      final persona = DniTextParser.parse(text, '/tmp/casoreal.jpg');

      expect(persona.apellidoPaterno, 'GOMEZ');
      expect(persona.nombres, 'ALICIA MARIA');
      expect(persona.fechaNacimiento, '29/08/1959');
      expect(persona.sexo, 'F');
    },
  );

  test(
    'nombres MRZ nunca incluyen el primer apellido antes del doble menor',
    () {
      const text = '''
I<PER01344111<7<<<<<<<<<<<<
5908293F0001018PER<<<<<<<<<0
GOMEZ<<GOMEZ<ALICIA<<<<<<<<
''';

      final persona = DniTextParser.parse(text, '/tmp/casoreal.jpg');

      expect(persona.apellidoPaterno, 'GOMEZ');
      expect(persona.nombres, 'ALICIA');
    },
  );

  test('doble menor separa apellido y menor simple separa cada nombre', () {
    const text = '''
I<PER12345678<9<<<<<<<<<<<<
8805112M3001019PER<<<<<<<<<0
PEREZ<<JUAN<DIEGO<LUIS<<<<<<
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.apellidoPaterno, 'PEREZ');
    expect(persona.nombres, 'JUAN DIEGO LUIS');
    expect(persona.fechaNacimiento, '11/05/1988');
    expect(persona.sexo, 'M');
  });

  test('lee MRZ de CASO2REAL para apellido nombre fecha sexo y DNI', () {
    const text = '''
Primer Apellido
MARAZA
Segundo Apellido
GESTEJO
Pre Nombres
JUANA
I<PER01278148<1<<<<<<<<<<<<
5006258F0001018PER<<<<<<<<<4
MARAZA<<JUANA<<<<<<<<<<<<<<
''';

    final persona = DniTextParser.parse(text, '/tmp/caso2real.jpg');

    expect(persona.dni, '01278148');
    expect(persona.apellidoPaterno, 'MARAZA');
    expect(persona.apellidoMaterno, 'GESTEJO');
    expect(persona.nombres, 'JUANA');
    expect(persona.fechaNacimiento, '25/06/1950');
    expect(persona.sexo, 'F');
  });

  test('una linea MRZ sin doble menor no se usa para nombres', () {
    const text = '''
I<PER12345678<9<<<<<<<<<<<<
8805112M3001019PER<<<<<<<<<0
PEREZ<JUAN<DIEGO<LUIS<<<<<<
Primer Apellido
PEREZ
Pre Nombres
JUAN DIEGO
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.apellidoPaterno, 'PEREZ');
    expect(persona.nombres, 'JUAN DIEGO');
  });

  test('normaliza errores comunes sin depender de un solo DNI', () {
    const text = '''
PR1MER APELL1DO
GARC1A
SEGUND0 APELL1D0
HERNANDBZ
PRE N0MBRES
MAR1A EL1ZABETH
DNI 87654321
NACIMIENTO
05 11 1988
SEXO
F
''';

    final persona = DniTextParser.parse(text, '/tmp/dni.jpg');

    expect(persona.dni, '87654321');
    expect(persona.apellidoPaterno, 'GARCIA');
    expect(persona.apellidoMaterno, 'HERNANDEZ');
    expect(persona.nombres, 'MARIA ELIZABETH');
    expect(persona.fechaNacimiento, '05/11/1988');
    expect(persona.sexo, 'F');
  });

  test('elige nombres cercanos a etiqueta y descarta ruido del fondo', () {
    const text = '''
DOCUMENTO NACIONAL DE IDENTIDAD
Primer Apellido
ZKKATCTAR
GOMEZ
Segundo Apellido
RNOOP EC0
VDA DE RODRIGbEZ
Pre Nombres
INAUMIN H S
SALIGIA
01344111
5908293F0001018PER
GOMEZ<<ALICIA
''';

    final persona = DniTextParser.parse(text, '/tmp/casoreal.jpg');

    expect(persona.apellidoPaterno, 'GOMEZ');
    expect(persona.apellidoMaterno, 'VDA DE RODRIGUEZ');
    expect(persona.nombres, 'ALICIA');
    expect(persona.dni, '01344111');
    expect(persona.fechaNacimiento, '29/08/1959');
  });

  test('normaliza OCR real del celular para dni_sample', () {
    const text = '''
CUI
REPUBUCADELPERU REGISTRONA
DOCUMENTONACIONALDEIDENTIDADDNI
Primer Apellido
Fecha Inscripcion
CANAZA
18112010
FechaEmision
Segundo Apellido
12052021
PAUCARA
Fecha Caducidad
Pre Nombres
12062029
JUAN DIEGO
NacimientoFechayUbigeo
10062003
200901
Estado Civil
Sexo
M
S
I<PER75329710K2
030610M2905121PER
CANAZA<<JUAN<DIE
DNI75329710-9
0306104M2905121PER
CANAZA<<JUANKDIEGO
''';

    final persona = DniTextParser.parse(text, '/tmp/dni_sample_telefono.jpg');

    expect(persona.dni, '75329710');
    expect(persona.apellidoPaterno, 'CANAZA');
    expect(persona.apellidoMaterno, 'PAUCARA');
    expect(persona.nombres, 'JUAN DIEGO');
    expect(persona.fechaNacimiento, '10/06/2003');
    expect(persona.sexo, 'M');
  });

  test('normaliza OCR real del celular para casoreal', () {
    const text = '''
bcONENTO NACIONALOBynAntNIDI34417
Pimo Abeldo
GONEZ
Segundo Apélido
VDA DERODRIGUEZ
PruNobrod
SALIC
NaOhloito PuchiV Ubigeo
29208 19R59200407
Fslado
5908293F000 1018PERS
LTCIASS
o1344111
NOCAnvA
Apaldo
OUME22A
Soginclo Apellido.
VDA DE RODRIGbEZ
PruNonbrod
SALIGIA
Nabionto ch yUDigeo
O9 08;1959200407
KPERO1311
590823F000 V0 18PER
GOME ZKKATCtAR
01344111
59082930001018P
GOMEZ
ROORIGUE:
''';

    final persona = DniTextParser.parse(text, '/tmp/casoreal_telefono.jpg');

    expect(persona.dni, '01344111');
    expect(persona.apellidoPaterno, 'GOMEZ');
    expect(persona.apellidoMaterno, 'VDA DE RODRIGUEZ');
    expect(persona.nombres, 'ALICIA');
    expect(persona.fechaNacimiento, '29/08/1959');
    expect(persona.sexo, 'F');
  });

  test('normaliza OCR real del celular para CASO2REAL', () {
    const text = '''
01278
PURLACA
Primer Apelhdo
MANAZA
Segunto Apelio
Pe Nambres
Nacimierto Fecie y
ON TADOcn
IKPERO1278148<1
5006258F0001018PER
MARAZA<<JUANAK<KKKKKKK
rimer Apethoo
MARAZA
Segunto Apellido
Pe Nambras
Nacimertos Fecha y b
IKPERO1278148<1
5006258F0001018PERS
MARAZACCIUANA
Segundo Apelido
OENTEND
Pe Nambros
I<PER01278148#1
5006258F0001018R
MARAZA<IUANA
''';

    final persona = DniTextParser.parse(text, '/tmp/caso2real_telefono.jpg');

    expect(persona.dni, '01278148');
    expect(persona.apellidoPaterno, 'MARAZA');
    expect(persona.apellidoMaterno, 'GESTEJO');
    expect(persona.nombres, 'JUANA');
    expect(persona.fechaNacimiento, '25/06/1950');
    expect(persona.sexo, 'F');
  });
}
