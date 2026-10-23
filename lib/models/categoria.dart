// lib/models/categoria.dart
//
// Representa una agrupación de productos dentro de un ejercicio,
// definida libremente por el usuario (ej: "Insumos", "Material de
// limpieza", "Combustibles"). Un producto puede pertenecer a una
// categoría o a ninguna.

class Categoria {
  final String? id;
  final String ejercicioId;
  final String nombre;
  final DateTime fechaCreacion;

  Categoria({
    this.id,
    required this.ejercicioId,
    required this.nombre,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'ejercicio_id': ejercicioId,
      'nombre': nombre,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as String?,
      ejercicioId: map['ejercicio_id'] as String,
      nombre: map['nombre'] as String,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
    );
  }
}