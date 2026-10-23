// lib/services/kardex_calculator.dart
//
// El "motor" de cálculo del kardex. Recibe TODOS los movimientos de
// UN producto (saldo inicial, compras, ventas, devoluciones) y el
// método de valuación, y devuelve la tabla kardex completa.
//
// Reglas clave de este motor (confirmadas con el usuario):
// - PEPS y UEPS: si una venta consume más de un lote, se genera
//   UNA FILA POR CADA LOTE consumido, cada una con su costo exacto.
// - CPP: nunca se divide, siempre una sola fila al costo promedio.
// - Devolución en venta: el costo de reingreso puede ser MANUAL
//   (el usuario lo escribe) o AUTOMÁTICO (se toma el costo del
//   último lote que se tocó en la venta que se está devolviendo).
// - Devolución en compra: el costo de salida puede ser MANUAL o
//   AUTOMÁTICO (se toma el costo original de la compra referenciada,
//   y se descuenta exactamente de ese lote, sin importar PEPS/UEPS).

import '../models/ejercicio.dart';
import '../models/fila_kardex.dart';
import '../models/movimiento_inventario.dart';

/// Se lanza cuando se intenta sacar (vender o devolver a proveedor)
/// más unidades de las que hay disponibles.
class StockInsuficienteException implements Exception {
  final String mensaje;
  StockInsuficienteException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Se lanza cuando una devolución no trae suficiente información
/// para calcular su costo (ni costo manual, ni una referencia
/// válida a un movimiento anterior), o cuando la referencia no
/// coincide con ningún lote disponible.
class ReferenciaInvalidaException implements Exception {
  final String mensaje;
  ReferenciaInvalidaException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Una "capa" es un lote de unidades que entraron juntas, al mismo
/// costo. [origenMovimientoId] recuerda de qué movimiento original
/// vino esta capa (una compra, un saldo inicial, o una devolución
/// en venta) — lo necesitamos para las devoluciones en compra en
/// modo automático, que deben descontar de un lote EXACTO.
class _CapaInventario {
  int cantidad;
  final double costoUnitario;
  final String? origenMovimientoId;
  _CapaInventario({
    required this.cantidad,
    required this.costoUnitario,
    this.origenMovimientoId,
  });
}

/// Un "trozo" consumido de una capa al procesar una salida
/// (venta o devolución en compra), usado para armar las filas
/// separadas por lote.
class _ConsumoLote {
  final int cantidad;
  final double costoUnitario;
  _ConsumoLote(this.cantidad, this.costoUnitario);
}

class KardexCalculator {
  /// Calcula el kardex completo. Si algún movimiento tiene un
  /// problema (stock insuficiente, referencia inválida), LANZA la
  /// excepción correspondiente — úsalo cuando quieras validar ANTES
  /// de guardar un movimiento nuevo (ver [calcularSeguro] para la
  /// versión pensada para mostrar en pantalla).
  List<FilaKardex> calcular(
    List<MovimientoInventario> movimientos,
    MetodoValuacion metodo,
  ) {
    final resultado = _procesar(movimientos, metodo, detenerEnError: false);
    if (resultado.error != null) throw resultado.error!;
    return resultado.filas;
  }

  /// Calcula el kardex igual que [calcular], pero si encuentra un
  /// movimiento con problemas, EN VEZ DE LANZAR UNA EXCEPCIÓN Y
  /// PERDER TODO, devuelve las filas válidas calculadas hasta ese
  /// punto junto con un mensaje de error. Pensado para mostrar en
  /// pantalla sin ocultar el historial previo que sí es correcto.
  ({List<FilaKardex> filas, String? mensajeError}) calcularSeguro(
    List<MovimientoInventario> movimientos,
    MetodoValuacion metodo,
  ) {
    final resultado = _procesar(movimientos, metodo, detenerEnError: true);
    return (filas: resultado.filas, mensajeError: resultado.error?.toString());
  }

