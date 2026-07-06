class Sede {
  const Sede({
    this.id,
    required this.nombre,
    this.codigo = '',
    this.descripcion = '',
    this.fechaCreacion = '',
    this.fechaActualizacion = '',
  });

  final int? id;
  final String nombre;
  final String codigo;
  final String descripcion;
  final String fechaCreacion;
  final String fechaActualizacion;

  String get displayName {
    final cleanName = nombre.trim();
    final cleanCode = codigo.trim();
    if (cleanCode.isEmpty) return cleanName;
    return '$cleanCode - $cleanName';
  }

  Sede copyWith({
    int? id,
    String? nombre,
    String? codigo,
    String? descripcion,
    String? fechaCreacion,
    String? fechaActualizacion,
  }) {
    return Sede(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'descripcion': descripcion,
      'fecha_creacion': fechaCreacion,
      'fecha_actualizacion': fechaActualizacion,
    };
  }

  factory Sede.fromMap(Map<String, Object?> map) {
    return Sede(
      id: map['id'] as int?,
      nombre: map['nombre'] as String? ?? '',
      codigo: map['codigo'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      fechaCreacion: map['fecha_creacion'] as String? ?? '',
      fechaActualizacion: map['fecha_actualizacion'] as String? ?? '',
    );
  }
}
