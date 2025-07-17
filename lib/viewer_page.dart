import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  final supabase = Supabase.instance.client;

  Future<void> _logout(BuildContext context) async {
    await supabase.auth.signOut();
  }

  Future<List<Map<String, dynamic>>> _getSitios() async {
    final response = await supabase.from('sitios').select();
    return List<Map<String, dynamic>>.from(response);
  }

  String getImageUrl(String fileName) {
    return supabase.storage.from('uploads').getPublicUrl(fileName);
  }

  Future<void> _agregarResena(int sitioId) async {
    final TextEditingController resenaController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar reseña'),
        content: TextField(
          controller: resenaController,
          decoration: const InputDecoration(labelText: 'Escribe tu reseña'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final texto = resenaController.text.trim();
              if (texto.isNotEmpty) {
                final user = supabase.auth.currentUser;
                await supabase.from('resenas').insert({
                  'sitio_id': sitioId,
                  'texto': texto,
                  'fecha': DateTime.now().toIso8601String(),
                  'usuario': user?.email ?? 'Anónimo',
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reseña agregada')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getResenas(int sitioId) async {
    final response = await supabase
        .from('resenas')
        .select()
        .eq('sitio_id', sitioId)
        .order('fecha', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> _resenasStream(int sitioId) {
    return supabase
        .from('resenas')
        .stream(primaryKey: ['id'])
        .eq('sitio_id', sitioId)
        .order('fecha', ascending: false)
        .map((response) => List<Map<String, dynamic>>.from(response));
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Paleta de colores igual a publicator_page.dart
    final Color azulPrincipal = const Color(0xFF1756A9);
    final Color azulClaro = const Color(0xFF4FC3F7);
    final Color verde = const Color(0xFF388E3C);
    final Color amarillo = const Color(0xFFFFC107);
    final Color fondoTarjeta = const Color(0xFFF7FAFC);
    final Color blanco = Colors.white;
    final Color grisClaro = const Color(0xFFE3E9F0);

    return Scaffold(
      backgroundColor: grisClaro,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: azulPrincipal,
            boxShadow: [
              BoxShadow(
                color: azulPrincipal.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.travel_explore, color: amarillo, size: 32),
                  const SizedBox(width: 10),
                  Text(
                    'Perfil Visitante',
                    style: TextStyle(
                      color: blanco,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.logout, color: blanco, size: 28),
                    tooltip: 'Cerrar sesión',
                    onPressed: () => _logout(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getSitios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No hay sitios disponibles.',
                style: TextStyle(color: azulPrincipal, fontSize: 18),
              ),
            );
          }
          final sitios = snapshot.data!;
          return ListView.builder(
            itemCount: sitios.length,
            itemBuilder: (context, index) {
              final sitio = sitios[index];
              final imagenes = sitio['imagenes'] as List<dynamic>? ?? [];
              final ubicacionUrl = sitio['ubicacion_url'] as String?;
              final sitioId = sitio['id'] as int;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: fondoTarjeta,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: azulPrincipal.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título con amarillo y azul
                      Row(
                        children: [
                          Icon(Icons.location_on, color: amarillo, size: 26),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sitio['nombre'] ?? 'Sin nombre',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: azulPrincipal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Reseña sin icono, con azul oscuro
                      Text(
                        sitio['resena'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Galería de imágenes
                      if (imagenes.isNotEmpty)
                        SizedBox(
                          height: 180,
                          child: PageView.builder(
                            itemCount: imagenes.length,
                            controller: PageController(viewportFraction: 0.8),
                            itemBuilder: (context, imgIdx) {
                              final url = getImageUrl(imagenes[imgIdx]);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: GestureDetector(
                                    onTap: () => _showImageDialog(url),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(Icons.broken_image, size: 60, color: Colors.grey[400]),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.image_not_supported, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            const Text(
                              'Sin imágenes',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      // Botones de acción, uno debajo del otro
                      if (ubicacionUrl != null && ubicacionUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: verde,
                              foregroundColor: blanco,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final uri = Uri.parse(ubicacionUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(Icons.map, size: 22),
                            label: const Text('Ver en el mapa'),
                          ),
                        ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulPrincipal,
                          foregroundColor: blanco,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _agregarResena(sitioId),
                        icon: const Icon(Icons.rate_review, size: 22),
                        label: const Text('Agregar reseña'),
                      ),
                      const SizedBox(height: 14),
                      // Mostrar reseñas
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _resenasStream(sitioId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('Cargando reseñas...');
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Text('Sin reseñas aún.');
                          }
                          final resenas = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reseñas:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              ...resenas.map(
                                (resena) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Text(
                                    '${resena['usuario'] ?? 'Anónimo'}: ${resena['texto']}',
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