  ({List<FilaKardex> filas, Exception? error}) _procesar(
    List<MovimientoInventario> movimientos,
    MetodoValuacion metodo, {
    required bool detenerEnError,
  }) {
    // Ordenamos por fecha. Si dos movimientos caen el mismo día,
    // respetamos el orden en que fueron ingresados originalmente
    // (por ejemplo, para que una devolución quede después de la
    // venta que la originó, si ambas son del mismo día).
    final indexados = List.generate(
      movimientos.length,
      (i) => MapEntry(i, movimientos[i]),
    );
    indexados.sort((a, b) {
      final cmp = a.value.fecha.compareTo(b.value.fecha);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });
    final ordenados = indexados.map((e) => e.value).toList();

    final filas = <FilaKardex>[];
    final capas = <_CapaInventario>[];

    int saldoCantidad = 0;
    double saldoValorizado = 0;

    // "Memoria" auxiliar para resolver las devoluciones automáticas:
    // recuerda el costo original de cada compra/saldo inicial (para
    // devolución en compra), y el costo del último lote tocado en
    // cada venta (para devolución en venta).
    final costoOrigenPorMovimiento = <String, double>{};
    final ultimoCostoVenta = <String, double>{};

    try {
      for (final mov in ordenados) {
        switch (mov.tipo) {
          case TipoMovimiento.saldoInicial:
          case TipoMovimiento.compra:
            filas.add(
              _procesarEntradaSimple(
                mov: mov,
                capas: capas,
                costoOrigenPorMovimiento: costoOrigenPorMovimiento,
                actualizarSaldo: (cant, val) {
                  saldoCantidad += cant;
                  saldoValorizado += val;
                },
                saldoCantidadActual: () => saldoCantidad,
                saldoValorizadoActual: () => saldoValorizado,
              ),
            );
            break;

          case TipoMovimiento.venta:
            if (mov.cantidad > saldoCantidad) {
              throw StockInsuficienteException(
                'No hay suficiente inventario para vender ${mov.cantidad} '
                'unidades el ${_soloFecha(mov.fecha)}. '
                'Saldo disponible: $saldoCantidad.',
              );
            }

            if (metodo == MetodoValuacion.cpp) {
              final promedio = saldoCantidad == 0
                  ? 0.0
                  : saldoValorizado / saldoCantidad;
              final costoTotal = mov.cantidad * promedio;

              _consumirCapasSimple(capas, mov.cantidad);

              saldoCantidad -= mov.cantidad;
              saldoValorizado -= costoTotal;

              if (mov.id != null) ultimoCostoVenta[mov.id!] = promedio;

              filas.add(
                FilaKardex(
                  fecha: mov.fecha,
                  tipo: mov.tipo,
                  movimientoId: mov.id,
                  cantidadSalida: mov.cantidad,
                  costoUnitarioSalida: promedio,
                  costoTotalSalida: costoTotal,
                  saldoCantidad: saldoCantidad,
                  saldoValorizado: saldoValorizado,
                ),
              );
            } else {
              final esPeps = metodo == MetodoValuacion.peps;
              final consumos = _consumirCapasDetallado(
                capas,
                mov.cantidad,
                deLasMasAntiguas: esPeps,
              );

              for (final consumo in consumos) {
                final costoTotalFila =
                    consumo.cantidad * consumo.costoUnitario;
                saldoCantidad -= consumo.cantidad;
                saldoValorizado -= costoTotalFila;

                filas.add(
                  FilaKardex(
                    fecha: mov.fecha,
                    tipo: mov.tipo,
                    movimientoId: mov.id,
                    cantidadSalida: consumo.cantidad,
                    costoUnitarioSalida: consumo.costoUnitario,
                    costoTotalSalida: costoTotalFila,
                    saldoCantidad: saldoCantidad,
                    saldoValorizado: saldoValorizado,
                  ),
                );
              }

              if (mov.id != null && consumos.isNotEmpty) {
                ultimoCostoVenta[mov.id!] = consumos.last.costoUnitario;
              }
            }
            break;

          case TipoMovimiento.devolucionVenta:
            final costoReingreso = _resolverCostoDevolucionVenta(
              mov,
              ultimoCostoVenta,
            );
            final costoTotal = mov.cantidad * costoReingreso;

            capas.add(
              _CapaInventario(
                cantidad: mov.cantidad,
                costoUnitario: costoReingreso,
                origenMovimientoId: mov.id,
              ),
            );
            saldoCantidad += mov.cantidad;
            saldoValorizado += costoTotal;

            filas.add(
              FilaKardex(
                fecha: mov.fecha,
                tipo: mov.tipo,
                movimientoId: mov.id,
                cantidadEntrada: mov.cantidad,
                costoUnitarioEntrada: costoReingreso,
                costoTotalEntrada: costoTotal,
                saldoCantidad: saldoCantidad,
                saldoValorizado: saldoValorizado,
              ),
            );
            break;

          case TipoMovimiento.devolucionCompra:
            final costoDevolucion = _resolverCostoDevolucionCompra(
              mov,
              costoOrigenPorMovimiento,
            );

            if (mov.cantidad > saldoCantidad) {
              throw StockInsuficienteException(
                'No hay suficiente inventario para devolver ${mov.cantidad} '
                'unidades el ${_soloFecha(mov.fecha)}. '
                'Saldo disponible: $saldoCantidad.',
              );
            }

            _consumirCapasSimple(capas, mov.cantidad);

            final costoTotal = mov.cantidad * costoDevolucion;
            saldoCantidad -= mov.cantidad;
            saldoValorizado -= costoTotal;

            filas.add(
              FilaKardex(
                fecha: mov.fecha,
                tipo: mov.tipo,
                movimientoId: mov.id,
                cantidadSalida: mov.cantidad,
                costoUnitarioSalida: costoDevolucion,
                costoTotalSalida: costoTotal,
                saldoCantidad: saldoCantidad,
                saldoValorizado: saldoValorizado,
              ),
            );
            break;
        }
      }
    } on StockInsuficienteException catch (e) {
      if (detenerEnError) return (filas: filas, error: e);
      rethrow;
    } on ReferenciaInvalidaException catch (e) {
      if (detenerEnError) return (filas: filas, error: e);
      rethrow;
    }

    return (filas: filas, error: null);
  }

