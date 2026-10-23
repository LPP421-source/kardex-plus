// lib/services/producto_service.dart
//
// Centraliza la comunicación con la tabla "productos" de Supabase.
// Cada producto pertenece a un ejercicio.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/producto.dart';

class ProductoService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Obtiene todos los productos de UN ejercicio.
  Future<List<Producto>> obtenerProductos(String ejercicioId) async {
    final data = await _client
        .from('productos')
        .select()
        .eq('ejercicio_id', ejercicioId)
        .order('fecha_creacion', ascending: false);

    return data.map((fila) => Producto.fromMap(fila)).toList();
  }

  Future<void> crearProducto(Producto producto) async {
    await _client.from('productos').insert(producto.toMap());
  }

  Future<void> actualizarProducto(Producto producto) async {
    if (producto.id == null) {
      throw Exception('No se puede actualizar un producto sin id');
    }
    await _client
        .from('productos')
        .update(producto.toMap())
        .eq('id', producto.id as Object);
  }

  /// Borrar un producto también borra en cascada todos sus
  /// movimientos (por el "on delete cascade" que configuramos).
  Future<void> borrarProducto(String id) async {
    await _client.from('productos').delete().eq('id', id);
  }
}