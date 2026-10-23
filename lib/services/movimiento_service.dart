// lib/services/movimiento_service.dart
//
// Centraliza la comunicación con la tabla "movimientos_inventario"
// de Supabase. Cada movimiento pertenece a un ejercicio específico.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/movimiento_inventario.dart';

class MovimientoService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Obtiene todos los movimientos de UN producto en particular,
  /// ordenados por fecha (del más antiguo al más reciente, que es
  /// el orden que necesita el kardex para calcular bien).
  Future<List<MovimientoInventario>> obtenerMovimientos(
    String productoId,
  ) async {
    final data = await _client
        .from('movimientos_inventario')
        .select()
        .eq('producto_id', productoId)
        .order('fecha', ascending: true);

    return data.map((fila) => MovimientoInventario.fromMap(fila)).toList();
  }

  /// Guarda un nuevo movimiento (compra o venta).
  Future<void> crearMovimiento(MovimientoInventario movimiento) async {
    await _client.from('movimientos_inventario').insert(movimiento.toMap());
  }

  /// Actualiza un movimiento ya existente (lo identifica por su "id").
  Future<void> actualizarMovimiento(MovimientoInventario movimiento) async {
    if (movimiento.id == null) {
      throw Exception('No se puede actualizar un movimiento sin id');
    }
    await _client
        .from('movimientos_inventario')
        .update(movimiento.toMap())
        .eq('id', movimiento.id as Object);
  }

  /// Borra un movimiento por su id.
  Future<void> borrarMovimiento(String id) async {
    await _client.from('movimientos_inventario').delete().eq('id', id);
  }
}