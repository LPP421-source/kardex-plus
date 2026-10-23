// lib/screens/lista_productos_screen.dart
//
// Se abre al tocar un ejercicio. Muestra sus productos; cada uno
// lleva a su propia tarjeta kardex (KardexScreen).

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/categoria.dart';
import '../models/ejercicio.dart';
import '../models/producto.dart';
import '../services/categoria_service.dart';
import '../services/kardex_calculator.dart';
import '../services/movimiento_service.dart';
import '../services/pdf_report_service.dart';
import '../services/producto_service.dart';
import '../utils/formato_numero.dart';
import '../utils/redondeo_bancario.dart';
import 'crear_producto_screen.dart';
import 'kardex_screen.dart';

/// Un producto junto con su saldo actual (ya calculado), para poder
/// mostrarlo en la lista sin tener que entrar a su tarjeta kardex.
class _ProductoConSaldo {
  final Producto producto;

  /// null si el producto todavía no tiene movimientos.
  final int? saldoCantidad;
  final double? saldoValorizado;

  /// true si hay algún movimiento con problemas en su historial
  /// (ej: una venta sin stock suficiente).
  final bool hayError;

  _ProductoConSaldo({
    required this.producto,
    this.saldoCantidad,
    this.saldoValorizado,
    this.hayError = false,
  });
}

/// Todo lo que necesita la pantalla para dibujarse, cargado junto.
class _DatosPantalla {
  final List<Categoria> categorias;
  final List<_ProductoConSaldo> productos;
  _DatosPantalla({required this.categorias, required this.productos});
}

class ListaProductosScreen extends StatefulWidget {
  final Ejercicio ejercicio;

  const ListaProductosScreen({super.key, required this.ejercicio});

  @override
  State<ListaProductosScreen> createState() => _ListaProductosScreenState();
}

class _ListaProductosScreenState extends State<ListaProductosScreen> {
  final _service = ProductoService();
  final _categoriaService = CategoriaService();
  final _movimientoService = MovimientoService();
  final _calculator = KardexCalculator();
  final _pdfService = PdfReportService();
  late Future<_DatosPantalla> _futureDatos;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  void _cargarProductos() {
    setState(() {
      _futureDatos = _cargarDatos();
    });
  }

  /// Trae las categorías y los productos del ejercicio, y para cada
  /// producto calcula su saldo actual (cantidad y Bs) usando el mismo
  /// motor del kardex — así se ve el saldo sin tener que entrar a la
  /// tarjeta.
  Future<_DatosPantalla> _cargarDatos() async {
    final categorias = await _categoriaService.obtenerCategorias(
      widget.ejercicio.id!,
    );
    final productos = await _service.obtenerProductos(widget.ejercicio.id!);

    final productosConSaldo = <_ProductoConSaldo>[];
    for (final producto in productos) {
      final movimientos = await _movimientoService.obtenerMovimientos(
        producto.id!,
      );

      if (movimientos.isEmpty) {
        productosConSaldo.add(_ProductoConSaldo(producto: producto));
        continue;
      }

      final resultado = _calculator.calcularSeguro(movimientos, producto.metodo);
      final ultimaFila = resultado.filas.isNotEmpty
          ? resultado.filas.last
          : null;

      productosConSaldo.add(
        _ProductoConSaldo(
          producto: producto,
          saldoCantidad: ultimaFila?.saldoCantidad,
          saldoValorizado: ultimaFila?.saldoValorizado,
          hayError: resultado.mensajeError != null,
        ),
      );
    }

    return _DatosPantalla(categorias: categorias, productos: productosConSaldo);
  }

