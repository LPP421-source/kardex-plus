// test/kardex_calculator_test.dart
//
// Prueba automatizada del motor de cálculo con un caso que cubre
// los 5 tipos de movimiento: saldo inicial, compra, venta (que
// consume 2 lotes distintos), devolución en venta (automática) y
// devolución en compra (automática).
//
// Caso de prueba:
//   01-may: Saldo inicial   100 unidades @ 100
//   04-may: Compra          100 unidades @ 120
//   10-may: Venta           120 unidades (consume 100 del saldo
//                           inicial + 20 de la compra)
//   15-may: Devolución venta 10 unidades (del último lote tocado
//                           en la venta anterior)
//   20-may: Devolución compra 10 unidades (de la compra del 04-may)
//
// Para correr: flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_app/models/ejercicio.dart';
import 'package:inventario_app/models/movimiento_inventario.dart';
import 'package:inventario_app/services/kardex_calculator.dart';

void main() {
  // Construimos la misma secuencia de movimientos para probarla
  // con los 3 métodos. Le damos "id" manualmente (en la app real
  // vendría de Supabase) para poder armar las referencias de las
  // devoluciones automáticas.
  List<MovimientoInventario> construirMovimientos() => [
    MovimientoInventario(
      id: 'saldo_inicial',
      productoId: 'test',
      fecha: DateTime(2024, 5, 1),
      tipo: TipoMovimiento.saldoInicial,
      cantidad: 100,
      costoUnitario: 100,
    ),
    MovimientoInventario(
      id: 'compra_1',
      productoId: 'test',
      fecha: DateTime(2024, 5, 4),
      tipo: TipoMovimiento.compra,
      cantidad: 100,
      costoUnitario: 120,
    ),
    MovimientoInventario(
      id: 'venta_1',
      productoId: 'test',
      fecha: DateTime(2024, 5, 10),
      tipo: TipoMovimiento.venta,
      cantidad: 120,
    ),
    MovimientoInventario(
      id: 'dev_venta_1',
      productoId: 'test',
      fecha: DateTime(2024, 5, 15),
      tipo: TipoMovimiento.devolucionVenta,
      cantidad: 10,
      movimientoReferenciaId: 'venta_1', // modo automático
    ),
    MovimientoInventario(
      id: 'dev_compra_1',
      productoId: 'test',
      fecha: DateTime(2024, 5, 20),
      tipo: TipoMovimiento.devolucionCompra,
      cantidad: 10,
      movimientoReferenciaId: 'compra_1', // modo automático
    ),
  ];

  final calculator = KardexCalculator();

  test('PEPS: divide la venta en 2 filas y calcula las devoluciones bien', () {
    final filas = calculator.calcular(
      construirMovimientos(),
      MetodoValuacion.peps,
    );

    // Las filas de la venta_1 deben ser 2 (una por cada lote
    // consumido): 100 unidades del saldo inicial ($100) y 20 de
    // la compra ($120).
    final filasVenta = filas
        .where((f) => f.movimientoId == 'venta_1')
        .toList();
    expect(filasVenta.length, 2);
    expect(filasVenta[0].cantidadSalida, 100);
    expect(filasVenta[0].costoUnitarioSalida, closeTo(100, 0.01));
    expect(filasVenta[1].cantidadSalida, 20);
    expect(filasVenta[1].costoUnitarioSalida, closeTo(120, 0.01));

    // Después de la venta: saldo 80 unidades, $9,600.
    expect(filasVenta.last.saldoCantidad, 80);
    expect(filasVenta.last.saldoValorizado, closeTo(9600, 0.01));

    // Devolución en venta: reingresa al costo del ÚLTIMO lote
    // tocado en la venta (el de $120). Saldo: 90 unidades, $10,800.
    final filaDevVenta = filas.firstWhere(
      (f) => f.movimientoId == 'dev_venta_1',
    );
    expect(filaDevVenta.costoUnitarioEntrada, closeTo(120, 0.01));
    expect(filaDevVenta.saldoCantidad, 90);
    expect(filaDevVenta.saldoValorizado, closeTo(10800, 0.01));

    // Devolución en compra: se valora al costo ORIGINAL de esa
    // compra ($120). Saldo: 80 unidades, $9,600.
    final filaDevCompra = filas.firstWhere(
      (f) => f.movimientoId == 'dev_compra_1',
    );
    expect(filaDevCompra.costoUnitarioSalida, closeTo(120, 0.01));
    expect(filaDevCompra.saldoCantidad, 80);
    expect(filaDevCompra.saldoValorizado, closeTo(9600, 0.01));
  });

  test('UEPS: divide la venta en 2 filas y calcula las devoluciones bien', () {
    final filas = calculator.calcular(
      construirMovimientos(),
      MetodoValuacion.ueps,
    );

    // UEPS consume primero lo más nuevo: 100 de la compra ($120)
    // y luego 20 del saldo inicial ($100).
    final filasVenta = filas
        .where((f) => f.movimientoId == 'venta_1')
        .toList();
    expect(filasVenta.length, 2);
    expect(filasVenta[0].cantidadSalida, 100);
    expect(filasVenta[0].costoUnitarioSalida, closeTo(120, 0.01));
    expect(filasVenta[1].cantidadSalida, 20);
    expect(filasVenta[1].costoUnitarioSalida, closeTo(100, 0.01));
    expect(filasVenta.last.saldoCantidad, 80);
    expect(filasVenta.last.saldoValorizado, closeTo(8000, 0.01));

    // Devolución en venta: el último lote tocado fue el de $100.
    final filaDevVenta = filas.firstWhere(
      (f) => f.movimientoId == 'dev_venta_1',
    );
    expect(filaDevVenta.costoUnitarioEntrada, closeTo(100, 0.01));
    expect(filaDevVenta.saldoCantidad, 90);
    expect(filaDevVenta.saldoValorizado, closeTo(9000, 0.01));

    // Devolución en compra: SIGUE valorándose al costo original de
    // factura ($120), aunque ese lote físico ya se había agotado.
    final filaDevCompra = filas.firstWhere(
      (f) => f.movimientoId == 'dev_compra_1',
    );
    expect(filaDevCompra.costoUnitarioSalida, closeTo(120, 0.01));
    expect(filaDevCompra.saldoCantidad, 80);
    expect(filaDevCompra.saldoValorizado, closeTo(7800, 0.01));
  });

  test('CPP: nunca divide filas y recalcula el promedio correctamente', () {
    final filas = calculator.calcular(
      construirMovimientos(),
      MetodoValuacion.cpp,
    );

    // En CPP, la venta_1 es UNA SOLA fila (nunca se divide).
    final filasVenta = filas
        .where((f) => f.movimientoId == 'venta_1')
        .toList();
    expect(filasVenta.length, 1);
    // Promedio antes de vender: 200 unidades por $22,000 = $110.
    expect(filasVenta.first.costoUnitarioSalida, closeTo(110, 0.01));
    expect(filasVenta.first.saldoCantidad, 80);
    expect(filasVenta.first.saldoValorizado, closeTo(8800, 0.01));

    // Devolución en venta: reingresa al promedio que tenía la
    // venta que se devuelve ($110).
    final filaDevVenta = filas.firstWhere(
      (f) => f.movimientoId == 'dev_venta_1',
    );
    expect(filaDevVenta.costoUnitarioEntrada, closeTo(110, 0.01));
    expect(filaDevVenta.saldoCantidad, 90);
    expect(filaDevVenta.saldoValorizado, closeTo(9900, 0.01));

    // Devolución en compra: se resta al costo ORIGINAL de factura
    // ($120, no el promedio actual), lo que recalcula el promedio
    // a $108.75.
    final filaDevCompra = filas.firstWhere(
      (f) => f.movimientoId == 'dev_compra_1',
    );
    expect(filaDevCompra.costoUnitarioSalida, closeTo(120, 0.01));
    expect(filaDevCompra.saldoCantidad, 80);
    expect(filaDevCompra.saldoValorizado, closeTo(8700, 0.01));
    expect(
      filaDevCompra.saldoCostoUnitarioPromedio,
      closeTo(108.75, 0.01),
    );
  });

  test('Lanza error si se intenta vender más de lo disponible', () {
    final movimientosConError = [
      MovimientoInventario(
        productoId: 'test',
        fecha: DateTime(2024, 1, 1),
        tipo: TipoMovimiento.compra,
        cantidad: 10,
        costoUnitario: 5,
      ),
      MovimientoInventario(
        productoId: 'test',
        fecha: DateTime(2024, 1, 2),
        tipo: TipoMovimiento.venta,
        cantidad: 999,
      ),
    ];

    expect(
      () => calculator.calcular(movimientosConError, MetodoValuacion.peps),
      throwsA(isA<StockInsuficienteException>()),
    );
  });

  test(
    'Lanza error si una devolución no tiene costo manual ni referencia',
    () {
      final movimientosConError = [
        MovimientoInventario(
          productoId: 'test',
          fecha: DateTime(2024, 1, 1),
          tipo: TipoMovimiento.compra,
          cantidad: 10,
          costoUnitario: 5,
        ),
        MovimientoInventario(
          productoId: 'test',
          fecha: DateTime(2024, 1, 2),
          tipo: TipoMovimiento.devolucionCompra,
          cantidad: 5,
          // Sin costoUnitario y sin movimientoReferenciaId: no hay
          // forma de saber a qué costo se devuelve.
        ),
      ];

      expect(
        () => calculator.calcular(movimientosConError, MetodoValuacion.peps),
        throwsA(isA<ReferenciaInvalidaException>()),
      );
    },
  );
}