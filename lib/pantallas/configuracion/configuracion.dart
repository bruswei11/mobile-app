import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/usuario.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/bloqueo_service.dart';
import '../../services/navegacion.dart';
import '../../services/preferencias.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';
import '../menu_principal.dart';

/// Configuracion del escritorio: pestañas Mi cuenta (nombre, contraseña y Preferencias: modo oscuro,
/// bloqueo) / Marco Legal / Mi actividad / Usuarios (solo josechavez: crear cuentas nuevas).
/// Abajo, Cerrar sesión y Volver.
class Configuracion extends StatefulWidget {
  const Configuracion({super.key});
  @override
  State<Configuracion> createState() => _ConfiguracionState();
}

class _ConfiguracionState extends State<Configuracion> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final bool _usuarios;

  @override
  void initState() {
    super.initState();
    _usuarios = context.read<AuthService>().puedeCrearUsuarios;
    _tabs = TabController(length: _usuarios ? 4 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _cerrarSesion() async {
    final auth = context.read<AuthService>();
    final ok = await confirmar(context,
        titulo: 'Cerrar sesión', mensaje: '¿Cerrar la sesión de ${auth.nombre}?', accion: 'Cerrar sesión', peligroso: true);
    if (ok) auth.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.read<Navegacion>();
    final ancho = esAncho(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Encabezado(
        titulo: 'Configuración',
        subtitulo: _usuarios ? 'Cuenta, preferencias, marco legal, tu actividad y usuarios' : 'Cuenta, preferencias, marco legal y tu actividad',
        izquierda: flechaAtras(context, nav.irAlMenu),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(ancho ? 14 : 0, ancho ? 14 : 0, ancho ? 14 : 0, 0),
        child: BarraPestanas(controller: _tabs, pestanas: [
          const Pestana('Mi cuenta', Icons.person_outline),
          const Pestana('Marco Legal', Icons.gavel),
          const Pestana('Mi actividad', Icons.history),
          if (_usuarios) const Pestana('Usuarios', Icons.people_alt_outlined),
        ]),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, physics: const NeverScrollableScrollPhysics(), children: [
          const _MiCuenta(),
          const _MarcoLegal(),
          const _Actividad(),
          if (_usuarios) const _Usuarios(),
        ]),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 8, ancho ? 20 : 12, 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Boton.peligro('Cerrar sesión', icono: Icons.logout, onPressed: _cerrarSesion),
          if (ancho) ...[const SizedBox(width: 12), Boton('Volver', icono: Icons.arrow_back, onPressed: nav.irAlMenu)],
        ]),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Mi cuenta

class _MiCuenta extends StatefulWidget {
  const _MiCuenta();
  @override
  State<_MiCuenta> createState() => _MiCuentaState();
}

class _MiCuentaState extends State<_MiCuenta> {
  static const _minLargo = 8;
  late final TextEditingController _nombre;
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();
  bool _guardandoNombre = false;
  bool _guardandoClave = false;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: context.read<AuthService>().nombre);
  }

  Future<void> _guardarNombre() async {
    final auth = context.read<AuthService>();
    final nuevo = _nombre.text.trim();
    if (nuevo.isEmpty) {
      Tema.aviso(context, 'El nombre no puede estar vacío', error: true);
      return;
    }
    setState(() => _guardandoNombre = true);
    try {
      await ApiClient.instancia.put('/api/usuarios/me/nombre', {'nombre': nuevo});
      auth.actualizarNombre(nuevo);
      if (mounted) Tema.aviso(context, 'Nombre actualizado');
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _guardandoNombre = false);
    }
  }

  Future<void> _cambiarClave() async {
    if (_nueva.text.length < _minLargo) {
      Tema.aviso(context, 'La nueva contraseña debe tener al menos $_minLargo caracteres', error: true);
      return;
    }
    if (_nueva.text != _repetir.text) {
      Tema.aviso(context, 'La confirmación no coincide con la nueva contraseña', error: true);
      return;
    }
    setState(() => _guardandoClave = true);
    try {
      await ApiClient.instancia.put('/api/usuarios/me/password', {'passwordActual': _actual.text, 'passwordNueva': _nueva.text});
      if (!mounted) return;
      Tema.aviso(context, 'Contraseña actualizada');
      _actual.clear();
      _nueva.clear();
      _repetir.clear();
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _guardandoClave = false);
    }
  }

  Widget _fila(String etiqueta, Widget campo) {
    final ancho = esAncho(context);
    if (!ancho) return Padding(padding: const EdgeInsets.only(bottom: 10), child: Campo(etiqueta, campo));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [SizedBox(width: 200, child: Text(etiqueta, style: const TextStyle(fontSize: 14.5))), Expanded(child: campo)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final prefs = context.watch<Preferencias>();
    final p = Paleta.de(context);
    final ancho = esAncho(context);
    return ListView(padding: EdgeInsets.all(ancho ? 14 : 10), children: [
      Tarjeta(
        titulo: 'Mi cuenta',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Conectado como ${auth.usuario} (${auth.etiquetaRol()})', style: TextStyle(color: p.textoSecundario)),
          const SizedBox(height: 12),
          _fila('Nombre para mostrar:', TextField(controller: _nombre, decoration: decoracionCampo(context))),
          Padding(
            padding: EdgeInsets.only(left: ancho ? 200 : 0),
            child: Align(alignment: Alignment.centerLeft,
                child: Boton.primario('Guardar nombre', icono: Icons.check, cargando: _guardandoNombre, onPressed: _guardarNombre)),
          ),
          const SizedBox(height: 14),
          Divider(color: p.borde),
          const SizedBox(height: 10),
          _fila('Contraseña actual:', TextField(controller: _actual, obscureText: true, decoration: decoracionCampo(context))),
          _fila('Nueva contraseña:', TextField(controller: _nueva, obscureText: true,
              decoration: decoracionCampo(context, hint: 'Mínimo $_minLargo caracteres'))),
          _fila('Confirmar nueva contraseña:', TextField(controller: _repetir, obscureText: true,
              onSubmitted: (_) => _cambiarClave(), decoration: decoracionCampo(context))),
          Padding(
            padding: EdgeInsets.only(left: ancho ? 200 : 0),
            child: Align(alignment: Alignment.centerLeft,
                child: Boton.primario('Cambiar contraseña', icono: Icons.check, cargando: _guardandoClave, onPressed: _cambiarClave)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Tarjeta(
        titulo: 'Preferencias',
        child: Wrap(spacing: 18, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Modo oscuro')),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Del sistema')),
            ],
            selected: {prefs.modoTema},
            onSelectionChanged: (v) => prefs.cambiarTema(v.first),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Bloquear la pantalla tras  ', style: TextStyle(fontSize: 14.5)),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<int>(
                initialValue: prefs.bloqueoMinutos,
                decoration: decoracionCampo(context),
                items: Preferencias.opcionesBloqueo
                    .map((m) => DropdownMenuItem(value: m, child: Text(m == 0 ? 'Nunca' : '${Preferencias.etiquetaBloqueo(m)} sin uso')))
                    .toList(),
                onChanged: (v) => prefs.cambiarBloqueo(v ?? 5),
              ),
            ),
          ]),
          Boton('Bloquear ahora', icono: Icons.lock_outline, onPressed: () => context.read<BloqueoService>().bloquear(), tooltip: 'Ctrl+L'),
          Text('Exportar estudiantes y respaldos: Estudiantes → pestaña "Reportes y archivos"',
              style: TextStyle(fontSize: 12, color: p.textoSecundario)),
        ]),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Marco Legal

