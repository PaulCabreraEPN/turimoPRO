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
                  'usuario':
                      user?.email ?? 'Anónimo', // O usa 'user_id': user?.id
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sitios turísticos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getSitios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay sitios disponibles.'));
          }
          final sitios = snapshot.data!;
          return ListView.builder(
            itemCount: sitios.length,
            itemBuilder: (context, index) {
              final sitio = sitios[index];
              final imagenes = sitio['imagenes'] as List<dynamic>? ?? [];
              final ubicacionUrl = sitio['ubicacion_url'] as String?;
              final sitioId = sitio['id'] as int;
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sitio['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(sitio['resena'] ?? ''),
                      const SizedBox(height: 8),
                      if (imagenes.isNotEmpty)
                        SizedBox(
                          height: 180,
                          child: PageView.builder(
                            itemCount: imagenes.length,
                            controller: PageController(viewportFraction: 0.8),
                            itemBuilder: (context, imgIdx) {
                              final url = getImageUrl(imagenes[imgIdx]);
                              return GestureDetector(
                                onTap: () => _showImageDialog(url),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.broken_image,
                                                size: 60,
                                                color: Colors.grey,
                                              ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        const Text(
                          'Sin imágenes',
                          style: TextStyle(color: Colors.grey),
                        ),
                      const SizedBox(height: 8),
                      if (ubicacionUrl != null && ubicacionUrl.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(ubicacionUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            icon: const Icon(Icons.map),
                            label: const Text('Ver en el mapa'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _agregarResena(sitioId),
                        icon: const Icon(Icons.rate_review),
                        label: const Text('Agregar reseña'),
                      ),
                      const SizedBox(height: 8),
                      // Mostrar reseñas
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _resenasStream(sitioId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.0,
                                  ),
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
