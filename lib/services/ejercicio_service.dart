// lib/services/ejercicio_service.dart
//
// Este archivo centraliza TODA la comunicación con la tabla
// "ejercicios" de Supabase. Las pantallas van a llamar a estas
// funciones en vez de hablar directo con Supabase.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ejercicio.dart';

class EjercicioService {
  // Referencia al cliente de Supabase (la misma conexión que
  // inicializamos en main.dart).
  final SupabaseClient _client = Supabase.instance.client;

  /// LEER: obtiene todos los ejercicios guardados, ordenados por
  /// fecha de creación (el más reciente primero).
  Future<List<Ejercicio>> obtenerEjercicios() async {
    final data = await _client
        .from('ejercicios')
        .select()
        .order('fecha_creacion', ascending: false);

    // "data" es una lista de Maps (filas crudas de la base de datos).
    // La convertimos a una lista de objetos Ejercicio de Dart.
    return data.map((fila) => Ejercicio.fromMap(fila)).toList();
  }

  /// CREAR: guarda un nuevo ejercicio en la base de datos.
  Future<void> crearEjercicio(Ejercicio ejercicio) async {
    await _client.from('ejercicios').insert(ejercicio.toMap());
  }

  /// ACTUALIZAR: modifica un ejercicio ya existente (lo identifica
  /// por su "id").
  Future<void> actualizarEjercicio(Ejercicio ejercicio) async {
    if (ejercicio.id == null) {
      throw Exception('No se puede actualizar un ejercicio sin id');
    }
    await _client
        .from('ejercicios')
        .update(ejercicio.toMap())
        .eq('id', ejercicio.id as Object);
  }

  /// BORRAR: elimina un ejercicio por su id.
  ///
  /// Recuerda: como configuramos "on delete cascade" en la tabla
  /// movimientos_inventario, al borrar un ejercicio se borran
  /// automáticamente todos sus movimientos asociados.
  Future<void> borrarEjercicio(String id) async {
    await _client.from('ejercicios').delete().eq('id', id);
  }
}