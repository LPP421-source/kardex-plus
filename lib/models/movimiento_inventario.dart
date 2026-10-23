// lib/models/movimiento_inventario.dart
//
// Cada movimiento es una línea del kardex de UN producto: puede ser
// un saldo inicial, una compra, una venta, o una devolución (de
// venta o de compra).

/// Los 5 tipos de movimiento que maneja una empresa comercial.
enum TipoMovimiento {
  saldoInicial, // Inventario con el que arranca el producto
  compra,
  venta,
  devolucionVenta, // El cliente nos devuelve producto
  devolucionCompra, // Nosotros devolvemos producto al proveedor
}

extension TipoMovimientoNombre on TipoMovimiento {
  String get nombreCompleto {
    switch (this) {
      case TipoMovimiento.saldoInicial:
        return 'Saldo Inicial';
      case TipoMovimiento.compra:
        return 'Compra';
      case TipoMovimiento.venta:
        return 'Venta';
      case TipoMovimiento.devolucionVenta:
        return 'Devolución en Venta';
      case TipoMovimiento.devolucionCompra:
        return 'Devolución en Compra';
    }
  }

  /// true si este tipo de movimiento AUMENTA el inventario
  /// (entra mercadería), false si lo DISMINUYE (sale mercadería).
  bool get esEntrada {
    switch (this) {
      case TipoMovimiento.saldoInicial:
      case TipoMovimiento.compra:
      case TipoMovimiento.devolucionVenta:
        return true;
      case TipoMovimiento.venta:
      case TipoMovimiento.devolucionCompra:
        return false;
    }
  }
}

class MovimientoInventario {
  final String? id;

  /// A qué producto pertenece (antes era ejercicioId: ahora el
  /// kardex se calcula por producto, no por ejercicio completo).
  final String productoId;

  final DateTime fecha;
  final TipoMovimiento tipo;
  final int cantidad;

  /// Costo unitario "manual". Se usa siempre en Compra y Saldo
  /// Inicial. En las devoluciones, solo se usa si el usuario eligió
  /// el modo MANUAL (si eligió el modo automático, este campo queda
  /// en null y el costo se calcula solo, mirando la referencia).
  final double? costoUnitario;

  /// Solo aplica a devoluciones en modo AUTOMÁTICO: apunta al id
  /// del movimiento original (la venta o la compra) que se está
  /// devolviendo. Con esa referencia, el sistema sabe de qué lote
  /// exacto sacar el costo, sin que el usuario tenga que escribirlo.
  final String? movimientoReferenciaId;

  MovimientoInventario({
    this.id,
    required this.productoId,
    required this.fecha,
    required this.tipo,
    required this.cantidad,
    this.costoUnitario,
    this.movimientoReferenciaId,
  });

  Map<String, dynamic> toMap() {
    return {
      'producto_id': productoId,
      'fecha': fecha.toIso8601String(),
      'tipo': tipo.name,
      'cantidad': cantidad,
      'costo_unitario': costoUnitario,
      'movimiento_referencia_id': movimientoReferenciaId,
    };
  }

  factory MovimientoInventario.fromMap(Map<String, dynamic> map) {
    return MovimientoInventario(
      id: map['id'] as String?,
      productoId: map['producto_id'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      tipo: TipoMovimiento.values.byName(map['tipo'] as String),
      cantidad: map['cantidad'] as int,
      costoUnitario: (map['costo_unitario'] as num?)?.toDouble(),
      movimientoReferenciaId: map['movimiento_referencia_id'] as String?,
    );
  }
}