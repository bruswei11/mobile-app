import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../tema.dart';

/// Login del escritorio: marca del Departamento arriba (degradé), usuario y contraseña. Los
/// mensajes de error (incluido el bloqueo tras 5 intentos) vienen armados del servidor. No hay
/// registro libre: las cuentas nuevas las crea josechavez desde Configuración → Usuarios.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _focoPassword = FocusNode();
  bool _cargando = false;
  bool _ver = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = context.read<AuthService>().motivoCierre;
  }

  Future<void> _entrar() async {
    if (_usuarioCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Completá usuario y contraseña');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    final error = await context.read<AuthService>().login(_usuarioCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = error;
      if (error != null) _passwordCtrl.clear();
    });
  }

  Future<void> _configurarServidor() async {
    final ctrl = TextEditingController(text: ApiClient.instancia.baseUrl);
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dirección del servidor'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://192.168.x.x:8080',
            helperText: 'La IP de la computadora del Departamento en la red WiFi, con :8080 al final',
            helperMaxLines: 3,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevo != null && nuevo.isNotEmpty) {
      await ApiClient.instancia.guardarServidor(nuevo);
      if (mounted) Tema.aviso(context, 'Servidor configurado: $nuevo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Tema.esOscuro(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: oscuro ? [const Color(0xFF1B2440), const Color(0xFF231C40)] : [Tema.secundario, Tema.primario],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo_colegio.png', height: 110, filterQuality: FilterQuality.medium),
                    const SizedBox(height: 14),
                    const Text('Departamento de Psicología',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Colegio Nacional E.M.D. San Roque González de Santacruz',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Iniciar sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _usuarioCtrl,
                                enabled: !_cargando,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person_outline)),
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => _focoPassword.requestFocus(),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordCtrl,
                                focusNode: _focoPassword,
                                enabled: !_cargando,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _ver ? 'Ocultar' : 'Mostrar',
                                    icon: Icon(_ver ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                    onPressed: () => setState(() => _ver = !_ver),
                                  ),
                                ),
                                obscureText: !_ver,
                                onSubmitted: (_) => _entrar(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _cargando ? null : _entrar,
                                child: _cargando
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Ingresar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!kIsWeb) // en la web el servidor es la misma página
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: _configurarServidor,
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: const Text('Configurar servidor'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