class _MarcoLegal extends StatelessWidget {
  const _MarcoLegal();

  static const _normas = [
    ('Ley N° 4633/2012 — Contra el Acoso Escolar',
        'Define el acoso u hostigamiento escolar como violencia física, verbal, psicológica o social entre estudiantes que se da de forma REITERADA y genera un agravio en el desarrollo del afectado — un hecho aislado no alcanza este umbral legal. Clasifica el acoso en tres tipos: Directo (daño físico), Indirecto (daño a bienes o pertenencias) y Verbal (insultos, ofensas). Aplica a instituciones educativas públicas, privadas y subvencionadas en todos los niveles. Esta es la clasificación que usan los campos "Tipo de acoso" y "¿Es reiterado?" en Seguimiento del Estudiante.'),
    ('Resolución MEC N° 8353/2012 — Protocolo de Atención',
        'Aprueba el protocolo oficial que el colegio debe activar ante cualquier sospecha de violencia o acoso escolar: detección temprana, medidas urgentes, y un plan de intervención a nivel individual, de aula y familiar. Cualquier miembro de la comunidad educativa (familia, docente, estudiante) puede activar el protocolo.'),
    ('CIE-10 — Clasificación Internacional de Enfermedades',
        'Estándar de la OMS que también usa el Ministerio de Salud Pública de Paraguay (MSPBS) para codificar diagnósticos y motivos de consulta en salud mental. El capítulo F (F00-F99) cubre trastornos mentales reales (ej. F90 TDAH, F91 trastornos de conducta) — asignar un código F es un acto clínico. El capítulo Z (Z00-Z99) cubre situaciones de vida sin ser un trastorno (ej. Z55 problemas educativos, Z63 problemas familiares) y suele ajustarse mejor a una atención escolar común. El campo "Código CIE-10" de Seguimiento del Estudiante es opcional.'),
    ('Ley N° 1680/01 — Código de la Niñez y la Adolescencia',
        'Establece que los expedientes de niños y adolescentes son estrictamente confidenciales: solo pueden acceder el propio estudiante, sus padres/tutores, representantes legales, y quienes demuestren un interés legítimo. Refuerza el control de acceso por roles que ya usa este sistema (por ejemplo, que el rol "Usuario autorizado" no vea las pestañas clínicas).'),
    ('Ley N° 7.593/2025 — Protección de Datos Personales',
        'Primera ley general de protección de datos de Paraguay (entra en vigencia en noviembre de 2027). Clasifica la salud como "dato sensible" y fija sanciones más altas cuando el titular del dato es un niño o adolescente — el caso de este sistema. Exige poder responder pedidos de acceso/rectificación/eliminación en 30 días y notificar brechas de seguridad en 72 horas. El consentimiento del padre/madre/tutor que se registra en la ficha del estudiante responde a este marco.'),
    ('Código de Ética del Psicólogo (Sociedad Paraguaya de Psicología)',
        'Establece el secreto profesional: toda la información que maneja el psicólogo es confidencial y solo puede revelarse con consentimiento expreso del usuario o por orden judicial.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Paleta.de(context);
    return ListView(padding: EdgeInsets.all(esAncho(context) ? 14 : 10), children: [
      Tarjeta(
        titulo: 'Marco Legal y Normativo',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Referencia rápida de las normas paraguayas relacionadas con la atención psicológica escolar y con los datos que registra este sistema. No reemplaza asesoría legal formal.',
              style: TextStyle(color: p.textoSecundario, fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),
          for (final (titulo, texto) in _normas)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: TextStyle(fontWeight: FontWeight.w800, color: p.primario, fontSize: 15)),
                const SizedBox(height: 5),
                Text(texto, style: TextStyle(height: 1.45, color: p.texto)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Mi actividad (solo la propia)

class _Actividad extends StatefulWidget {
  const _Actividad();
  @override
  State<_Actividad> createState() => _ActividadState();
}

class _ActividadState extends State<_Actividad> {
  final _texto = TextEditingController();
  DateTime? _desde;
  DateTime? _hasta;
  List<RegistroAuditoria> _registros = [];
  bool _cargando = true;
  bool _hayMas = false;
  static const _pagina = 100;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool masAntiguos = false}) async {
    setState(() => _cargando = true);
    DateTime? hasta = _hasta == null ? null : DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59);
    if (masAntiguos && _registros.isNotEmpty) {
      hasta = DateTime.parse(_registros.last.fecha).subtract(const Duration(seconds: 1));
    }
    try {
      final data = await ApiClient.instancia.get('/api/auditoria', {
        if (_texto.text.trim().isNotEmpty) 'texto': _texto.text.trim(),
        if (_desde != null) 'desde': Tema.isoLocal(_desde!),
        if (hasta != null) 'hasta': Tema.isoLocal(hasta),
        'limite': _pagina,
      });
      if (!mounted) return;
      final nuevos = (data as List).map((e) => RegistroAuditoria.fromJson(e)).toList();
      setState(() {
        _registros = masAntiguos ? [..._registros, ...nuevos] : nuevos;
        _hayMas = nuevos.length == _pagina;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        Tema.aviso(context, e.toString(), error: true);
      }
    }
  }

  Future<void> _elegirFecha(bool desde) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (desde ? _desde : _hasta) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    setState(() => desde ? _desde = d : _hasta = d);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    return Padding(
      padding: EdgeInsets.all(ancho ? 14 : 10),
      child: Tarjeta(
        titulo: 'Mi actividad · qué registros abriste o cambiaste y cuándo',
        expandir: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: ancho ? 300 : double.infinity,
              child: TextField(controller: _texto, onSubmitted: (_) => _cargar(),
                  decoration: decoracionCampo(context, hint: 'Acción o detalle', prefijo: const Icon(Icons.search, size: 20))),
            ),
            Boton(_desde == null ? 'Desde…' : 'Desde ${Tema.fecha(Tema.isoFecha(_desde!))}', icono: Icons.event, onPressed: () => _elegirFecha(true)),
            Boton(_hasta == null ? 'Hasta…' : 'Hasta ${Tema.fecha(Tema.isoFecha(_hasta!))}', icono: Icons.event, onPressed: () => _elegirFecha(false)),
            if (_desde != null || _hasta != null || _texto.text.isNotEmpty)
              Boton('Limpiar', icono: Icons.filter_alt_off, onPressed: () {
                _texto.clear();
                setState(() {
                  _desde = null;
                  _hasta = null;
                });
                _cargar();
              }),
            Boton.primario('Buscar', icono: Icons.search, onPressed: _cargar),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: _cargando && _registros.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Tabla<RegistroAuditoria>(
                    filas: _registros,
                    vacio: 'Sin registros para estos filtros.',
                    columnas: [
                      Columna('Fecha', (r) => Columna.texto(Tema.fechaHora(r.fecha)), flex: 2, ordenarPor: (r) => r.fecha),
                      Columna('Acción', (r) => Columna.texto(r.accion), flex: 3, ordenarPor: (r) => r.accion),
                      Columna('Entidad', (r) => Columna.texto('${r.entidad}${r.entidadId != null ? ' #${r.entidadId}' : ''}'), flex: 2),
                      Columna('Detalle', (r) => Tooltip(message: r.detalle ?? '', child: Columna.texto(r.detalle ?? '')), flex: 4),
                    ],
                    tarjeta: (r) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.accion, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(Tema.fechaHora(r.fecha), style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                      if ((r.detalle ?? '').isNotEmpty) Text(r.detalle!, style: const TextStyle(fontSize: 12.5)),
                    ]),
                  ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text('${_registros.length} registros', style: TextStyle(color: p.textoSecundario)),
            const Spacer(),
            if (_hayMas) Boton('Cargar más antiguos', cargando: _cargando, onPressed: () => _cargar(masAntiguos: true)),
          ]),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ Usuarios (solo josechavez)

/// Cuentas del sistema y "Nuevo usuario". Todas son de profesional de psicología; no hay registro
/// libre desde el login, así que esta es la única forma de sumar a alguien.
class _Usuarios extends StatefulWidget {
  const _Usuarios();
  @override
  State<_Usuarios> createState() => _UsuariosState();
}

class _UsuariosState extends State<_Usuarios> {
  List<Usuario> _usuarios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await ApiClient.instancia.get('/api/usuarios');
      if (!mounted) return;
      setState(() {
        _usuarios = (data as List).map((e) => Usuario.fromJson(e)).toList();
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        Tema.aviso(context, e.toString(), error: true);
      }
    }
  }

  Future<void> _nuevo() async {
    final creado = await mostrarHoja<String>(
      context,
      titulo: 'Nuevo usuario',
      subtitulo: 'Cuenta de profesional de psicología. Va a ver solo a sus propios estudiantes.',
      ancho: 520,
      contenido: (_) => const _FormularioUsuario(),
    );
    if (creado == null || !mounted) return;
    Tema.aviso(context, 'Cuenta "$creado" creada. Pasale el usuario y la contraseña para que ingrese.');
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    return Padding(
      padding: EdgeInsets.all(ancho ? 14 : 10),
      child: Tarjeta(
        titulo: 'Usuarios del sistema',
        accion: Boton.primario('Nuevo usuario', icono: Icons.person_add_alt_1, onPressed: _nuevo),
        expandir: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Solo vos podés crear cuentas. Cada profesional ve únicamente a sus estudiantes.',
              style: TextStyle(color: p.textoSecundario)),
          const SizedBox(height: 10),
          Expanded(
            child: _cargando && _usuarios.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Tabla<Usuario>(
                    filas: _usuarios,
                    vacio: 'Todavía no hay usuarios.',
                    columnas: [
                      Columna('Nombre', (u) => Columna.texto(u.nombre, negrita: true), flex: 3, ordenarPor: (u) => u.nombre),
                      Columna('Usuario', (u) => Columna.texto(u.usuario), flex: 2, ordenarPor: (u) => u.usuario),
                      Columna('Estado', (u) => Columna.texto(u.activo ? 'Activa' : 'Desactivada',
                          color: u.activo ? null : p.textoSecundario), flex: 1),
                    ],
                    tarjeta: (u) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${u.usuario}${u.activo ? '' : ' · desactivada'}', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                    ]),
                  ),
          ),
          const SizedBox(height: 8),
          Text('${_usuarios.length} usuarios', style: TextStyle(color: p.textoSecundario)),
        ]),
      ),
    );
  }
}

class _FormularioUsuario extends StatefulWidget {
  const _FormularioUsuario();
  @override
  State<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends State<_FormularioUsuario> {
  static const _minLargo = 8;
  final _nombre = TextEditingController();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _repetir = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _usuario, _clave, _repetir]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validar() {
    if (_nombre.text.trim().isEmpty) return 'Escribí el nombre y apellido';
    if (!RegExp(r'^[A-Za-z0-9._-]{3,30}$').hasMatch(_usuario.text.trim())) {
      return 'El usuario debe tener entre 3 y 30 caracteres: letras, números, punto, guion o guion bajo (sin espacios)';
    }
    if (_clave.text.length < _minLargo) return 'La contraseña debe tener al menos $_minLargo caracteres';
    if (_clave.text != _repetir.text) return 'Las contraseñas no coinciden';
    return null;
  }

  Future<void> _crear() async {
    final problema = _validar();
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ApiClient.instancia.post('/api/usuarios', {
        'nombre': _nombre.text.trim(),
        'usuario': _usuario.text.trim(),
        'password': _clave.text,
      });
      if (mounted) Navigator.pop(context, _usuario.text.trim());
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e is ApiException ? e.mensaje : e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Campo('Nombre y apellido*', TextField(controller: _nombre, autofocus: true, textCapitalization: TextCapitalization.words,
          decoration: decoracionCampo(context, hint: 'Ej.: Lic. María González'))),
      const SizedBox(height: 12),
      Campo('Usuario* (con este nombre va a ingresar, sin espacios)',
          TextField(controller: _usuario, decoration: decoracionCampo(context, hint: 'Ej.: mariagonzalez'))),
      const SizedBox(height: 12),
      Campo('Contraseña*', TextField(controller: _clave, obscureText: true,
          decoration: decoracionCampo(context, hint: 'Mínimo $_minLargo caracteres'))),
      const SizedBox(height: 12),
      Campo('Repetir contraseña*', TextField(controller: _repetir, obscureText: true, onSubmitted: (_) => _crear(),
          decoration: decoracionCampo(context))),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, size: 18, color: error),
          const SizedBox(width: 6),
          Expanded(child: Text(_error!, style: TextStyle(color: error))),
        ]),
      ],
      const SizedBox(height: 18),
      Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
        Boton('Cancelar', onPressed: _guardando ? null : () => Navigator.pop(context)),
        Boton.primario('Crear usuario', icono: Icons.check, cargando: _guardando, onPressed: _crear),
      ]),
    ]);
  }
}
