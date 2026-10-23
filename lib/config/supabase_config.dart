// lib/config/supabase_config.dart
//
// Este archivo centraliza las credenciales de conexión a Supabase.
// Las tenemos en un solo lugar para no repetirlas por todo el código.
//
// NOTA DE SEGURIDAD: la "publishable key" está diseñada para ser
// usada del lado del cliente (tu app), así que no hay problema en
// que esté en el código. NUNCA pongas aquí la "service_role key"
// (esa sí es secreta y solo se usa en servidores).

class SupabaseConfig {
  static const String url = 'https://wwhrdcmemeyopwimbjpi.supabase.co';

  static const String publishableKey =
      'sb_publishable_TRXHGJRJC5eeIrvX0FIvTQ_Q_lvUr-6';
}