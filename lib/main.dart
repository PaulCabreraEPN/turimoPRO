import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'upload_page.dart';
import 'publicator_page.dart';
import 'viewer_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://eabrubdlaywkxjsormzd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhYnJ1YmRsYXl3a3hqc29ybXpkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyOTc2MjAsImV4cCI6MjA2Mzg3MzYyMH0.uCp5AozdjUqgnBs9r2IgfXYrqe-BiXex5tr36Qfn55U',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecuador Blog Turistico ',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E88E5), // Azul principal
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          primary: const Color(0xFF1E88E5), // Azul
          secondary: const Color(0xFFFFC107), // Amarillo
          background: const Color(0xFFE3F2FD), // Celeste claro
        ),
        scaffoldBackgroundColor: const Color(0xFFE3F2FD),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          if (session.user!.userMetadata?['role'] == 'Publicador') {
            return const PublicatorPage();
          } else {
            return const ViewerPage();
          }
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  String _selectedRole = 'Visitador'; // Valor por defecto

  Future<void> login() async {
    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text,
        password: passwordController.text,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al iniciar sesión: $e')));
    }
  }

  Future<void> signup() async {
    try {
      await supabase.auth.signUp(
        email: emailController.text,
        password: passwordController.text,
        data: {'role': _selectedRole}, // Guarda el rol seleccionado
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa tu correo para confirmar tu cuenta.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al registrarse: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo turístico
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/ecuador_tourist_blog.png',
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.travel_explore,
                        size: 80,
                        color: Color(0xFF388E3C), // Verde
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'ECUADOR BLOC TURISTICO',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E88E5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Descubre, comparte y explora Ecuador',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.blueGrey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: '¿Cómo deseas ingresar?',
                      prefixIcon: Icon(
                        _selectedRole == 'Publicador'
                            ? Icons.edit_location_alt
                            : Icons.hiking,
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Visitador',
                        child: Row(
                          children: [
                            Icon(Icons.hiking, color: Color(0xFF388E3C)),
                            SizedBox(width: 8),
                            Text('Como Visitador'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Publicador',
                        child: Row(
                          children: [
                            Icon(Icons.edit_location_alt, color: Color(0xFFFFC107)),
                            SizedBox(width: 8),
                            Text('Como Publicador'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1E88E5)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF388E3C)),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: login,
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: const Text('Iniciar sesión'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: signup,
                    icon: const Icon(Icons.person_add_alt_1, color: Color(0xFFFFC107)),
                    label: const Text('Registrarse'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