  Future<void> _crearOEditarProducto({Producto? productoAEditar}) async {
    // Sugerimos el siguiente número de tarjeta según cuántos
    // productos ya tiene este ejercicio (solo aplica al crear uno
    // nuevo, no al editar).
    int? sugerencia;
    if (productoAEditar == null) {
      final datos = await _futureDatos;
      sugerencia = datos.productos.length + 1;
    }

    if (!mounted) return;

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearProductoScreen(
          ejercicioId: widget.ejercicio.id!,
          productoAEditar: productoAEditar,
          numeroTarjetaSugerido: sugerencia,
          metodoSugerido: widget.ejercicio.metodo,
        ),
      ),
    );
    if (resultado == true) _cargarProductos();
  }

  /// Deja que el usuario elija CUÁLES productos quiere incluir en
  /// el PDF (con casillas de verificación), y después genera el
  /// reporte solo con los que marcó.
  Future<void> _exportarTodoAPdf() async {
    final datos = await _futureDatos;
    final todosLosProductos = datos.productos.map((p) => p.producto).toList();

    if (todosLosProductos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este ejercicio todavía no tiene productos.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final seleccionados = await showDialog<List<Producto>>(
      context: context,
      builder: (context) =>
          _DialogoSeleccionarProductos(productos: todosLosProductos),
    );

    // El usuario canceló, o no marcó ninguno.
    if (seleccionados == null || seleccionados.isEmpty) return;

    await _generarYMostrarPdf(seleccionados);
  }

  /// Genera el PDF con las tarjetas de los productos indicados
  /// (cada una en su propia hoja, sin mezclarse entre sí) y abre el
  /// diálogo de imprimir/guardar/compartir.
  Future<void> _generarYMostrarPdf(List<Producto> productos) async {
    // Mostramos un diálogo de carga mientras se arma el PDF (puede
    // tardar un poco si hay muchos productos con muchos movimientos).
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Generando el PDF de todas las tarjetas...')),
            ],
          ),
        ),
      );
    }

    try {
      final items = <ProductoConFilas>[];
      for (final producto in productos) {
        final movimientos = await _movimientoService.obtenerMovimientos(
          producto.id!,
        );
        final resultado = _calculator.calcularSeguro(
          movimientos,
          producto.metodo,
        );
        items.add(ProductoConFilas(producto: producto, filas: resultado.filas));
      }

      final bytes = await _pdfService.generarReporteCompleto(
        ejercicio: widget.ejercicio,
        productos: items,
      );

      if (mounted) Navigator.pop(context); // cierra el diálogo de carga

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'Kardex_${widget.ejercicio.nombre}.pdf',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // cierra el diálogo de carga
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al generar el PDF: $e')));
      }
    }
  }

  Future<void> _confirmarYBorrar(Producto producto) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar producto?'),
        content: Text(
          'Se borrará "${producto.nombre}" y todo su historial de '
          'movimientos. Esta acción no se puede deshacer.',
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
      await _service.borrarProducto(producto.id!);
      _cargarProductos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al borrar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ejercicio.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar tarjetas a PDF',
            onPressed: _exportarTodoAPdf,
          ),
        ],
      ),
      body: FutureBuilder<_DatosPantalla>(
        future: _futureDatos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }

          final datos = snapshot.data!;

          if (datos.productos.isEmpty) {
            return const Center(
              child: Text(
                'Este ejercicio todavía no tiene productos.\n'
                'Toca el botón + para agregar uno.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: _construirGrupos(datos),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _crearOEditarProducto(),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Arma la lista: un encabezado por cada categoría que tenga
  /// productos, seguido de las tarjetas de esos productos. Los que
  /// no tienen categoría van al final bajo "Sin categoría" (pero si
  /// el ejercicio no usa categorías para nada, no mostramos ningún
  /// encabezado, para que se vea limpio como antes).
  List<Widget> _construirGrupos(_DatosPantalla datos) {
    final widgets = <Widget>[];

    // Agrupamos los productos por el id de su categoría.
    final porCategoria = <String?, List<_ProductoConSaldo>>{};
    for (final item in datos.productos) {
      porCategoria.putIfAbsent(item.producto.categoriaId, () => []).add(item);
    }

    final hayCategoriasEnUso = datos.categorias.any(
      (c) => (porCategoria[c.id] ?? []).isNotEmpty,
    );

    // Primero, cada categoría en el orden en que fue creada.
    for (final categoria in datos.categorias) {
      final productosDeLaCategoria = porCategoria[categoria.id] ?? [];
      if (productosDeLaCategoria.isEmpty) continue;

      widgets.add(_encabezadoDeGrupo(categoria.nombre));
      widgets.addAll(productosDeLaCategoria.map(_tarjetaDeProducto));
    }

    // Después, los productos sin categoría.
    final sinCategoria = porCategoria[null] ?? [];
    if (sinCategoria.isNotEmpty) {
      if (hayCategoriasEnUso) widgets.add(_encabezadoDeGrupo('Sin categoría'));
      widgets.addAll(sinCategoria.map(_tarjetaDeProducto));
    }

    return widgets;
  }

  Widget _encabezadoDeGrupo(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        titulo.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// Texto del saldo que se muestra en cada tarjeta de producto.
  String _textoDeSaldo(_ProductoConSaldo item) {
    if (item.saldoCantidad == null || item.saldoValorizado == null) {
      return 'Sin movimientos todavía';
    }
    final monto = formatoConMiles(redondearBancario(item.saldoValorizado!, 2), 2);
    return 'Saldo: ${item.saldoCantidad} ${item.producto.unidadMedida}  ·  Bs $monto';
  }

  Widget _tarjetaDeProducto(_ProductoConSaldo item) {
    final producto = item.producto;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(producto.nombre),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (producto.numeroTarjeta != null)
                  'Tarjeta Nº ${producto.numeroTarjeta}',
                if (producto.codigo != null) 'Código: ${producto.codigo}',
                'Unidad: ${producto.unidadMedida}',
                producto.metodo.nombreCompleto,
              ].join(' · '),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.hayError)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
                Flexible(
                  child: Text(
                    _textoDeSaldo(item),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _crearOEditarProducto(productoAEditar: producto),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmarYBorrar(producto),
            ),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  KardexScreen(ejercicio: widget.ejercicio, producto: producto),
            ),
          );
          // Al volver de la tarjeta, recargamos para que el saldo
          // mostrado refleje cualquier movimiento que se haya
          // agregado, editado o borrado allá.
          _cargarProductos();
        },
      ),
    );
  }
}

