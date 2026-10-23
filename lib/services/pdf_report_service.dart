// lib/services/pdf_report_service.dart
//
// Genera el reporte en PDF de la tarjeta kardex de uno o varios
// productos, con el mismo formato que ves en pantalla: encabezados
// combinados (CONTROL FÍSICO / CONTROL VALORADO), fila de TOTAL, y
// respetando los mismos decimales configurados en el ejercicio.
//
// Usa el paquete "pdf" para construir el documento y "printing"
// para mostrarlo (el usuario puede imprimirlo, guardarlo o
// compartirlo desde ese mismo diálogo — funciona igual en Chrome,
// Windows o Android).

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/ejercicio.dart';
import '../models/fila_kardex.dart';
import '../models/movimiento_inventario.dart';
import '../models/producto.dart';
import '../utils/formato_numero.dart';
import '../utils/redondeo_bancario.dart';

/// Agrupa un producto con su tabla kardex ya calculada, para poder
/// generar el reporte de "todas las tarjetas" de un ejercicio.
class ProductoConFilas {
  final Producto producto;
  final List<FilaKardex> filas;
  ProductoConFilas({required this.producto, required this.filas});
}

class PdfReportService {
  // Mismos anchos "proporcionales" que usamos en la pantalla, pero
  // en puntos (la unidad que usa el PDF), ajustados para que quepan
  // bien en una hoja A4 apaisada (horizontal).
  static const _wFecha = 65.0;
  static const _wDetalle = 120.0;
  static const _wCantidad = 50.0;
  static const _wCostoUnitario = 80.0;
  static const _wValorizado = 85.0;

  /// Genera el PDF de la tarjeta kardex de UN SOLO producto.
  Future<Uint8List> generarKardexPdf({
    required Ejercicio ejercicio,
    required Producto producto,
    required List<FilaKardex> filas,
  }) async {
    final doc = pw.Document();
    doc.addPage(_paginaDeProducto(ejercicio, producto, filas));
    return doc.save();
  }

  /// Genera UN SOLO PDF con las tarjetas kardex de VARIOS productos
  /// (por ejemplo, todos los de un ejercicio). Cada producto
  /// SIEMPRE empieza en una hoja nueva — así ninguna tarjeta queda
  /// "cortada a la mitad" compartiendo hoja con la siguiente.
  Future<Uint8List> generarReporteCompleto({
    required Ejercicio ejercicio,
    required List<ProductoConFilas> productos,
  }) async {
    final doc = pw.Document();
    for (final item in productos) {
      // Cada llamada a addPage() con un MultiPage arranca en una
      // hoja nueva — por eso alcanza con esto para que nunca se
      // mezclen dos productos en la misma página.
      doc.addPage(_paginaDeProducto(ejercicio, item.producto, item.filas));
    }
    return doc.save();
  }

