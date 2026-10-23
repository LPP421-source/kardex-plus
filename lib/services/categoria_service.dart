// lib/services/categoria_service.dart
//
// Centraliza la comunicación con la tabla "categorias" de Supabase.
// Cada categoría pertenece a un ejercicio.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/categoria.dart';

class CategoriaService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Obtiene todas las categorías de UN ejercicio, en el orden en
  /// que se crearon (para que el orden no "salte" cada vez que se
  /// recarga la pantalla).
  Future<List<Categoria>> obtenerCategorias(String ejercicioId) async {
    final data = await _client
        .from('categorias')
        .select()
        .eq('ejercicio_id', ejercicioId)
        .order('fecha_creacion', ascending: true);

    return data.map((fila) => Categoria.fromMap(fila)).toList();
  }

  Future<Categoria> crearCategoria(Categoria categoria) async {
    final fila = await _client
        .from('categorias')
        .insert(categoria.toMap())
        .select()
        .single();
    return Categoria.fromMap(fila);
  }

  Future<void> actualizarCategoria(Categoria categoria) async {
    if (categoria.id == null) {
      throw Exception('No se puede actualizar una categoría sin id');
    }
    await _client
        .from('categorias')
        .update(categoria.toMap())
        .eq('id', categoria.id as Object);
  }

  /// Borrar una categoría NO borra los productos que la usaban —
  /// simplemente quedan sin categoría (ver "on delete set null" en
  /// la tabla productos).
  Future<void> borrarCategoria(String id) async {
    await _client.from('categorias').delete().eq('id', id);
  }
}