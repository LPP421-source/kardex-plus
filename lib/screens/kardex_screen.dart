// lib/screens/kardex_screen.dart
//
// Pantalla de la tarjeta kardex de UN producto. Muestra el
// formulario para registrar los 5 tipos de movimiento (saldo
// inicial, compra, venta, devolución en venta, devolución en
// compra) y la tabla kardex calculada en tiempo real.

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/ejercicio.dart';
import '../models/fila_kardex.dart';
import '../models/movimiento_inventario.dart';
import '../models/producto.dart';
import '../services/kardex_calculator.dart';
import '../services/movimiento_service.dart';
import '../services/pdf_report_service.dart';
import '../services/producto_service.dart';
import '../utils/formato_numero.dart';
import '../utils/redondeo_bancario.dart';

class KardexScreen extends StatefulWidget {
  final Ejercicio ejercicio;
  final Producto producto;

  const KardexScreen({
    super.key,
    required this.ejercicio,
    required this.producto,
  });

  @override
  State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  final _movimientoService = MovimientoService();
  final _productoService = ProductoService();
  final _calculator = KardexCalculator();
  final _pdfService = PdfReportService();

  // Guardamos el producto como ESTADO local (no solo como
  // _producto) porque su método de valuación se puede cambiar
  // desde esta misma pantalla, y necesitamos poder actualizarlo sin
  // tener que volver a la pantalla anterior.
  late Producto _producto;

  late Future<List<MovimientoInventario>> _futureMovimientos;

  @override
  void initState() {
    super.initState();
    _producto = widget.producto;
    _cargarMovimientos();
  }

  void _cargarMovimientos() {
    setState(() {
      _futureMovimientos = _movimientoService.obtenerMovimientos(
        _producto.id!,
      );
    });
  }

