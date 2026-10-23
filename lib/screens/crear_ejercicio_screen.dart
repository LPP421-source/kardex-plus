// lib/screens/crear_ejercicio_screen.dart
//
// Formulario para crear un nuevo ejercicio: nombre, descripción
// opcional, y método de valuación (PEPS, UEPS o CPP).

import 'package:flutter/material.dart';
import '../config/app_settings.dart';
import '../models/ejercicio.dart';
import '../services/ejercicio_service.dart';

class CrearEjercicioScreen extends StatefulWidget {
  // Si "ejercicioAEditar" viene con un valor, la pantalla entra en
  // modo "edición" en vez de "creación".
  final Ejercicio? ejercicioAEditar;

  const CrearEjercicioScreen({super.key, this.ejercicioAEditar});

  @override
  State<CrearEjercicioScreen> createState() => _CrearEjercicioScreenState();
}

class _CrearEjercicioScreenState extends State<CrearEjercicioScreen> {
  // "GlobalKey" nos permite validar el formulario completo de un
  // solo golpe (revisa todos los campos a la vez).
  final _formKey = GlobalKey<FormState>();

  final _service = EjercicioService();

  // Controladores: guardan y leen lo que el usuario escribe.
  final _nombreController = TextEditingController();
  final _empresaController = TextEditingController();
  final _descripcionController = TextEditingController();

  // Valor seleccionado en el dropdown. Empieza en PEPS por defecto.
  MetodoValuacion _metodoSeleccionado = MetodoValuacion.peps;

  // Decimales para la columna "Costo Unitario" de este ejercicio.
  late int _decimalesSeleccionados;

  bool _guardando = false;

  // Forma corta de saber en qué modo estamos, la usamos varias
  // veces más abajo (en el título y en el texto del botón).
  bool get _esEdicion => widget.ejercicioAEditar != null;

  @override
  void initState() {
    super.initState();
    // Si nos pasaron un ejercicio para editar, precargamos sus
    // datos en los campos del formulario.
    final ejercicio = widget.ejercicioAEditar;
    if (ejercicio != null) {
      _nombreController.text = ejercicio.nombre;
      _empresaController.text = ejercicio.empresa ?? '';
      _descripcionController.text = ejercicio.descripcion ?? '';
      _metodoSeleccionado = ejercicio.metodo;
      _decimalesSeleccionados = ejercicio.decimalesCosto;
    } else {
      // Ejercicio nuevo: sugerimos el valor global de Configuraciones,
      // pero el usuario lo puede cambiar solo para este ejercicio.
      _decimalesSeleccionados = AppSettings.decimalesCosto.value;
    }
  }

  @override
  void dispose() {
    // Buena práctica: liberar los controladores cuando la pantalla
    // se cierra, para no dejar cosas ocupando memoria de más.
    _nombreController.dispose();
    _empresaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _guardarEjercicio() async {
    // Si el formulario no pasa las validaciones (ej: nombre vacío),
    // no seguimos.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _guardando = true);

    final ejercicio = Ejercicio(
      // Si estamos editando, mantenemos el mismo id y la fecha de
      // creación original. Si estamos creando, ambos quedan en su
      // valor por defecto (null / ahora).
      id: widget.ejercicioAEditar?.id,
      fechaCreacion: widget.ejercicioAEditar?.fechaCreacion,
      nombre: _nombreController.text.trim(),
      empresa: _empresaController.text.trim().isEmpty
          ? null
          : _empresaController.text.trim(),
      descripcion: _descripcionController.text.trim().isEmpty
          ? null
          : _descripcionController.text.trim(),
      metodo: _metodoSeleccionado,
      decimalesCosto: _decimalesSeleccionados,
    );

    try {
      if (_esEdicion) {
        await _service.actualizarEjercicio(ejercicio);
      } else {
        await _service.crearEjercicio(ejercicio);
      }
      if (mounted) {
        // "true" le avisa a la pantalla anterior que hubo un
        // cambio, para que sepa que debe refrescar su lista.
        Navigator.pop(context, true);
      }
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
        title: Text(_esEdicion ? 'Editar Ejercicio' : 'Nuevo Ejercicio'),
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
                  labelText: 'Nombre del ejercicio',
                  hintText: 'Ej: Ejercicio 1',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null; // null = sin error
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _empresaController,
                decoration: const InputDecoration(
                  labelText: 'Empresa (opcional)',
                  hintText: 'Ej: Distribuidora Santa Cruz S.A.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Contexto del caso práctico',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
              const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                initialValue: _decimalesSeleccionados,
                decoration: const InputDecoration(
                  labelText: 'Decimales del Costo Unitario',
                  helperText:
                      'Solo afecta la columna "Costo Unitario". Los '
                      'montos totales siempre usan 2 decimales.',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(11, (n) => n)
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (nuevoValor) {
                  if (nuevoValor != null) {
                    setState(() => _decimalesSeleccionados = nuevoValor);
                  }
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _guardarEjercicio,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_esEdicion ? 'Actualizar Ejercicio' : 'Guardar Ejercicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}