import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

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
  final ImagePicker _picker = ImagePicker();

  // Paleta inspirada en la imagen
  final Color azulFondo = const Color(0xFF1976D2);
  final Color azulOscuro = const Color(0xFF0D47A1);
  final Color verde = const Color(0xFF388E3C);
  final Color amarillo = const Color(0xFFFFC107);
  final Color naranja = const Color(0xFFFF9800);
  final Color blanco = Colors.white;

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _checkAndRequestPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final photosStatus = await Permission.photos.status;

    if (!cameraStatus.isGranted || !photosStatus.isGranted) {
      final result = await [
        Permission.camera,
        Permission.photos,
      ].request();
      
      if (result[Permission.camera] != PermissionStatus.granted ||
          result[Permission.photos] != PermissionStatus.granted) {
        throw 'Permisos de cámara y galería no concedidos';
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    try {
      await _checkAndRequestPermissions();
      
      final result = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: blanco,
          title: Text('Seleccionar fuente de imagen', style: TextStyle(color: azulOscuro)),
          content: const Text('¿Cómo deseas agregar las imágenes?'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: Icon(Icons.camera_alt, color: naranja),
              label: const Text('Tomar foto'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              icon: Icon(Icons.photo_library, color: verde),
              label: const Text('Elegir de galería'),
            ),
          ],
        ),
      );

      if (result != null) {
        await _pickImages(result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _pickImages(ImageSource source) async {
    try {
      if (_selectedImages.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya tienes 5 imágenes seleccionadas. No puedes subir más de 5.'),
          ),
        );
        return;
      }

      final List<XFile> pickedFiles = [];

      if (source == ImageSource.gallery) {
        pickedFiles.addAll(await _picker.pickMultiImage(
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 90,
        ));
      } else {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 90,
        );
        if (image != null) {
          pickedFiles.add(image);
        }
      }

      if (pickedFiles.isNotEmpty) {
        final List<PlatformFile> platformFiles = [];
        int espacioDisponible = 5 - _selectedImages.length;
        final nuevasImagenes = pickedFiles.take(espacioDisponible);

        for (final xfile in nuevasImagenes) {
          final file = File(xfile.path);
          final bytes = await file.readAsBytes();

          platformFiles.add(PlatformFile(
            name: xfile.name,
            size: bytes.length,
            bytes: bytes,
            path: xfile.path,
          ));
        }

        setState(() {
          _selectedImages = [..._selectedImages, ...platformFiles];
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedImages.length} imagen(es) seleccionada(s)'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imágenes: $e')),
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
      for (int i = 0; i < _selectedImages.length; i++) {
        final file = _selectedImages[i];
        final fileName =
            '${siteName.replaceAll(' ', '_')}${i + 1}.${file.extension}';
        await supabase.storage
            .from('uploads')
            .uploadBinary(fileName, file.bytes!);
      }

      final imagenes = List.generate(
        _selectedImages.length,
        (i) =>
            '${siteName.replaceAll(' ', '_')}${i + 1}.${_selectedImages[i].extension}',
      );

      await supabase.from('sitios').insert({
        'nombre': siteName,
        'resena': review,
        'imagenes': imagenes,
        'ubicacion_url': _ubicacionUrl,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e')),
      );
    }
  }

  void _showAddSiteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: blanco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.add_location_alt, color: verde),
            const SizedBox(width: 8),
            Text('Agregar nuevo sitio', style: TextStyle(color: azulOscuro)),
          ],
        ),
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
                  decoration: InputDecoration(
                    labelText: 'Nombre del sitio',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.place, color: naranja),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reviewController,
                  decoration: InputDecoration(
                    labelText: 'Reseña',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.rate_review, color: azulOscuro),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulFondo,
                    foregroundColor: blanco,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar foto o seleccionar de galería'),
                ),
                if (_selectedImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      spacing: 8,
                      children: _selectedImages.map((img) {
                        return Chip(
                          label: Text(img.name, style: TextStyle(color: azulOscuro)),
                          backgroundColor: amarillo.withOpacity(0.2),
                          avatar: Icon(Icons.image, color: verde),
                        );
                      }).toList(),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: blanco,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _getLocation,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Obtener ubicación actual'),
                ),
                if (_ubicacionTexto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(_ubicacionTexto!, style: TextStyle(color: azulOscuro)),
                  ),
                if (_ubicacionUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Ubicación lista para guardar',
                      style: TextStyle(color: verde, fontWeight: FontWeight.w600),
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
            child: Text('Cancelar', style: TextStyle(color: azulOscuro)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: naranja,
              foregroundColor: blanco,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
        backgroundColor: blanco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.reviews, color: azulFondo),
            const SizedBox(width: 8),
            Text('Reseñas', style: TextStyle(color: azulOscuro)),
          ],
        ),
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
                  return Card(
                    color: amarillo.withOpacity(0.15),
                    child: ListTile(
                      leading: Icon(Icons.person, color: verde),
                      title: Text(
                        '${resena['usuario'] ?? 'Anónimo'}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: azulOscuro),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${resena['texto']}'),
                          if (resena['fecha'] != null)
                            Text(resena['fecha'].toString(), style: TextStyle(fontSize: 12, color: azulFondo)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _eliminarResena(resena['id'] as int);
                          Navigator.of(context).pop();
                          _showResenasDialog(sitioId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reseña eliminada')),
                          );
                        },
                      ),
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
            child: Text('Cerrar', style: TextStyle(color: azulOscuro)),
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
    // Paleta de colores
    final Color azulPrincipal = const Color(0xFF1756A9); // Azul fuerte
    final Color azulClaro = const Color(0xFF4FC3F7);     // Azul claro
    final Color verde = const Color(0xFF388E3C);         // Verde botón
    final Color amarillo = const Color(0xFFFFC107);      // Amarillo marcador
    final Color fondoTarjeta = const Color(0xFFF7FAFC);  // Fondo tarjeta
    final Color blanco = Colors.white;
    final Color grisClaro = const Color(0xFFE3E9F0);

    return Scaffold(
      backgroundColor: grisClaro,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: azulPrincipal,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
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
                  Icon(Icons.explore, color: amarillo, size: 32),
                  const SizedBox(width: 10),
                  Text(
                    'Perfil Publicador',
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
        future: Supabase.instance.client.from('sitios').select(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No hay sitios publicados.',
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
                              final url = Supabase.instance.client.storage
                                  .from('uploads')
                                  .getPublicUrl(imagenes[imgIdx]);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: GestureDetector(
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
                        onPressed: () => _showResenasDialog(sitio['id'] as int),
                        icon: const Icon(Icons.reviews, size: 22),
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
        backgroundColor: azulPrincipal,
        foregroundColor: blanco,
        onPressed: _showAddSiteDialog,
        tooltip: 'Agregar nuevo sitio',
        child: const Icon(Icons.add),
      ),
    );
  }
}
