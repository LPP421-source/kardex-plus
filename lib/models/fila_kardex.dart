// lib/models/fila_kardex.dart
//
// Representa UNA fila ya calculada de la tabla kardex. A diferencia
// de MovimientoInventario (que es el dato "crudo" que el usuario
// ingresa), esta clase ya trae los cálculos hechos: costos, totales
// y el saldo acumulado después de ese movimiento.

import 'movimiento_inventario.dart';

class FilaKardex {
  final DateTime fecha;
  final TipoMovimiento tipo;

  /// A qué movimiento original pertenece esta fila. Importante:
  /// cuando una venta se divide en varias filas (una por lote),
  /// TODAS esas filas comparten el mismo movimientoId, porque en
  /// la base de datos siguen siendo UN solo movimiento guardado.
  final String? movimientoId;

  // --- Columna de ENTRADAS (solo tiene valor si tipo == compra) ---
  final int? cantidadEntrada;
  final double? costoUnitarioEntrada;
  final double? costoTotalEntrada;

  // --- Columna de SALIDAS (solo tiene valor si tipo == venta) ---
  final int? cantidadSalida;
  // Costo unitario promedio de las unidades que salieron. Para PEPS
  // y UEPS puede ser una mezcla de varias "capas" de compra distintas.
  final double? costoUnitarioSalida;
  final double? costoTotalSalida;

  // --- Columna de SALDO (siempre tiene valor, es el estado del
  // inventario DESPUÉS de este movimiento) ---
  final int saldoCantidad;
  final double saldoValorizado;

  const FilaKardex({
    required this.fecha,
    required this.tipo,
    this.movimientoId,
    this.cantidadEntrada,
    this.costoUnitarioEntrada,
    this.costoTotalEntrada,
    this.cantidadSalida,
    this.costoUnitarioSalida,
    this.costoTotalSalida,
    required this.saldoCantidad,
    required this.saldoValorizado,
  });

  /// Costo unitario promedio del saldo actual (saldo valorizado
  /// dividido entre la cantidad). Útil para mostrarlo en la tabla.
  double get saldoCostoUnitarioPromedio {
    if (saldoCantidad == 0) return 0;
    return saldoValorizado / saldoCantidad;
  }
}