  /// Cambia el método de valuación de este producto. Como el kardex
  /// se recalcula siempre desde cero (nunca queda "congelado" en la
  /// base de datos), cambiar el método es seguro — pero TODOS los
  /// números de la tarjeta van a cambiar de golpe, así que primero
  /// avisamos con claridad qué va a pasar.
  /// Genera el reporte PDF de la tarjeta kardex de este producto y
  /// abre el diálogo de imprimir/guardar/compartir del sistema.
  Future<void> _exportarPdf() async {
    final movimientos = await _movimientoService.obtenerMovimientos(
      _producto.id!,
    );

    final resultado = _calculator.calcularSeguro(movimientos, _producto.metodo);

    if (resultado.filas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay movimientos para exportar todavía.'),
          ),
        );
      }
      return;
    }

    // Si hay un movimiento con problemas más adelante en el
    // historial, avisamos ANTES de exportar que el PDF solo va a
    // incluir las filas válidas hasta ese punto.
    if (resultado.mensajeError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aviso: se exportarán solo los movimientos válidos '
            '(hay un problema más adelante: ${resultado.mensajeError}).',
          ),
        ),
      );
    }

    final bytes = await _pdfService.generarKardexPdf(
      ejercicio: widget.ejercicio,
      producto: _producto,
      filas: resultado.filas,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Kardex_${_producto.nombre}.pdf',
    );
  }

  Future<void> _cambiarMetodo() async {
    var seleccionTemporal = _producto.metodo;

    final nuevoMetodo = await showDialog<MetodoValuacion>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialogo) => AlertDialog(
          title: const Text('Cambiar método de valuación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Al cambiar el método, TODA la tarjeta se recalcula '
                'con el nuevo método: costos, saldos y el costo de '
                'las devoluciones automáticas pueden cambiar. No se '
                'pierde ningún movimiento registrado, pero los '
                'números que ves van a ser distintos.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MetodoValuacion>(
                initialValue: seleccionTemporal,
                decoration: const InputDecoration(
                  labelText: 'Nuevo método',
                  border: OutlineInputBorder(),
                ),
                items: MetodoValuacion.values.map((metodo) {
                  return DropdownMenuItem(
                    value: metodo,
                    child: Text(metodo.nombreCompleto),
                  );
                }).toList(),
                onChanged: (valor) {
                  if (valor != null) {
                    setStateDialogo(() => seleccionTemporal = valor);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, seleccionTemporal),
              child: const Text('Confirmar cambio'),
            ),
          ],
        ),
      ),
    );

    // Si el usuario canceló, o eligió el mismo método que ya tenía,
    // no hacemos nada.
    if (nuevoMetodo == null || nuevoMetodo == _producto.metodo) return;

    final productoActualizado = _producto.copyWith(metodo: nuevoMetodo);

    try {
      await _productoService.actualizarProducto(productoActualizado);
      setState(() => _producto = productoActualizado);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cambiar método: $e')));
      }
    }
  }

  Future<void> _abrirFormularioMovimiento() async {
    // Traemos los movimientos más recientes ANTES de abrir el
    // formulario, porque las devoluciones automáticas necesitan
    // mostrar una lista de ventas/compras ya registradas.
    final movimientosActuales = await _movimientoService.obtenerMovimientos(
      _producto.id!,
    );

    if (!mounted) return;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoNuevoMovimiento(
        productoId: _producto.id!,
        service: _movimientoService,
        calculator: _calculator,
        metodo: _producto.metodo,
        decimalesCosto: widget.ejercicio.decimalesCosto,
        movimientosExistentes: movimientosActuales,
      ),
    );

    if (guardado == true) {
      _cargarMovimientos();
    }
  }

  Future<void> _editarMovimiento(MovimientoInventario movimiento) async {
    // Igual que al crear: traemos los movimientos más recientes
    // para que las listas de "venta/compra original" del modo
    // automático estén al día.
    final movimientosActuales = await _movimientoService.obtenerMovimientos(
      _producto.id!,
    );

    if (!mounted) return;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoNuevoMovimiento(
        productoId: _producto.id!,
        service: _movimientoService,
        calculator: _calculator,
        metodo: _producto.metodo,
        decimalesCosto: widget.ejercicio.decimalesCosto,
        movimientosExistentes: movimientosActuales,
        movimientoAEditar: movimiento,
      ),
    );

    if (guardado == true) {
      _cargarMovimientos();
    }
  }

  Future<void> _confirmarYBorrarMovimiento(String movimientoId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar movimiento?'),
        content: const Text(
          'El kardex se recalculará sin este movimiento. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await _movimientoService.borrarMovimiento(movimientoId);
      _cargarMovimientos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al borrar: $e')));
      }
    }
  }

  String _formatoEntero(int? valor) => valor == null ? '—' : '$valor';

  /// Para la columna "Costo Unitario": usa los decimales configurados
  /// EN ESTE EJERCICIO (cada ejercicio puede tener un valor distinto),
  /// con separador de miles.
  String _formatoCostoUnitario(double? valor) => valor == null
      ? '—'
      : 'Bs ${formatoConMiles(valor, widget.ejercicio.decimalesCosto)}';

  /// Para montos totales (Entrada/Salida/Saldo en Bs): SIEMPRE 2
  /// decimales, sin importar la configuración del ejercicio — es el
  /// estándar contable para montos de dinero. Usa redondeo bancario
  /// (ver lib/utils/redondeo_bancario.dart) y separador de miles.
  String _formatoMonto(double? valor) {
    if (valor == null) return '—';
    return 'Bs ${formatoConMiles(redondearBancario(valor, 2), 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_producto.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar a PDF',
            onPressed: _exportarPdf,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Cambiar método de valuación',
            onPressed: _cambiarMetodo,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              [
                if (_producto.numeroTarjeta != null)
                  'Nº Tarjeta: ${_producto.numeroTarjeta}',
                if (_producto.codigo != null)
                  'Código: ${_producto.codigo}',
                'Unidad: ${_producto.unidadMedida}',
                'Método: ${_producto.metodo.nombreCompleto}',
              ].join('  ·  '),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<MovimientoInventario>>(
        future: _futureMovimientos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar: ${snapshot.error}'),
            );
          }

          final movimientos = snapshot.data ?? [];

          if (movimientos.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no hay movimientos.\n'
                'Toca el botón + para registrar el saldo inicial, '
                'una compra o una venta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final resultado = _calculator.calcularSeguro(
            movimientos,
            _producto.metodo,
          );
          final filas = resultado.filas;

          // Si no hay NINGUNA fila válida (el problema está desde
          // el primer movimiento), mostramos solo el aviso.
          if (filas.isEmpty && resultado.mensajeError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  '⚠️ ${resultado.mensajeError}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 15),
                ),
              ),
            );
          }

          return Column(
            children: [
              // Si hay un problema MÁS ADELANTE en el historial,
              // mostramos las filas válidas de todas formas, con
              // este aviso arriba explicando qué falta corregir.
              if (resultado.mensajeError != null)
                Container(
                  width: double.infinity,
                  color: Colors.red.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '⚠️ ${resultado.mensajeError}\n'
                    'Corrige o borra ese movimiento para ver el resto '
                    'del kardex.',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              Expanded(child: _construirTabla(filas, movimientos)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioMovimiento,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Anchos fijos de cada columna, en píxeles. Los usamos tanto en
  // los encabezados como en las filas de datos para que todo quede
  // alineado en la tabla.
  static const _wFecha = 90.0;
  static const _wDetalle = 150.0;
  static const _wCantidad = 65.0; // Entrada/Salida/Saldo (físico)
  static const _wCostoUnitario = 85.0;
  static const _wValorizado = 95.0; // Entrada/Salida/Saldo (valorado)
  static const _wAcciones = 92.0;

  Widget _construirTabla(
    List<FilaKardex> filas,
    List<MovimientoInventario> movimientos,
  ) {
    if (filas.isEmpty) {
      return const Center(child: Text('No hay filas para mostrar.'));
    }

    // --- Totales, igual que la fila "TOTAL" de una tarjeta kardex
    // física: suma de todas las entradas, de todas las salidas, y
    // el saldo final (el de la última fila, no una suma).
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
    final saldoFinal = filas.last;

    // InteractiveViewer permite hacer zoom (pellizcando en el celular,
    // o con Ctrl + rueda del mouse / gesto de pellizco en trackpad en
    // Chrome) y arrastrar la tabla libremente en cualquier dirección
    // — mucho más cómodo en pantallas chicas que un scroll fijo.
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(60),
      minScale: 0.5,
      maxScale: 3.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filaEncabezadoGrupos(),
          _filaEncabezadoColumnas(),
          for (final fila in filas) _filaDeDatos(fila, movimientos),
          _filaTotales(
            totalEntradaCant: totalEntradaCant,
            totalEntradaVal: totalEntradaVal,
            totalSalidaCant: totalSalidaCant,
            totalSalidaVal: totalSalidaVal,
            saldoFinal: saldoFinal,
          ),
        ],
      ),
    );
  }

  /// Primera fila de encabezado: aquí es donde "combinamos" celdas
  /// visualmente — un solo bloque ancho para "CONTROL FÍSICO" y
  /// otro para "CONTROL VALORADO", cada uno abarcando el espacio de
  /// sus 3 columnas de abajo.
  Widget _filaEncabezadoGrupos() {
    return Row(
      children: [
        _celdaEncabezado('', _wFecha),
        _celdaEncabezado('', _wDetalle),
        _celdaEncabezado(
          'CONTROL FÍSICO',
          _wCantidad * 3,
          color: Colors.blueGrey.shade100,
        ),
        _celdaEncabezado('', _wCostoUnitario),
        _celdaEncabezado(
          'CONTROL VALORADO',
          _wValorizado * 3,
          color: Colors.blueGrey.shade100,
        ),
        _celdaEncabezado('', _wAcciones),
      ],
    );
  }

  /// Segunda fila de encabezado: los subtítulos (Fecha, Detalle,
  /// Entrada/Salida/Saldo repetidos bajo cada grupo, Costo
  /// Unitario, Acciones).
  Widget _filaEncabezadoColumnas() {
    return Row(
      children: [
        _celdaEncabezado('Fecha', _wFecha),
        _celdaEncabezado('Detalle', _wDetalle),
        _celdaEncabezado('Entrada', _wCantidad),
        _celdaEncabezado('Salida', _wCantidad),
        _celdaEncabezado('Saldo', _wCantidad),
        _celdaEncabezado('Costo\nUnitario', _wCostoUnitario),
        _celdaEncabezado('Entrada', _wValorizado),
        _celdaEncabezado('Salida', _wValorizado),
        _celdaEncabezado('Saldo', _wValorizado),
        _celdaEncabezado('Acciones', _wAcciones),
      ],
    );
  }

  Widget _filaDeDatos(FilaKardex fila, List<MovimientoInventario> movimientos) {
    final esEntrada = fila.tipo.esEntrada;
    final colorFondo = esEntrada
        ? Colors.green.withValues(alpha: 0.06)
        : Colors.orange.withValues(alpha: 0.06);

    // El costo unitario es el de entrada O el de salida, nunca
    // ambos a la vez (cada fila es una sola cosa).
    final costoUnitario = fila.costoUnitarioEntrada ?? fila.costoUnitarioSalida;

    // Buscamos el movimiento original completo (no solo el id) para
    // poder abrir el formulario de edición con sus datos precargados.
    final movimientoOriginal = fila.movimientoId == null
        ? null
        : movimientos.firstWhere((m) => m.id == fila.movimientoId);

    return Row(
      children: [
        _celdaDato(
          fila.fecha.toIso8601String().substring(0, 10),
          _wFecha,
          color: colorFondo,
        ),
        _celdaDato(fila.tipo.nombreCompleto, _wDetalle, color: colorFondo),
        _celdaDato(
          _formatoEntero(fila.cantidadEntrada),
          _wCantidad,
          color: colorFondo,
        ),
        _celdaDato(
          _formatoEntero(fila.cantidadSalida),
          _wCantidad,
          color: colorFondo,
        ),
        _celdaDato(
          '${fila.saldoCantidad}',
          _wCantidad,
          color: colorFondo,
          negrita: true,
        ),
        _celdaDato(
          _formatoCostoUnitario(costoUnitario),
          _wCostoUnitario,
          color: colorFondo,
        ),
        _celdaDato(
          _formatoMonto(fila.costoTotalEntrada),
          _wValorizado,
          color: colorFondo,
        ),
        _celdaDato(
          _formatoMonto(fila.costoTotalSalida),
          _wValorizado,
          color: colorFondo,
        ),
        _celdaDato(
          _formatoMonto(fila.saldoValorizado),
          _wValorizado,
          color: colorFondo,
          negrita: true,
        ),
        Container(
          width: _wAcciones,
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: colorFondo,
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: movimientoOriginal == null
              ? const SizedBox.shrink()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _editarMovimiento(movimientoOriginal),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      onPressed: () =>
                          _confirmarYBorrarMovimiento(fila.movimientoId!),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _filaTotales({
    required int totalEntradaCant,
    required double totalEntradaVal,
    required int totalSalidaCant,
    required double totalSalidaVal,
    required FilaKardex saldoFinal,
  }) {
    const colorTotal = Color(0xFFE0E0E0);
    return Container(
      // Borde superior grueso para que esta fila se distinga
      // claramente de las de arriba, incluso si el usuario tiene
      // desplazada la tabla y no ve la palabra "TOTAL" a la
      // izquierda.
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black54, width: 2)),
      ),
      child: Row(
        children: [
          _celdaDato('', _wFecha, color: colorTotal),
          _celdaDato('TOTAL', _wDetalle, color: colorTotal, negrita: true),
          _celdaDato(
            totalEntradaCant == 0 ? '—' : '$totalEntradaCant',
            _wCantidad,
            color: colorTotal,
            negrita: true,
          ),
          _celdaDato(
            totalSalidaCant == 0 ? '—' : '$totalSalidaCant',
            _wCantidad,
            color: colorTotal,
            negrita: true,
          ),
          _celdaDato(
            '${saldoFinal.saldoCantidad}',
            _wCantidad,
            color: colorTotal,
            negrita: true,
          ),
          _celdaDato('—', _wCostoUnitario, color: colorTotal),
          _celdaDato(
            totalEntradaCant == 0 ? '—' : _formatoMonto(totalEntradaVal),
            _wValorizado,
            color: colorTotal,
            negrita: true,
          ),
          _celdaDato(
            totalSalidaCant == 0 ? '—' : _formatoMonto(totalSalidaVal),
            _wValorizado,
            color: colorTotal,
            negrita: true,
          ),
          _celdaDato(
            _formatoMonto(saldoFinal.saldoValorizado),
            _wValorizado,
            color: colorTotal,
            negrita: true,
          ),
          _celdaDato('', _wAcciones, color: colorTotal),
        ],
      ),
    );
  }

  Widget _celdaEncabezado(String texto, double ancho, {Color? color}) {
    return Container(
      width: ancho,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _celdaDato(
    String texto,
    double ancho, {
    Color? color,
    bool negrita = false,
  }) {
    return Container(
      width: ancho,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Diálogo emergente con el formulario de un nuevo movimiento.
/// Se adapta según el tipo elegido: Saldo Inicial y Compra piden
/// costo unitario; Venta no pide nada más (se calcula sola);
/// las Devoluciones piden elegir entre modo Automático (con una
/// referencia) o Manual (con un costo escrito a mano).
class _DialogoNuevoMovimiento extends StatefulWidget {
  final String productoId;
  final MovimientoService service;
  final KardexCalculator calculator;
  final MetodoValuacion metodo;
  final int decimalesCosto;
  final List<MovimientoInventario> movimientosExistentes;

  /// Si viene con un valor, el diálogo entra en modo EDICIÓN:
  /// precarga sus datos y actualiza en vez de crear uno nuevo.
  final MovimientoInventario? movimientoAEditar;

  const _DialogoNuevoMovimiento({
    required this.productoId,
    required this.service,
    required this.calculator,
    required this.metodo,
    required this.decimalesCosto,
    required this.movimientosExistentes,
    this.movimientoAEditar,
  });

  @override
  State<_DialogoNuevoMovimiento> createState() =>
      _DialogoNuevoMovimientoState();
}

class _DialogoNuevoMovimientoState extends State<_DialogoNuevoMovimiento> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();
  final _costoController = TextEditingController();

  DateTime _fechaSeleccionada = DateTime.now();
  TipoMovimiento _tipoSeleccionado = TipoMovimiento.compra;

  // Para Devolución en Venta / Devolución en Compra:
  bool _modoAutomatico = true;
  MovimientoInventario? _referenciaSeleccionada;

  bool _guardando = false;

  bool get _esEdicion => widget.movimientoAEditar != null;

  @override
  void initState() {
    super.initState();
    final mov = widget.movimientoAEditar;
    if (mov == null) return;

    // Precargamos todos los campos con los datos del movimiento
    // que se está editando.
    _tipoSeleccionado = mov.tipo;
    _fechaSeleccionada = mov.fecha;
    _cantidadController.text = '${mov.cantidad}';

    if (mov.tipo == TipoMovimiento.devolucionVenta ||
        mov.tipo == TipoMovimiento.devolucionCompra) {
      if (mov.movimientoReferenciaId != null) {
        // Estaba en modo automático: buscamos a qué movimiento
        // apuntaba, para dejarlo ya seleccionado en el desplegable.
        _modoAutomatico = true;
        try {
          _referenciaSeleccionada = widget.movimientosExistentes.firstWhere(
            (m) => m.id == mov.movimientoReferenciaId,
          );
        } catch (_) {
          _referenciaSeleccionada = null;
        }
      } else {
        _modoAutomatico = false;
        _costoController.text = '${mov.costoUnitario}';
      }
    } else if (mov.costoUnitario != null) {
      _costoController.text = '${mov.costoUnitario}';
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _costoController.dispose();
    super.dispose();
  }

  bool get _esEntradaSimple =>
      _tipoSeleccionado == TipoMovimiento.saldoInicial ||
      _tipoSeleccionado == TipoMovimiento.compra;

  bool get _esVenta => _tipoSeleccionado == TipoMovimiento.venta;

  bool get _esDevolucionVenta =>
      _tipoSeleccionado == TipoMovimiento.devolucionVenta;

  bool get _esDevolucionCompra =>
      _tipoSeleccionado == TipoMovimiento.devolucionCompra;

  bool get _esDevolucion => _esDevolucionVenta || _esDevolucionCompra;

  /// Ventas ya registradas (para elegir cuál se está devolviendo).
  List<MovimientoInventario> get _ventasDisponibles => widget
      .movimientosExistentes
      .where((m) => m.tipo == TipoMovimiento.venta)
      .toList();

  /// Compras (y saldo inicial) ya registradas (para elegir cuál se
  /// está devolviendo al proveedor).
  List<MovimientoInventario> get _comprasDisponibles => widget
      .movimientosExistentes
      .where(
        (m) =>
            m.tipo == TipoMovimiento.compra ||
            m.tipo == TipoMovimiento.saldoInicial,
      )
      .toList();

  /// Costos distintos ya usados en compras/saldo inicial, para
  /// sugerírselos al usuario en el modo manual de devolución en
  /// compra (así no tiene que adivinar qué costos existen).
  List<double> get _costosSugeridos {
    final costos = _comprasDisponibles
        .map((m) => m.costoUnitario)
        .whereType<double>()
        .toSet()
        .toList();
    costos.sort();
    return costos;
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _fechaSeleccionada = fecha);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación extra para el modo automático: si el usuario no
    // eligió una referencia, no dejamos guardar (el Form normal no
    // valida dropdowns de este tipo tan fácil, así que lo hacemos
    // a mano aquí).
    if (_esDevolucion && _modoAutomatico && _referenciaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona a qué movimiento corresponde la devolución'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    double? costoUnitario;
    String? referenciaId;

    if (_esEntradaSimple) {
      costoUnitario = double.parse(_costoController.text);
    } else if (_esDevolucion) {
      if (_modoAutomatico) {
        referenciaId = _referenciaSeleccionada!.id;
      } else {
        costoUnitario = double.parse(_costoController.text);
      }
    }
    // En Venta, costoUnitario y referenciaId quedan null: se calcula solo.

    final movimiento = MovimientoInventario(
      id: widget.movimientoAEditar?.id,
      productoId: widget.productoId,
      fecha: _fechaSeleccionada,
      tipo: _tipoSeleccionado,
      cantidad: int.parse(_cantidadController.text),
      costoUnitario: costoUnitario,
      movimientoReferenciaId: referenciaId,
    );

    // VALIDACIÓN CLAVE: antes de guardar nada en Supabase, probamos
    // cómo quedaría el kardex completo SI agregáramos (o
    // reemplazáramos) este movimiento. Si eso lanza un error (ej:
    // stock insuficiente), avisamos y NO guardamos.
    //
    // Si estamos EDITANDO, hay que sacar la versión VIEJA de este
    // mismo movimiento de la lista antes de probar — si no, el
    // cálculo contaría el movimiento dos veces (la vieja y la
    // nueva) y daría resultados incorrectos.
    final listaParaValidar = _esEdicion
        ? [
            ...widget.movimientosExistentes.where(
              (m) => m.id != widget.movimientoAEditar!.id,
            ),
            movimiento,
          ]
        : [...widget.movimientosExistentes, movimiento];

    try {
      widget.calculator.calcular(listaParaValidar, widget.metodo);
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }

    try {
      if (_esEdicion) {
        await widget.service.actualizarMovimiento(movimiento);
      } else {
        await widget.service.crearMovimiento(movimiento);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _guardando = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  String _etiquetaMovimiento(MovimientoInventario m) {
    final fecha = m.fecha.toIso8601String().substring(0, 10);
    return '$fecha — ${m.cantidad} unidades'
        '${m.costoUnitario != null ? ' a Bs ${formatoConMiles(m.costoUnitario!, widget.decimalesCosto)}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar Movimiento' : 'Nuevo Movimiento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de tipo: los 5 posibles.
              DropdownButtonFormField<TipoMovimiento>(
                initialValue: _tipoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Tipo de movimiento',
                  border: OutlineInputBorder(),
                ),
                items: TipoMovimiento.values.map((tipo) {
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text(tipo.nombreCompleto),
                  );
                }).toList(),
                onChanged: (nuevoTipo) {
                  if (nuevoTipo != null) {
                    setState(() {
                      _tipoSeleccionado = nuevoTipo;
                      _referenciaSeleccionada = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Fecha.
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha'),
                subtitle: Text(
                  _fechaSeleccionada.toIso8601String().substring(0, 10),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _seleccionarFecha,
              ),
              const SizedBox(height: 8),

              // Cantidad (siempre visible).
              TextFormField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  final numero = int.tryParse(valor ?? '');
                  if (numero == null || numero <= 0) {
                    return 'Ingresa una cantidad válida (mayor a 0)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Caso 1: Saldo Inicial o Compra → costo obligatorio.
              if (_esEntradaSimple)
                TextFormField(
                  controller: _costoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario (Bs)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    final numero = double.tryParse(valor ?? '');
                    if (numero == null || numero <= 0) {
                      return 'Ingresa un costo válido (mayor a 0)';
                    }
                    return null;
                  },
                ),

              // --- Caso 2: Venta → nada más, se calcula sola.
              if (_esVenta)
                const Text(
                  'El costo de salida se calculará automáticamente '
                  'según el método de valuación del ejercicio.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),

              // --- Caso 3: Devoluciones → elegir Automático o Manual.
              if (_esDevolucion) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Automático')),
                    ButtonSegment(value: false, label: Text('Manual')),
                  ],
                  selected: {_modoAutomatico},
                  onSelectionChanged: (nuevaSeleccion) {
                    setState(() {
                      _modoAutomatico = nuevaSeleccion.first;
                      _referenciaSeleccionada = null;
                    });
                  },
                ),
                const SizedBox(height: 12),

                if (_modoAutomatico) ...[
                  Text(
                    _esDevolucionVenta
                        ? 'El costo se toma del último lote usado en la '
                              'venta que elijas:'
                        : 'El costo se toma de la compra original que elijas:',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<MovimientoInventario>(
                    initialValue: _referenciaSeleccionada,
                    decoration: InputDecoration(
                      labelText: _esDevolucionVenta
                          ? 'Venta original'
                          : 'Compra original',
                      border: const OutlineInputBorder(),
                    ),
                    items:
                        (_esDevolucionVenta
                                ? _ventasDisponibles
                                : _comprasDisponibles)
                            .map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Text(_etiquetaMovimiento(m)),
                              );
                            })
                            .toList(),
                    onChanged: (nuevaReferencia) {
                      setState(() => _referenciaSeleccionada = nuevaReferencia);
                    },
                  ),
                ] else ...[
                  // Modo manual: costo escrito a mano. Para
                  // Devolución en Compra, además mostramos los
                  // costos ya usados como sugerencia rápida.
                  if (_esDevolucionCompra && _costosSugeridos.isNotEmpty) ...[
                    const Text(
                      'Costos ya registrados en compras (toca uno para '
                      'usarlo):',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _costosSugeridos.map((costo) {
                        return ActionChip(
                          label: Text(
                            'Bs ${formatoConMiles(costo, widget.decimalesCosto)}',
                          ),
                          onPressed: () {
                            // Aquí SIN separador de miles: este valor
                            // se vuelve a interpretar como número al
                            // guardar, así que debe quedar "limpio".
                            _costoController.text = costo.toStringAsFixed(
                              widget.decimalesCosto,
                            );
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    controller: _costoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Costo unitario (Bs)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      final numero = double.tryParse(valor ?? '');
                      if (numero == null || numero <= 0) {
                        return 'Ingresa un costo válido (mayor a 0)';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_esEdicion ? 'Actualizar' : 'Guardar'),
        ),
      ],
    );
  }
}