  /// Construye el bloque completo (encabezado + tabla + total) de
  /// UN producto, como su propio MultiPage independiente. Si la
  /// tabla de ese producto es muy larga, esta misma pieza se sigue
  /// paginando sola en varias hojas (eso sí está bien que pase);
  /// lo que evitamos es que SE MEZCLE con el siguiente producto.
  pw.MultiPage _paginaDeProducto(
    Ejercicio ejercicio,
    Producto producto,
    List<FilaKardex> filas,
  ) {
    final totalEntradaCant = filas.fold<int>(
      0,
      (s, f) => s + (f.cantidadEntrada ?? 0),
    );
    final totalEntradaVal = filas.fold<double>(
      0,
      (s, f) => s + (f.costoTotalEntrada ?? 0),
    );
    final totalSalidaCant = filas.fold<int>(
      0,
      (s, f) => s + (f.cantidadSalida ?? 0),
    );
    final totalSalidaVal = filas.fold<double>(
      0,
      (s, f) => s + (f.costoTotalSalida ?? 0),
    );
    final saldoFinal = filas.isNotEmpty ? filas.last : null;

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      // El "header" se repite en cada página de ESTE producto (si
      // su tabla es larga y no cabe en una sola hoja). Los datos
      // del producto solo se muestran en la primera de sus páginas;
      // los encabezados de columnas se repiten siempre.
      header: (context) {
        return pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (context.pageNumber == 1) ...[
                pw.Text(
                  'TARJETA DE CONTROL FÍSICO-VALORADO',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _dato('Artículo', producto.nombre),
                        _dato('Código', producto.codigo ?? '—'),
                        _dato('Unidad de medida', producto.unidadMedida),
                      ],
                    ),
                    pw.SizedBox(width: 60),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _dato('Nº de Tarjeta', producto.numeroTarjeta ?? '—'),
                        _dato(
                          'Método de valuación',
                          producto.metodo.nombreCompleto,
                        ),
                        if (ejercicio.empresa != null)
                          _dato('Empresa', ejercicio.empresa!),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),
              ],
              if (filas.isNotEmpty)
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _celda('', _wFecha),
                    _celda('', _wDetalle),
                    _celda(
                      'CONTROL FÍSICO',
                      _wCantidad * 3,
                      negrita: true,
                      color: PdfColors.blueGrey100,
                    ),
                    _celda('', _wCostoUnitario),
                    _celda(
                      'CONTROL VALORADO',
                      _wValorizado * 3,
                      negrita: true,
                      color: PdfColors.blueGrey100,
                    ),
                  ],
                ),
              if (filas.isNotEmpty)
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    _celda('Fecha', _wFecha, negrita: true),
                    _celda('Detalle', _wDetalle, negrita: true),
                    _celda('Entrada', _wCantidad, negrita: true),
                    _celda('Salida', _wCantidad, negrita: true),
                    _celda('Saldo', _wCantidad, negrita: true),
                    _celda('Costo\nUnitario', _wCostoUnitario, negrita: true),
                    _celda('Entrada', _wValorizado, negrita: true),
                    _celda('Salida', _wValorizado, negrita: true),
                    _celda('Saldo', _wValorizado, negrita: true),
                  ],
                ),
            ],
          ),
        );
      },
      build: (context) {
        if (filas.isEmpty) {
          return [
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 30),
                child: pw.Text(
                  'Este producto todavía no tiene movimientos registrados.',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ),
          ];
        }
        return [
          for (final fila in filas)
            pw.Center(child: _filaDeDatos(fila, ejercicio)),
          if (saldoFinal != null)
            pw.Center(
              child: _filaTotal(
                totalEntradaCant: totalEntradaCant,
                totalEntradaVal: totalEntradaVal,
                totalSalidaCant: totalSalidaCant,
                totalSalidaVal: totalSalidaVal,
                saldoFinal: saldoFinal,
              ),
            ),
        ];
      },
    );
  }

  pw.Widget _dato(String etiqueta, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(
        '$etiqueta: $valor',
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }

  pw.Widget _filaDeDatos(FilaKardex fila, Ejercicio ejercicio) {
    final costoUnitario = fila.costoUnitarioEntrada ?? fila.costoUnitarioSalida;
    final colorFondo = fila.tipo.esEntrada
        ? PdfColors.green50
        : PdfColors.orange50;

    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _celda(
          fila.fecha.toIso8601String().substring(0, 10),
          _wFecha,
          color: colorFondo,
        ),
        _celda(fila.tipo.nombreCompleto, _wDetalle, color: colorFondo),
        _celda(_formatoEntero(fila.cantidadEntrada), _wCantidad, color: colorFondo),
        _celda(_formatoEntero(fila.cantidadSalida), _wCantidad, color: colorFondo),
        _celda(
          '${fila.saldoCantidad}',
          _wCantidad,
          negrita: true,
          color: colorFondo,
        ),
        _celda(
          _formatoCostoUnitario(costoUnitario, ejercicio.decimalesCosto),
          _wCostoUnitario,
          color: colorFondo,
        ),
        _celda(_formatoMonto(fila.costoTotalEntrada), _wValorizado, color: colorFondo),
        _celda(_formatoMonto(fila.costoTotalSalida), _wValorizado, color: colorFondo),
        _celda(
          _formatoMonto(fila.saldoValorizado),
          _wValorizado,
          negrita: true,
          color: colorFondo,
        ),
      ],
    );
  }

  pw.Widget _filaTotal({
    required int totalEntradaCant,
    required double totalEntradaVal,
    required int totalSalidaCant,
    required double totalSalidaVal,
    required FilaKardex saldoFinal,
  }) {
    const colorTotal = PdfColors.grey300;
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        _celda('', _wFecha, color: colorTotal),
        _celda('TOTAL', _wDetalle, negrita: true, color: colorTotal),
        _celda(
          totalEntradaCant == 0 ? '—' : '$totalEntradaCant',
          _wCantidad,
          negrita: true,
          color: colorTotal,
        ),
        _celda(
          totalSalidaCant == 0 ? '—' : '$totalSalidaCant',
          _wCantidad,
          negrita: true,
          color: colorTotal,
        ),
        _celda(
          '${saldoFinal.saldoCantidad}',
          _wCantidad,
          negrita: true,
          color: colorTotal,
        ),
        _celda('—', _wCostoUnitario, color: colorTotal),
        _celda(
          totalEntradaCant == 0 ? '—' : _formatoMonto(totalEntradaVal),
          _wValorizado,
          negrita: true,
          color: colorTotal,
        ),
        _celda(
          totalSalidaCant == 0 ? '—' : _formatoMonto(totalSalidaVal),
          _wValorizado,
          negrita: true,
          color: colorTotal,
        ),
        _celda(
          _formatoMonto(saldoFinal.saldoValorizado),
          _wValorizado,
          negrita: true,
          color: colorTotal,
        ),
      ],
    );
  }

  pw.Widget _celda(
    String texto,
    double ancho, {
    bool negrita = false,
    PdfColor? color,
  }) {
    return pw.Container(
      width: ancho,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      decoration: pw.BoxDecoration(
        color: color,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Text(
        texto,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _formatoEntero(int? valor) => valor == null ? '—' : '$valor';

  String _formatoCostoUnitario(double? valor, int decimales) =>
      valor == null ? '—' : formatoConMiles(valor, decimales);

  String _formatoMonto(double? valor) =>
      valor == null ? '—' : formatoConMiles(redondearBancario(valor, 2), 2);
}