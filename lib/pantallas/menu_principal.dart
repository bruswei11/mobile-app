import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/turno.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/borradores.dart';
import '../services/bloqueo_service.dart';
import '../services/navegacion.dart';
import '../tema.dart';
import '../ui/componentes.dart';
import 'busqueda_rapida.dart';
import 'estudiantes/estudiantes_panel.dart';
import 'panel/panel_general.dart';
import 'configuracion/configuracion.dart';

/// MenuPrincipal del escritorio: una sola "ventana" que cambia de sección con un fundido
/// (Tema.cambiarConFundido). El menú tiene la barra de búsqueda (Ctrl+K), la franja "Hoy" y las
/// tres tarjetas Estudiantes / Panel / Configuración. Atajos: Ctrl+K, Ctrl+L, Alt+1..3, Esc.
class MenuPrincipal extends StatefulWidget {
  const MenuPrincipal({super.key});
  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  late final BloqueoService _bloqueo;
  final _foco = FocusNode();

  List<Turno> _hoy = [];
  bool _cargandoHoy = true;
  Timer? _reloj;
  final Set<int> _recordadas = {};
  bool _bienvenida = false;

  @override
  void initState() {
    super.initState();
    context.read<Navegacion>().reiniciar();
    Borradores.limpiarVencidos(); // borradores de más de 24 h se eliminan
    _bloqueo = context.read<BloqueoService>()..iniciar();
    _cargarHoy();
    // Una vez por minuto, como el SwingWorker del escritorio: refresca la franja y recuerda las
    // citas programadas 10 minutos antes.
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) => _cargarHoy());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _bloqueo.detener(notificar: false);
    _foco.dispose();
    super.dispose();
  }

  Future<void> _cargarHoy() async {
    try {
      final data = await ApiClient.instancia.get('/api/turnos', {'fecha': Tema.isoFecha(DateTime.now())});
      if (!mounted) return;
      setState(() {
        _hoy = (data as List).map((e) => Turno.fromJson(e)).toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
        _cargandoHoy = false;
      });
      _avisos();
    } catch (_) {
      if (mounted) setState(() => _cargandoHoy = false);
    }
  }

  void _avisos() {
    final ahora = DateTime.now();
    final pendientes = _hoy.where((t) => t.estado == 'programado').toList();
    if (!_bienvenida) {
      _bienvenida = true;
      final n = pendientes.where((t) => t.fecha.isAfter(ahora)).length;
      final nombre = (context.read<AuthService>().nombre ?? '').split(' ').firstWhere((p) => !p.endsWith('.'), orElse: () => '');
      Tema.aviso(context, 'Hola${nombre.isEmpty ? '' : ', $nombre'}. ${n == 0 ? 'No tenés más citas programadas para hoy.' : 'Tenés $n cita(s) programada(s) para hoy.'}');
    }
    for (final t in pendientes) {
      final faltan = t.fecha.difference(ahora).inMinutes;
      if (faltan >= 0 && faltan <= 10 && _recordadas.add(t.id!)) {
        final cuando = faltan == 0 ? 'ahora' : 'en $faltan min';
        // Con la sesión bloqueada no se muestra el nombre del estudiante.
        Tema.aviso(context, _bloqueo.bloqueado ? 'Tenés una cita $cuando' : 'Cita $cuando con ${t.pacienteNombre ?? 'un estudiante'}');
      }
    }
  }

  void _buscar() => BusquedaRapida.mostrar(context);

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<Navegacion>();
    final atajos = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): _buscar,
      const SingleActivator(LogicalKeyboardKey.keyL, control: true): () => _bloqueo.bloquear(),
      const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => nav.verPestana(PestanaEstudiantes.lista),
      const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => nav.irA(Seccion.panel),
      const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => nav.irA(Seccion.configuracion),
      const SingleActivator(LogicalKeyboardKey.escape): () => nav.escape(),
    };
    final Widget seccion = switch (nav.seccion) {
      Seccion.menu => _menu(),
      Seccion.estudiantes => const EstudiantesPanel(key: ValueKey('estudiantes')),
      Seccion.panel => const PanelGeneral(key: ValueKey('panel')),
      Seccion.configuracion => const Configuracion(key: ValueKey('configuracion')),
    };
    return PopScope(
      // Botón "atrás" del celular: igual que Esc (cerrar lo abierto, volver al menú).
      canPop: nav.seccion == Seccion.menu,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.escape();
      },
      child: CallbackShortcuts(
        bindings: atajos,
        child: Focus(
          focusNode: _foco,
          autofocus: true,
          child: Scaffold(
            backgroundColor: Paleta.de(context).fondo,
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.03, 0), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(nav.seccion), child: seccion),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ menú

  Widget _menu() {
    final auth = context.watch<AuthService>();
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    return Column(
      key: const ValueKey('menu'),
      children: [
        Encabezado(
          titulo: ancho ? 'Departamento de Psicología · Colegio San Roque González' : 'Departamento de Psicología',
          subtitulo: 'Conectado como: ${auth.nombre ?? ''} (${auth.etiquetaRol()})',
          acciones: [
            BotonBlanco(icono: Icons.lock_outline, tooltip: 'Bloquear (Ctrl+L)', onPressed: () => _bloqueo.bloquear()),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarHoy,
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(ancho ? 30 : 12, ancho ? 22 : 12, ancho ? 30 : 12, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - (ancho ? 34 : 24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: _barraBusqueda(p))),
                      SizedBox(height: ancho ? 16 : 12),
                      _franjaHoy(p),
                      SizedBox(height: ancho ? 26 : 14),
                      if (ancho)
                        SizedBox(
                          height: (c.maxHeight - 250).clamp(260.0, 520.0),
                          child: Row(children: [
                            Expanded(child: _tarjetaSeccion(Seccion.estudiantes)),
                            const SizedBox(width: 24),
                            Expanded(child: _tarjetaSeccion(Seccion.panel)),
                            const SizedBox(width: 24),
                            Expanded(child: _tarjetaSeccion(Seccion.configuracion)),
                          ]),
                        )
                      else ...[
                        _tarjetaSeccion(Seccion.estudiantes),
                        const SizedBox(height: 12),
                        _tarjetaSeccion(Seccion.panel),
                        const SizedBox(height: 12),
                        _tarjetaSeccion(Seccion.configuracion),
                      ],
                      if (ancho) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Atajos: Ctrl+K buscar estudiante · Ctrl+L bloquear · Alt+1 Estudiantes · Alt+2 Panel · Alt+3 Configuración · Esc vuelve atrás',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: p.textoSecundario),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _barraBusqueda(Paleta p) {
    return Material(
      color: p.superficie,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _buscar,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: p.borde)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Icon(Icons.search, color: p.textoSecundario),
            const SizedBox(width: 12),
            Expanded(child: Text('Buscar un estudiante…', style: TextStyle(color: p.textoSecundario, fontSize: 15))),
            if (esAncho(context))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(border: Border.all(color: p.borde), borderRadius: BorderRadius.circular(4)),
                child: Text('Ctrl + K', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textoSecundario)),
              ),
          ]),
        ),
      ),
    );
  }

  Turno? get _proxima {
    final ahora = DateTime.now();
    for (final t in _hoy) {
      if (t.estado == 'programado' && t.fecha.add(Duration(minutes: t.duracionMinutos)).isAfter(ahora)) return t;
    }
    return null;
  }

  static String _nombreCorto(String? n) {
    final partes = (n ?? '').split(' ').where((s) => s.isNotEmpty).toList();
    if (partes.isEmpty) return '';
    return partes.length == 1 ? partes.first : '${partes.first} ${partes[1][0]}.';
  }

  Widget _franjaHoy(Paleta p) {
    final ancho = esAncho(context);
    final proxima = _proxima;
    final hoy = DateTime.now();
    String detalle;
    if (_cargandoHoy) {
      detalle = 'Cargando citas…';
    } else if (proxima == null) {
      detalle = _hoy.isEmpty ? 'No hay citas para hoy' : 'No quedan citas programadas';
    } else {
      final faltan = proxima.fecha.difference(hoy).inMinutes;
      final cuando = faltan <= 0 ? 'en curso' : (faltan < 60 ? 'en $faltan min' : 'en ${faltan ~/ 60} h ${faltan % 60} min');
      detalle = 'Próxima: ${proxima.pacienteNombre ?? ''} a las ${Tema.hora(proxima.fecha)} ($cuando)';
    }
    final dia = Tema.fechaLarga(hoy).split(' de ${hoy.year}').first;
    final encabezado = Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Tema.exito.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.calendar_today, color: Tema.exito, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hoy, ${dia[0].toLowerCase()}${dia.substring(1)}  ·  ${_hoy.length} cita${_hoy.length == 1 ? '' : 's'}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: p.texto)),
          const SizedBox(height: 2),
          Text(detalle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
        ]),
      ),
    ]);
    final chips = SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: _hoy.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _chipCita(p, _hoy[i], _hoy[i].id == proxima?.id),
      ),
    );
    final verAgenda = Boton('Ver agenda', icono: Icons.chevron_right,
        onPressed: () => context.read<Navegacion>().verPestana(PestanaEstudiantes.agenda));
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      child: ancho
          ? Row(children: [
              SizedBox(width: 380, child: encabezado),
              const SizedBox(width: 14),
              Expanded(child: _hoy.isEmpty ? const SizedBox() : Align(alignment: Alignment.centerLeft, child: chips)),
              const SizedBox(width: 12),
              verAgenda,
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              encabezado,
              if (_hoy.isNotEmpty) ...[const SizedBox(height: 10), chips],
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: verAgenda),
            ]),
    );
  }

  Widget _chipCita(Paleta p, Turno t, bool esProxima) {
    final color = esProxima ? p.primario : Tema.colorEstado(t.estado);
    final etiqueta = esProxima ? 'PRÓXIMA' : Tema.etiquetaEstado(t.estado).toUpperCase();
    return Material(
      color: esProxima ? p.seleccion : color.withValues(alpha: p.oscuro ? 0.18 : 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: esProxima ? p.primario : p.borde, width: esProxima ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => context.read<Navegacion>().abrirFicha(t.pacienteId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(Tema.hora(t.fecha), style: TextStyle(fontWeight: FontWeight.w800, color: p.texto.withValues(alpha: 0.75))),
                const SizedBox(width: 14),
                Text(etiqueta, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Tema.legible(context, color))),
              ]),
              Text(_nombreCorto(t.pacienteNombre), style: TextStyle(fontSize: 12, color: p.textoSecundario)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaSeccion(Seccion s) {
    final p = Paleta.de(context);
    final ancho = esAncho(context);
    final (String titulo, String detalle, IconData icono, List<Color> colores) = switch (s) {
      Seccion.estudiantes => ('Estudiantes', 'Fichas, atenciones,\nagenda y reportes', Icons.person, [const Color(0xFF3B6BC4), const Color(0xFF2F4F9C)]),
      Seccion.panel => ('Panel', 'Estadísticas del\nDepartamento', Icons.bar_chart_rounded, [const Color(0xFF6C8BE0), const Color(0xFF4460C4)]),
      _ => ('Configuración', 'Cuenta, contraseña,\npreferencias y actividad', Icons.settings, [const Color(0xFF6B7385), const Color(0xFF4B5263)]),
    };
    final atajo = switch (s) { Seccion.estudiantes => 'Alt+1', Seccion.panel => 'Alt+2', _ => 'Alt+3' };
    final iconoCaja = Container(
      width: ancho ? 84 : 56,
      height: ancho ? 84 : 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colores),
        borderRadius: BorderRadius.circular(ancho ? 12 : 10),
        boxShadow: [BoxShadow(color: colores.last.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(icono, color: Colors.white, size: ancho ? 44 : 30),
    );
    return Tooltip(
      message: '$titulo ($atajo)',
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: p.superficie,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => s == Seccion.estudiantes
              ? context.read<Navegacion>().verPestana(PestanaEstudiantes.lista)
              : context.read<Navegacion>().irA(s),
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colores.first, width: 5)),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.all(ancho ? 20 : 14),
            child: ancho
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    iconoCaja,
                    const SizedBox(height: 40),
                    Text(titulo, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.texto)),
                    const SizedBox(height: 18),
                    Text(detalle, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: p.textoSecundario, height: 1.4)),
                  ])
                : Row(children: [
                    iconoCaja,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(titulo, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.texto)),
                        const SizedBox(height: 3),
                        Text(detalle.replaceAll('\n', ' '), style: TextStyle(fontSize: 13.5, color: p.textoSecundario)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: p.textoSecundario),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior con "Volver al menú", como en cada sección del escritorio.
class PieVolver extends StatelessWidget {
  final String texto;
  final VoidCallback onVolver;
  final List<Widget> otros;
  const PieVolver({super.key, this.texto = 'Volver al menú', required this.onVolver, this.otros = const []});

  @override
  Widget build(BuildContext context) {
    if (!esAncho(context)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        ...otros,
        if (otros.isNotEmpty) const SizedBox(width: 12),
        Boton(texto, icono: Icons.arrow_back, onPressed: onVolver, tooltip: 'Esc'),
      ]),
    );
  }
}

/// Flecha "atrás" blanca para el encabezado en el celular (en pantalla ancha está el pie).
Widget? flechaAtras(BuildContext context, VoidCallback onVolver) =>
    esAncho(context) ? null : BotonBlanco(icono: Icons.arrow_back, tooltip: 'Volver', onPressed: onVolver);
