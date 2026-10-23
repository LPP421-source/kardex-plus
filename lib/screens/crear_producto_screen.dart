// lib/screens/crear_producto_screen.dart
//
// Formulario para crear (o editar) un producto dentro de un
// ejercicio. Mismo patrón que crear_ejercicio_screen.dart.

import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../models/ejercicio.dart';
import '../models/producto.dart';
import '../services/categoria_service.dart';
import '../services/producto_service.dart';

class CrearProductoScreen extends StatefulWidget {
  final String ejercicioId;
  final Producto? productoAEditar;

  /// Sugerencia para el número de tarjeta, calculada en la pantalla
  /// anterior (ej: "cuántos productos ya tiene este ejercicio + 1").
  final int? numeroTarjetaSugerido;

  /// Método de valuación sugerido por defecto (el del ejercicio),
  /// solo se usa al CREAR un producto nuevo. El usuario lo puede
  /// cambiar libremente, ya que cada producto tiene su propio
  /// método independiente.
  final MetodoValuacion metodoSugerido;

  const CrearProductoScreen({
    super.key,
    required this.ejercicioId,
    this.productoAEditar,
    this.numeroTarjetaSugerido,
    this.metodoSugerido = MetodoValuacion.peps,
  });

  @override
  State<CrearProductoScreen> createState() => _CrearProductoScreenState();
}

// Valor "sentinela" para el ítem especial "+ Nueva categoría..." del
// desplegable — no corresponde a ninguna categoría real.
const _opcionNuevaCategoria = '__nueva_categoria__';

