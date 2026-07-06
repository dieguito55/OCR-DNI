class Persona {
  const Persona({
    this.id,
    this.sedeId,
    this.numero,
    this.apellidoPaterno = '',
    this.apellidoMaterno = '',
    this.nombres = '',
    this.dni = '',
    this.sexo = '',
    this.fechaNacimiento = '',
    this.imagenDniPath = '',
    this.textoOcr = '',
    this.estadoRevision = 'pendiente',
    this.fechaCreacion = '',
    this.fechaActualizacion = '',
  });

  final int? id;
  final int? sedeId;
  final int? numero;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String nombres;
  final String dni;
  final String sexo;
  final String fechaNacimiento;
  final String imagenDniPath;
  final String textoOcr;
  final String estadoRevision;
  final String fechaCreacion;
  final String fechaActualizacion;

  String get nombreCompleto {
    final parts = [
      nombres,
      apellidoPaterno,
      apellidoMaterno,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    return parts.isEmpty ? 'Sin nombre' : parts;
  }

  bool get estaCompleto {
    return dni.trim().length == 8 &&
        nombres.trim().isNotEmpty &&
        apellidoPaterno.trim().isNotEmpty &&
        apellidoMaterno.trim().isNotEmpty &&
        sexo.trim().isNotEmpty &&
        fechaNacimiento.trim().isNotEmpty;
  }

  Persona copyWith({
    int? id,
    int? sedeId,
    int? numero,
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? nombres,
    String? dni,
    String? sexo,
    String? fechaNacimiento,
    String? imagenDniPath,
    String? textoOcr,
    String? estadoRevision,
    String? fechaCreacion,
    String? fechaActualizacion,
  }) {
    return Persona(
      id: id ?? this.id,
      sedeId: sedeId ?? this.sedeId,
      numero: numero ?? this.numero,
      apellidoPaterno: apellidoPaterno ?? this.apellidoPaterno,
      apellidoMaterno: apellidoMaterno ?? this.apellidoMaterno,
      nombres: nombres ?? this.nombres,
      dni: dni ?? this.dni,
      sexo: sexo ?? this.sexo,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      imagenDniPath: imagenDniPath ?? this.imagenDniPath,
      textoOcr: textoOcr ?? this.textoOcr,
      estadoRevision: estadoRevision ?? this.estadoRevision,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'sede_id': sedeId,
      'numero': numero,
      'apellido_paterno': apellidoPaterno,
      'apellido_materno': apellidoMaterno,
      'nombres': nombres,
      'dni': dni,
      'sexo': sexo,
      'fecha_nacimiento': fechaNacimiento,
      'imagen_dni_path': imagenDniPath,
      'texto_ocr': textoOcr,
      'estado_revision': estadoRevision,
      'fecha_creacion': fechaCreacion,
      'fecha_actualizacion': fechaActualizacion,
    };
  }

  factory Persona.fromMap(Map<String, Object?> map) {
    return Persona(
      id: map['id'] as int?,
      sedeId: map['sede_id'] as int?,
      numero: map['numero'] as int?,
      apellidoPaterno: map['apellido_paterno'] as String? ?? '',
      apellidoMaterno: map['apellido_materno'] as String? ?? '',
      nombres: map['nombres'] as String? ?? '',
      dni: map['dni'] as String? ?? '',
      sexo: map['sexo'] as String? ?? '',
      fechaNacimiento: map['fecha_nacimiento'] as String? ?? '',
      imagenDniPath: map['imagen_dni_path'] as String? ?? '',
      textoOcr: map['texto_ocr'] as String? ?? '',
      estadoRevision: map['estado_revision'] as String? ?? 'pendiente',
      fechaActualizacion: map['fecha_actualizacion'] as String? ?? '',
    );
  }
}
