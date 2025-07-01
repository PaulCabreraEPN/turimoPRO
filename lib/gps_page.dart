/*import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ubicación Actual',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Ubicación Actual'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _locationText;
  String? _geoUrl;
  String? _webUrl;

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verifica si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationText = 'El servicio de ubicación está deshabilitado.';
        _geoUrl = null;
        _webUrl = null;
      });
      return;
    }

    // Verifica permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationText = 'Permiso de ubicación denegado.';
          _geoUrl = null;
          _webUrl = null;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationText = 'Permiso de ubicación denegado permanentemente.';
        _geoUrl = null;
        _webUrl = null;
      });
      return;
    }

    // Obtiene la ubicación
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _locationText =
          'Latitud: ${position.latitude}, Longitud: ${position.longitude}';
      _geoUrl =
          'geo:${position.latitude},${position.longitude}?q=${position.latitude},${position.longitude}';
      _webUrl =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    });
  }

  Future<void> _openMaps() async {
    if (_geoUrl != null) {
      final geoUri = Uri.parse(_geoUrl!);
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // Si no puede abrir con geo:, intenta con la URL web
    if (_webUrl != null) {
      final webUri = Uri.parse(_webUrl!);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _getLocation,
              child: const Text('Obtener ubicación actual'),
            ),
            const SizedBox(height: 20),
            if (_locationText != null) Text(_locationText!),
            if (_geoUrl != null || _webUrl != null)
              TextButton(
                onPressed: _openMaps,
                child: const Text('Abrir en Google Maps'),
              ),
          ],
        ),
      ),
    );
  }
}
*/