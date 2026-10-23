// lib/models/producto.dart
//
// Representa UN producto dentro de un ejercicio. Cada producto
// tiene su propia tarjeta kardex independiente (su propio historial
// de movimientos, sus propios saldos, y su PROPIO método de
// valuación — igual que en una tarjeta kardex real, donde cada
// producto puede valuarse con un método distinto).

import 'ejercicio.dart' show MetodoValuacion;

class Producto {
  final String? id;
  final String ejercicioId;

  /// Nombre del producto, ej: "Chompas talla L"
  final String nombre;

  /// Número de tarjeta kardex, ej: "01" (como en las tarjetas
  /// físicas tradicionales). Se sugiere automáticamente pero el
  /// usuario puede cambiarlo.
  final String? numeroTarjeta;

  /// Código interno, ej: "CH-01"
  final String? codigo;

  /// Unidad de medida en la que se cuenta este producto (unidades,
  /// kg, litros, cajas, etc.). Es obligatoria porque toda tarjeta
  /// kardex real la necesita para que las cantidades tengan sentido.
  final String unidadMedida;

  /// Método de valuación de ESTE producto en particular. Vive aquí
  /// (y no en el Ejercicio) porque en la práctica real cada tarjeta
  /// kardex puede usar un método distinto.
  final MetodoValuacion metodo;

  /// A qué categoría pertenece este producto (ej: "Insumos",
  /// "Material de limpieza"). Es opcional — un producto puede no
  /// tener categoría asignada.
  final String? categoriaId;

  final String? descripcion;
  final DateTime fechaCreacion;

  Producto({
    this.id,
    required this.ejercicioId,
    required this.nombre,
    this.numeroTarjeta,
    this.codigo,
    required this.unidadMedida,
    required this.metodo,
    this.categoriaId,
    this.descripcion,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'ejercicio_id': ejercicioId,
      'nombre': nombre,
      'numero_tarjeta': numeroTarjeta,
      'codigo': codigo,
      'unidad_medida': unidadMedida,
      'metodo': metodo.name,
      'categoria_id': categoriaId,
      'descripcion': descripcion,
      'fecha_creacion': fechaCreacion.toIso8601String(),
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as String?,
      ejercicioId: map['ejercicio_id'] as String,
      nombre: map['nombre'] as String,
      numeroTarjeta: map['numero_tarjeta'] as String?,
      codigo: map['codigo'] as String?,
      unidadMedida: map['unidad_medida'] as String? ?? 'unidades',
      metodo: MetodoValuacion.values.byName(map['metodo'] as String),
      categoriaId: map['categoria_id'] as String?,
      descripcion: map['descripcion'] as String?,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
    );
  }

  /// Crea una copia de este producto con algunos campos cambiados.
  /// La usamos para el cambio de método: en vez de reconstruir el
  /// objeto entero a mano, solo indicamos qué cambia.
  Producto copyWith({MetodoValuacion? metodo}) {
    return Producto(
      id: id,
      ejercicioId: ejercicioId,
      nombre: nombre,
      numeroTarjeta: numeroTarjeta,
      codigo: codigo,
      unidadMedida: unidadMedida,
      metodo: metodo ?? this.metodo,
      categoriaId: categoriaId,
      descripcion: descripcion,
      fechaCreacion: fechaCreacion,
    );
  }
}