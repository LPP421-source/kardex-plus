// lib/screens/lista_ejercicios_screen.dart
//
// Pantalla principal del módulo de ejercicios: muestra todos los
// ejercicios guardados en Supabase, con opción de crear uno nuevo.

import 'package:flutter/material.dart';
import '../models/ejercicio.dart';
import '../services/ejercicio_service.dart';
import 'configuraciones_screen.dart';
import 'crear_ejercicio_screen.dart';
import 'lista_productos_screen.dart';

class ListaEjerciciosScreen extends StatefulWidget {
  const ListaEjerciciosScreen({super.key});

  @override
  State<ListaEjerciciosScreen> createState() => _ListaEjerciciosScreenState();
}

class _ListaEjerciciosScreenState extends State<ListaEjerciciosScreen> {
  final EjercicioService _service = EjercicioService();

  // Guardamos el "Future" (la promesa de datos que llegará más
  // adelante) en una variable, para poder decirle a FutureBuilder
  // que lo escuche, y para poder "refrescarlo" después de crear
  // un ejercicio nuevo.
  late Future<List<Ejercicio>> _futureEjercicios;

  @override
  void initState() {
    super.initState();
    _cargarEjercicios();
  }

  void _cargarEjercicios() {
    setState(() {
      _futureEjercicios = _service.obtenerEjercicios();
    });
  }

  Future<void> _editarEjercicio(Ejercicio ejercicio) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearEjercicioScreen(ejercicioAEditar: ejercicio),
      ),
    );
    if (resultado == true) {
      _cargarEjercicios();
    }
  }

  Future<void> _confirmarYBorrar(Ejercicio ejercicio) async {
    // showDialog muestra una ventana emergente y "espera" a que el
    // usuario elija una opción antes de seguir.
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar ejercicio?'),
        content: Text(
          'Se borrará "${ejercicio.nombre}" y todos sus movimientos. '
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

    // Si el usuario canceló (o cerró el diálogo sin elegir), no
    // hacemos nada.
    if (confirmado != true) return;

    try {
      await _service.borrarEjercicio(ejercicio.id!);
      _cargarEjercicios();
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
        title: const Text('Mis Ejercicios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuraciones',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfiguracionesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Ejercicio>>(
        future: _futureEjercicios,
        builder: (context, snapshot) {
          // Caso 1: todavía está cargando los datos.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Caso 2: algo salió mal (ej: sin internet).
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }

          final ejercicios = snapshot.data ?? [];

          // Caso 3: no hay ejercicios todavía.
          if (ejercicios.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no tienes ejercicios.\nToca el botón + para crear uno.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Caso 4: hay ejercicios, los mostramos en una lista.
          return ListView.builder(
            itemCount: ejercicios.length,
            itemBuilder: (context, index) {
              final ejercicio = ejercicios[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(ejercicio.nombre),
                  subtitle: Text(
                    ejercicio.empresa != null
                        ? '${ejercicio.empresa} · ${ejercicio.metodo.nombreCompleto}'
                        : ejercicio.metodo.nombreCompleto,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editarEjercicio(ejercicio),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _confirmarYBorrar(ejercicio),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ListaProductosScreen(ejercicio: ejercicio),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navegamos a la pantalla de creación y ESPERAMOS a que
          // el usuario vuelva. "resultado" será "true" si guardó
          // un ejercicio nuevo (según definimos en Navigator.pop).
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CrearEjercicioScreen()),
          );

          // Si se creó un ejercicio nuevo, recargamos la lista.
          if (resultado == true) {
            _cargarEjercicios();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}