class _CrearProductoScreenState extends State<CrearProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductoService();
  final _categoriaService = CategoriaService();

  final _nombreController = TextEditingController();
  final _numeroTarjetaController = TextEditingController();
  final _codigoController = TextEditingController();
  final _unidadMedidaController = TextEditingController();
  final _descripcionController = TextEditingController();

  late MetodoValuacion _metodoSeleccionado;
  String? _categoriaSeleccionadaId;
  List<Categoria> _categorias = [];
  bool _cargandoCategorias = true;

  bool _guardando = false;
  bool get _esEdicion => widget.productoAEditar != null;

  @override
  void initState() {
    super.initState();
    final producto = widget.productoAEditar;
    if (producto != null) {
      _nombreController.text = producto.nombre;
      _numeroTarjetaController.text = producto.numeroTarjeta ?? '';
      _codigoController.text = producto.codigo ?? '';
      _unidadMedidaController.text = producto.unidadMedida;
      _descripcionController.text = producto.descripcion ?? '';
      _metodoSeleccionado = producto.metodo;
      _categoriaSeleccionadaId = producto.categoriaId;
    } else {
      _metodoSeleccionado = widget.metodoSugerido;
      if (widget.numeroTarjetaSugerido != null) {
        // Al crear uno nuevo, sugerimos el siguiente número
        // disponible, pero el usuario lo puede cambiar libremente.
        _numeroTarjetaController.text = widget.numeroTarjetaSugerido!
            .toString()
            .padLeft(2, '0');
      }
      _unidadMedidaController.text = 'unidades';
    }
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final categorias = await _categoriaService.obtenerCategorias(
      widget.ejercicioId,
    );
    if (mounted) {
      setState(() {
        _categorias = categorias;
        _cargandoCategorias = false;
      });
    }
  }

  /// Abre un diálogo chiquito para escribir el nombre de una
  /// categoría nueva, la crea en Supabase, y la deja seleccionada.
  Future<void> _crearNuevaCategoria() async {
    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            hintText: 'Ej: Insumos, Material de limpieza',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (nombre == null || nombre.isEmpty) return;

    final nuevaCategoria = await _categoriaService.crearCategoria(
      Categoria(ejercicioId: widget.ejercicioId, nombre: nombre),
    );

    if (mounted) {
      setState(() {
        _categorias = [..._categorias, nuevaCategoria];
        _categoriaSeleccionadaId = nuevaCategoria.id;
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _numeroTarjetaController.dispose();
    _codigoController.dispose();
    _unidadMedidaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  /// Genera un código automático a partir del nombre (iniciales) y
  /// el número de tarjeta, ej: "Chompas talla L" + tarjeta "01" →
  /// "CH-01". El usuario puede editarlo después si no le gusta.
  void _generarCodigoAutomatico() {
    final palabras = _nombreController.text.trim().split(RegExp(r'\s+'));
    final iniciales = palabras
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    final numero = _numeroTarjetaController.text.trim().isNotEmpty
        ? _numeroTarjetaController.text.trim()
        : '01';

    setState(() {
      _codigoController.text = iniciales.isEmpty
          ? 'PRD-$numero'
          : '$iniciales-$numero';
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final producto = Producto(
      id: widget.productoAEditar?.id,
      ejercicioId: widget.ejercicioId,
      fechaCreacion: widget.productoAEditar?.fechaCreacion,
      nombre: _nombreController.text.trim(),
      numeroTarjeta: _numeroTarjetaController.text.trim().isEmpty
          ? null
          : _numeroTarjetaController.text.trim(),
      codigo: _codigoController.text.trim().isEmpty
          ? null
          : _codigoController.text.trim(),
      unidadMedida: _unidadMedidaController.text.trim(),
      metodo: _metodoSeleccionado,
      categoriaId: _categoriaSeleccionadaId,
      descripcion: _descripcionController.text.trim().isEmpty
          ? null
          : _descripcionController.text.trim(),
    );

    try {
      if (_esEdicion) {
        await _service.actualizarProducto(producto);
      } else {
        await _service.crearProducto(producto);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Producto' : 'Nuevo Producto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  hintText: 'Ej: Chompas talla L',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Categoría: opcional. Incluye una opción especial al
              // final para crear una categoría nueva sin salir de
              // este formulario.
              DropdownButtonFormField<String?>(
                // La "key" hace que el desplegable se reconstruya
                // cuando cambia la categoría seleccionada o la lista
                // (necesario porque "initialValue" solo se lee una vez).
                key: ValueKey('${_categoriaSeleccionadaId}_${_categorias.length}'),
                initialValue: _categoriaSeleccionadaId,
                decoration: InputDecoration(
                  labelText: 'Categoría (opcional)',
                  border: const OutlineInputBorder(),
                  helperText: _cargandoCategorias
                      ? 'Cargando categorías...'
                      : null,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin categoría'),
                  ),
                  ..._categorias.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.nombre),
                    ),
                  ),
                  const DropdownMenuItem<String?>(
                    value: _opcionNuevaCategoria,
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18),
                        SizedBox(width: 8),
                        Text('Nueva categoría...'),
                      ],
                    ),
                  ),
                ],
                onChanged: (nuevoValor) {
                  if (nuevoValor == _opcionNuevaCategoria) {
                    _crearNuevaCategoria();
                  } else {
                    setState(() => _categoriaSeleccionadaId = nuevoValor);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MetodoValuacion>(
                initialValue: _metodoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Método de valuación',
                  border: OutlineInputBorder(),
                ),
                items: MetodoValuacion.values.map((metodo) {
                  return DropdownMenuItem(
                    value: metodo,
                    child: Text(metodo.nombreCompleto),
                  );
                }).toList(),
                onChanged: (nuevoValor) {
                  if (nuevoValor != null) {
                    setState(() => _metodoSeleccionado = nuevoValor);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numeroTarjetaController,
                decoration: const InputDecoration(
                  labelText: 'Nº de Tarjeta',
                  hintText: 'Ej: 01',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unidadMedidaController,
                decoration: const InputDecoration(
                  labelText: 'Unidad de medida',
                  hintText: 'Ej: unidades, kg, litros, cajas',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'La unidad de medida es obligatoria';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codigoController,
                      decoration: const InputDecoration(
                        labelText: 'Código (opcional)',
                        hintText: 'Ej: CH-01',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _generarCodigoAutomatico,
                    icon: const Icon(Icons.auto_fix_high),
                    tooltip: 'Generar código automáticamente',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_esEdicion ? 'Actualizar Producto' : 'Guardar Producto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}