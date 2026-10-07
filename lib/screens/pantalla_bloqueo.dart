import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/bloqueo_service.dart';
import '../tema.dart';

/// Capa opaca de BloqueoService (BloqueoPantalla del escritorio). Tiene su propio Overlay
/// porque se dibuja por encima del Navigator de la app.
class PantallaBloqueo extends StatelessWidget {
  const PantallaBloqueo({super.key});

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [OverlayEntry(builder: (_) => const _Contenido())]);
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido();
  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  final _password = TextEditingController();
  final _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    // autofocus no alcanza: la capa aparece sobre la app ya dibujada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _foco.requestFocus();
    });
  }

  @override
  void dispose() {
    _foco.dispose();
    _password.dispose();
    super.dispose();
  }
  bool _verificando = false;
  bool _ver = false;
  bool _confirmandoSalida = false;
  String? _error;

  Future<void> _desbloquear() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Ingresá tu contraseña');
      return;
    }
    setState(() {
      _verificando = true;
      _error = null;
    });
    final bloqueo = context.read<BloqueoService>();
    final auth = context.read<AuthService>();
    final r = await bloqueo.desbloquear(_password.text);
    if (!mounted) return;
    if (r.cerrarSesion) {
      bloqueo.detener();
      auth.cerrarSesion(motivo: r.error);
      return;
    }
    setState(() {
      _verificando = false;
      _error = r.error;
      if (r.error != null) _password.clear();
    });
  }

  // Confirmación dentro de la misma tarjeta: un diálogo normal quedaría debajo de esta capa.
  void _cerrarSesion() {
    context.read<BloqueoService>().detener();
    context.read<AuthService>().cerrarSesion();
  }

  Widget _confirmacionSalida() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Tema.ambar, size: 40),
          const SizedBox(height: 10),
          const Text('¿Cerrar la sesión?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Lo que estaba abierto y no se guardó (una atención o una entrada de seguimiento a medio escribir) se pierde.',
              textAlign: TextAlign.center, style: TextStyle(color: Tema.textoSecundario(context))),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tema.peligro),
              onPressed: _cerrarSesion,
              child: const Text('Cerrar sesión'),
            ),
          ),
          TextButton(onPressed: () => setState(() => _confirmandoSalida = false), child: const Text('Volver')),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final oscuro = Tema.esOscuro(context);
    return Material(
      child: Container(
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
                constraints: const BoxConstraints(maxWidth: 380),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: _confirmandoSalida ? _confirmacionSalida() : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.lock_outline, size: 30, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 12),
                        const Text('Sesión bloqueada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${auth.nombre ?? ''} · ${auth.etiquetaRol()}',
                            textAlign: TextAlign.center, style: TextStyle(color: Tema.textoSecundario(context))),
                        const SizedBox(height: 6),
                        Text('Lo que estabas haciendo sigue abierto.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Tema.textoSecundario(context), fontSize: 13)),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _password,
                          focusNode: _foco,
                          obscureText: !_ver,
                          autofocus: true,
                          enabled: !_verificando,
                          onSubmitted: (_) => _desbloquear(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.key_outlined),
                            errorText: _error,
                            errorMaxLines: 3,
                            suffixIcon: IconButton(
                              tooltip: _ver ? 'Ocultar' : 'Mostrar',
                              icon: Icon(_ver ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setState(() => _ver = !_ver),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _verificando ? null : _desbloquear,
                            icon: _verificando
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.lock_open),
                            label: const Text('Desbloquear'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(onPressed: _verificando ? null : () => setState(() => _confirmandoSalida = true), child: const Text('Cerrar sesión / otro usuario')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