/// Diálogo con una casilla de verificación por producto, para que
/// el usuario elija cuáles tarjetas kardex quiere incluir en el PDF.
class _DialogoSeleccionarProductos extends StatefulWidget {
  final List<Producto> productos;

  const _DialogoSeleccionarProductos({required this.productos});

  @override
  State<_DialogoSeleccionarProductos> createState() =>
      _DialogoSeleccionarProductosState();
}

class _DialogoSeleccionarProductosState
    extends State<_DialogoSeleccionarProductos> {
  // Empezamos con TODOS marcados, ya que lo más común es que el
  // usuario quiera el reporte completo y solo excluya alguno.
  late Set<String> _idsSeleccionados;

  @override
  void initState() {
    super.initState();
    _idsSeleccionados = widget.productos.map((p) => p.id!).toSet();
  }

  bool get _estanTodosMarcados =>
      _idsSeleccionados.length == widget.productos.length;

  void _alternarTodos() {
    setState(() {
      if (_estanTodosMarcados) {
        _idsSeleccionados.clear();
      } else {
        _idsSeleccionados = widget.productos.map((p) => p.id!).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Qué tarjetas quieres exportar?'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              value: _estanTodosMarcados,
              title: Text(
                _estanTodosMarcados
                    ? 'Quitar todos'
                    : 'Seleccionar todos',
              ),
              onChanged: (_) => _alternarTodos(),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.productos.length,
                itemBuilder: (context, index) {
                  final producto = widget.productos[index];
                  final marcado = _idsSeleccionados.contains(producto.id);
                  return CheckboxListTile(
                    value: marcado,
                    title: Text(producto.nombre),
                    subtitle: Text(producto.metodo.nombreCompleto),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (nuevoValor) {
                      setState(() {
                        if (nuevoValor == true) {
                          _idsSeleccionados.add(producto.id!);
                        } else {
                          _idsSeleccionados.remove(producto.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _idsSeleccionados.isEmpty
              ? null
              : () {
                  final seleccionados = widget.productos
                      .where((p) => _idsSeleccionados.contains(p.id))
                      .toList();
                  Navigator.pop(context, seleccionados);
                },
          child: Text('Exportar (${_idsSeleccionados.length})'),
        ),
      ],
    );
  }
}