  // ---------------------------------------------------------------
  // Entradas simples (Saldo Inicial y Compra se procesan igual)
  // ---------------------------------------------------------------
  FilaKardex _procesarEntradaSimple({
    required MovimientoInventario mov,
    required List<_CapaInventario> capas,
    required Map<String, double> costoOrigenPorMovimiento,
    required void Function(int cantidad, double valor) actualizarSaldo,
    required int Function() saldoCantidadActual,
    required double Function() saldoValorizadoActual,
  }) {
    final costoUnitario = mov.costoUnitario ?? 0;
    final costoTotal = mov.cantidad * costoUnitario;

    capas.add(
      _CapaInventario(
        cantidad: mov.cantidad,
        costoUnitario: costoUnitario,
        origenMovimientoId: mov.id,
      ),
    );
    actualizarSaldo(mov.cantidad, costoTotal);

    if (mov.id != null) {
      costoOrigenPorMovimiento[mov.id!] = costoUnitario;
    }

    return FilaKardex(
      fecha: mov.fecha,
      tipo: mov.tipo,
      movimientoId: mov.id,
      cantidadEntrada: mov.cantidad,
      costoUnitarioEntrada: costoUnitario,
      costoTotalEntrada: costoTotal,
      saldoCantidad: saldoCantidadActual(),
      saldoValorizado: saldoValorizadoActual(),
    );
  }

  // ---------------------------------------------------------------
  // Resolver el costo de una devolución en venta (manual o automático)
  // ---------------------------------------------------------------
  double _resolverCostoDevolucionVenta(
    MovimientoInventario mov,
    Map<String, double> ultimoCostoVenta,
  ) {
    if (mov.costoUnitario != null) {
      return mov.costoUnitario!; // Modo manual.
    }
    final refId = mov.movimientoReferenciaId;
    if (refId != null && ultimoCostoVenta.containsKey(refId)) {
      return ultimoCostoVenta[refId]!; // Modo automático.
    }
    throw ReferenciaInvalidaException(
      'La devolución en venta del ${_soloFecha(mov.fecha)} no tiene costo '
      'manual ni una referencia válida a la venta original.',
    );
  }

  // ---------------------------------------------------------------
  // Resolver el costo de una devolución en compra (manual o automático)
  // ---------------------------------------------------------------
  double _resolverCostoDevolucionCompra(
    MovimientoInventario mov,
    Map<String, double> costoOrigenPorMovimiento,
  ) {
    if (mov.costoUnitario != null) {
      return mov.costoUnitario!; // Modo manual.
    }
    final refId = mov.movimientoReferenciaId;
    if (refId != null && costoOrigenPorMovimiento.containsKey(refId)) {
      return costoOrigenPorMovimiento[refId]!; // Modo automático.
    }
    throw ReferenciaInvalidaException(
      'La devolución en compra del ${_soloFecha(mov.fecha)} no tiene costo '
      'manual ni una referencia válida a la compra original.',
    );
  }

  // ---------------------------------------------------------------
  // Consumir capas SIN separar el detalle (usado en ventas con CPP,
  // donde el costo no depende del lote, solo nos interesa mantener
  // las cantidades de las capas al día).
  // ---------------------------------------------------------------
  void _consumirCapasSimple(List<_CapaInventario> capas, int cantidad) {
    int restante = cantidad;
    while (restante > 0) {
      final capa = capas.first;
      if (capa.cantidad <= restante) {
        restante -= capa.cantidad;
        capas.removeAt(0);
      } else {
        capa.cantidad -= restante;
        restante = 0;
      }
    }
  }

  // ---------------------------------------------------------------
  // Consumir capas separando el detalle lote por lote (usado en
  // ventas con PEPS/UEPS).
  // ---------------------------------------------------------------
  List<_ConsumoLote> _consumirCapasDetallado(
    List<_CapaInventario> capas,
    int cantidadAConsumir, {
    required bool deLasMasAntiguas,
  }) {
    final consumos = <_ConsumoLote>[];
    int restante = cantidadAConsumir;

    while (restante > 0) {
      final indice = deLasMasAntiguas ? 0 : capas.length - 1;
      final capa = capas[indice];

      if (capa.cantidad <= restante) {
        consumos.add(_ConsumoLote(capa.cantidad, capa.costoUnitario));
        restante -= capa.cantidad;
        capas.removeAt(indice);
      } else {
        consumos.add(_ConsumoLote(restante, capa.costoUnitario));
        capa.cantidad -= restante;
        restante = 0;
      }
    }

    return consumos;
  }

  String _soloFecha(DateTime fecha) => fecha.toIso8601String().substring(0, 10);
}