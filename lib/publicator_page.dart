import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicatorPage extends StatefulWidget {
  const PublicatorPage({super.key});

  @override
  State<PublicatorPage> createState() => _PublicatorPageState();
}

class _PublicatorPageState extends State<PublicatorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  List<PlatformFile> _selectedImages = [];
  String? _ubicacionUrl;
  String? _ubicacionTexto;

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedImages = result.files.take(5).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedImages.length} imagen(es) seleccionada(s)'),
        ),
      );
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _ubicacionTexto = 'El servicio de ubicación está deshabilitado.';
        _ubicacionUrl = null;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _ubicacionTexto = 'Permiso de ubicación denegado.';
          _ubicacionUrl = null;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _ubicacionTexto = 'Permiso de ubicación denegado permanentemente.';
        _ubicacionUrl = null;
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _ubicacionTexto =
          'Latitud: ${position.latitude}, Longitud: ${position.longitude}';
      _ubicacionUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ubicación seleccionada correctamente')),
    );
  }

  Future<void> _uploadSite() async {
    final supabase = Supabase.instance.client;
    final siteName = _siteNameController.text.trim();
    final review = _reviewController.text.trim();

    if (siteName.isEmpty || review.isEmpty || _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos y selecciona imágenes'),
        ),
      );
      return;
    }

    try {
      // Subir imágenes
      for (int i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final fileName =
            '${siteName.replaceAll(' ', '_')}${i + 1}.${file.extension}';
        await supabase.storage
            .from('uploads')
            .uploadBinary(fileName, file.bytes!);
      }

      // Guardar información del sitio en la tabla
      final imagenes = List.generate(
        _selectedImages.length,
        (i) =>
            '${siteName.replaceAll(' ', '_')}${i + 1}.${_selectedImages[i].extension}',
      );

      await supabase.from('sitios').insert({
        'nombre': siteName,
        'resena': review,
        'imagenes': imagenes,
        'ubicacion_url': _ubicacionUrl, // Guarda la URL de ubicación
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sitio y fotos subidos exitosamente')),
      );
      setState(() {
        _siteNameController.clear();
        _reviewController.clear();
        _selectedImages = [];
        _ubicacionUrl = null;
        _ubicacionTexto = null;
      });
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir: $e')));
    }
  }

  void _showAddSiteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar nuevo sitio'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Información del sitio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _siteNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del sitio',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reviewController,
                  decoration: const InputDecoration(
                    labelText: 'Reseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.rate_review),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Imágenes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Seleccionar hasta 5 imágenes'),
                ),
                if (_selectedImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${_selectedImages.length} imagen(es) seleccionada(s)',
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Ubicación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _getLocation,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Obtener ubicación actual'),
                ),
                if (_ubicacionTexto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_ubicacionTexto!),
                  ),
                if (_ubicacionUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Ubicación lista para guardar',
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _siteNameController.clear();
                _reviewController.clear();
                _selectedImages = [];
                _ubicacionUrl = null;
                _ubicacionTexto = null;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _uploadSite();
              }
            },
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showResenasDialog(int sitioId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reseñas'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: _getResenas(sitioId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('Sin reseñas aún.');
            }
            final resenas = snapshot.data!;
            return SizedBox(
              width: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: resenas.length,
                itemBuilder: (context, index) {
                  final resena = resenas[index];
                  return ListTile(
                    title: Text(
                      '${resena['usuario'] ?? 'Anónimo'}: ${resena['texto']}',
                    ),
                    subtitle: resena['fecha'] != null
                        ? Text(resena['fecha'].toString())
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _eliminarResena(resena['id'] as int);
                        Navigator.of(context).pop();
                        _showResenasDialog(sitioId); // Refresca el diálogo
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reseña eliminada')),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getResenas(int sitioId) async {
    final response = await Supabase.instance.client
        .from('resenas')
        .select()
        .eq('sitio_id', sitioId)
        .order('fecha', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _eliminarResena(int resenaId) async {
    await Supabase.instance.client.from('resenas').delete().eq('id', resenaId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Publicador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: Supabase.instance.client.from('sitios').select(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay sitios publicados.'));
          }
          final sitios = snapshot.data!;
          return ListView.builder(
            itemCount: sitios.length,
            itemBuilder: (context, index) {
              final sitio = sitios[index];
              final imagenes = sitio['imagenes'] as List<dynamic>? ?? [];
              final ubicacionUrl = sitio['ubicacion_url'] as String?;
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
                              final url = Supabase.instance.client.storage
                                  .from('uploads')
                                  .getPublicUrl(imagenes[imgIdx]);
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: InteractiveViewer(
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
                        onPressed: () => _showResenasDialog(sitio['id'] as int),
                        icon: const Icon(Icons.reviews),
                        label: const Text('Ver reseñas'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSiteDialog,
        tooltip: 'Agregar nuevo sitio',
        child: const Icon(Icons.add),
      ),
    );
  }
}
