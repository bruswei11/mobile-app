import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/paciente.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/descargas.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';
import '../agenda/formulario_cita.dart';
import 'formulario_estudiante.dart';
import 'importar_estudiantes.dart';

/// GestionPacientes del escritorio: "Buscar estudiante" (texto + curso + Limpiar filtros),
/// "Estudiantes registrados · n" con la barra Ver ficha / Editar datos / Eliminar | Nuevo
/// estudiante / Exportar lista (Excel) / Importar desde Excel, la tabla (doble clic abre la ficha,
/// clic derecho = menú) y el panel lateral Nuevo/Editar estudiante.
class GestionEstudiantes extends StatefulWidget {
  const GestionEstudiantes({super.key});
  @override
  State<GestionEstudiantes> createState() => _GestionEstudiantesState();
}

class _GestionEstudiantesState extends State<GestionEstudiantes> {
  List<Paciente> _todos = [];
  Map<int, String> _profesionales = {};
  bool _cargando = true;
  String? _error;
  final _busqueda = TextEditingController();
  String? _curso;
  Paciente? _seleccionado;
  int? _idASeleccionar;

  // Panel lateral: null = cerrado; Paciente() sin id = nuevo.
  Paciente? _enFormulario;
  bool _formularioAbierto = false;
  GlobalKey<FormularioEstudianteState> _claveFormulario = GlobalKey<FormularioEstudianteState>();

  late final Navegacion _nav;
  int _versionVista = -1;

  @override
  void initState() {
    super.initState();
    _nav = context.read<Navegacion>();
    _nav.registrarEscape(_alEscape);
    _nav.addListener(_alNavegar);
    _curso = _nav.tomarCursoPedido();
    _cargar();
  }

  @override
  void dispose() {
    _nav.quitarEscape(_alEscape);
    _nav.removeListener(_alNavegar);
    _busqueda.dispose();
    super.dispose();
  }

  bool _alEscape() {
    if (_formularioAbierto && _nav.fichaAbierta == null && _nav.pestana == PestanaEstudiantes.lista) {
      _claveFormulario.currentState?.pedirCierre();
      return true;
    }
    return false;
  }

  void _alNavegar() {
    final curso = _nav.tomarCursoPedido();
    if (curso != null) {
      setState(() {
        _curso = curso;
        _busqueda.clear();
      });
    }
    if (_nav.version != _versionVista && _nav.fichaAbierta == null) _cargar(silencioso: true);
  }

  Future<void> _cargar({bool silencioso = false}) async {
    _versionVista = _nav.version;
    if (!silencioso) setState(() => _cargando = true);
    try {
      final auth = context.read<AuthService>();
      final data = await ApiClient.instancia.get('/api/pacientes');
      var profesionales = _profesionales;
      if (!auth.esPsicologo && profesionales.isEmpty) {
        final ps = await ApiClient.instancia.get('/api/turnos/psicologos') as List;
        profesionales = {for (final x in ps) x['id'] as int: x['nombre'] as String};
      }
      if (!mounted) return;
      setState(() {
        _todos = (data as List).map((e) => Paciente.fromJson(e)).toList()
          ..sort((a, b) => _norm(a.nombre + a.apellido).compareTo(_norm(b.nombre + b.apellido)));
        _profesionales = profesionales;
        _cargando = false;
        _error = null;
        if (_idASeleccionar != null) {
          _seleccionado = _todos.where((p) => p.id == _idASeleccionar).firstOrNull;
          _idASeleccionar = null;
        } else if (_seleccionado != null) {
          _seleccionado = _todos.where((p) => p.id == _seleccionado!.id).firstOrNull;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  static String _norm(String s) {
    const con = 'áéíóúüñÁÉÍÓÚÜÑ';
    const sin = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final c in s.split('')) {
      final i = con.indexOf(c);
      b.write(i >= 0 ? sin[i] : c);
    }
    return b.toString().toLowerCase();
  }

  List<Paciente> get _filtrados {
    final q = _norm(_busqueda.text.trim());
    return _todos.where((p) {
      if (_curso != null && p.curso != _curso) return false;
      if (q.isEmpty) return true;
      final t = _norm('${p.nombre} ${p.apellido} ${p.apellido} ${p.nombre} ${p.ci ?? ''} ${p.telefono ?? ''}');
      return q.split(RegExp(r'\s+')).every(t.contains);
    }).toList();
  }

  String _alerta(Paciente p, AuthService auth) => !auth.esPsicologo && p.psicologoId == null ? 'Sin profesional asignado' : '';

  // ---------------------------------------------------------------- acciones

  void _verFicha([Paciente? p]) {
    final e = p ?? _seleccionado;
    if (e == null) return;
    _nav.registrarReciente(e);
    _nav.abrirFicha(e.id!);
  }

  Future<void> _abrirFormulario(Paciente? p) async {
    if (_formularioAbierto && !(await _claveFormulario.currentState?.pedirCierre() ?? true)) return;
    setState(() {
      _enFormulario = p ?? Paciente(nombre: '', apellido: '');
      _formularioAbierto = true;
      _claveFormulario = GlobalKey<FormularioEstudianteState>(); // formulario nuevo cada vez
    });
  }

  void _alCerrarFormulario(int? guardado) {
    setState(() {
      _formularioAbierto = false;
      _enFormulario = null;
      if (guardado != null) _idASeleccionar = guardado;
    });
    if (guardado != null) {
      _nav.datosCambiados();
      _cargar(silencioso: true);
    }
  }

  Future<void> _eliminar([Paciente? p]) async {
    final e = p ?? _seleccionado;
    if (e == null) return;
    final ok = await confirmar(context,
        titulo: 'Eliminar estudiante',
        mensaje: '¿Desea eliminar a ${e.nombreCompleto}? Esta acción no se puede deshacer.',
        accion: 'Eliminar',
        peligroso: true);
    if (!ok) return;
    try {
      await ApiClient.instancia.delete('/api/pacientes/${e.id}');
      if (!mounted) return;
      Tema.aviso(context, 'Estudiante eliminado');
      setState(() => _seleccionado = null);
      _nav.datosCambiados();
      _cargar(silencioso: true);
    } catch (err) {
      if (mounted) Tema.aviso(context, err.toString(), error: true);
    }
  }

  Future<void> _exportar() async {
    final lista = _filtrados;
    if (lista.isEmpty) {
      Tema.aviso(context, 'No hay estudiantes para exportar con estos filtros', error: true);
      return;
    }
    if (!Descargas.disponible) {
      Tema.aviso(context, 'Exportar está disponible en la versión web (navegador)', error: true);
      return;
    }
    final filtros = [
      if (_curso != null) 'curso: $_curso',
      if (_busqueda.text.trim().isNotEmpty) 'búsqueda: "${_busqueda.text.trim()}"',
    ];
    try {
      final archivo = await ApiClient.instancia.descargar('/api/reportes/estudiantes', {
        if (lista.length != _todos.length) 'ids': lista.map((p) => p.id).toList(),
        'descripcion': filtros.isEmpty ? 'todos' : 'filtro: ${filtros.join(', ')}',
      });
      Descargas.guardar(archivo.bytes, archivo.nombre, archivo.tipo);
      if (mounted) Tema.aviso(context, 'Lista exportada: ${archivo.nombre} (${lista.length} estudiantes) — quedó en Descargas');
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    }
  }

  Future<void> _importar() async {
    final n = await ImportarEstudiantes.iniciar(context);
    if (n != null && n > 0) {
      _nav.datosCambiados();
      _cargar(silencioso: true);
    }
  }

  void _menu(Paciente p, Offset pos) {
    setState(() => _seleccionado = p);
    mostrarMenu(context, pos, [
      ('Ver ficha', Icons.person_outline, () => _verFicha(p), false),
      ('Editar datos', Icons.edit_outlined, () => _abrirFormulario(p), false),
      ('Nueva cita', Icons.event_available, () => FormularioCita.mostrar(context, paciente: p), false),
      ('Eliminar', Icons.delete_outline, () => _eliminar(p), true),
    ]);
  }

  // ---------------------------------------------------------------- vista

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final ancho = esAncho(context);
    final filtrados = _filtrados;
    final panel = _formularioAbierto
        ? FormularioEstudiante(
            key: _claveFormulario,
            paciente: _enFormulario?.id == null ? null : _enFormulario,
            alCerrar: _alCerrarFormulario,
          )
        : null;
    return Padding(
      padding: EdgeInsets.all(ancho ? 16 : 10),
      child: ConPanelLateral(
        panel: panel,
        contenido: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tarjetaBuscar(ancho),
            SizedBox(height: ancho ? 16 : 10),
            Expanded(child: _tarjetaLista(auth, filtrados, ancho)),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaBuscar(bool ancho) {
    final cursos = {..._todos.map((p) => p.curso).whereType<String>(), ?_curso}.toList()..sort();
    final campoBuscar = TextField(
      controller: _busqueda,
      onChanged: (_) => setState(() {}),
      decoration: decoracionCampo(context, hint: 'Nombre, apellido, teléfono o CI', prefijo: const Icon(Icons.search, size: 20)),
    );
    final comboCurso = DropdownButtonFormField<String?>(
      initialValue: _curso,
      key: ValueKey('curso_$_curso'),
      isExpanded: true,
      decoration: decoracionCampo(context),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
        ...cursos.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) => setState(() => _curso = v),
    );
    final limpiar = Boton('Limpiar filtros', icono: Icons.refresh, onPressed: () => setState(() {
          _busqueda.clear();
          _curso = null;
        }));
    if (!ancho) {
      return Column(children: [
        campoBuscar,
        const SizedBox(height: 8),
        Row(children: [Expanded(child: comboCurso), const SizedBox(width: 8), Boton('Limpiar', soloIcono: true, icono: Icons.refresh, onPressed: () => setState(() {
              _busqueda.clear();
              _curso = null;
            }))]),
      ]);
    }
    return Tarjeta(
      titulo: 'Buscar estudiante',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const SizedBox(width: 60, child: Text('Buscar:', style: TextStyle(fontSize: 14.5))),
          SizedBox(width: 360, child: campoBuscar),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const SizedBox(width: 60, child: Text('Curso:', style: TextStyle(fontSize: 14.5))),
          SizedBox(width: 360, child: comboCurso),
          const SizedBox(width: 12),
          limpiar,
        ]),
      ]),
    );
  }

  Widget _tarjetaLista(AuthService auth, List<Paciente> filtrados, bool ancho) {
    final p = Paleta.de(context);
    final hay = _seleccionado != null;
    final compacto = !ancho || _formularioAbierto;
    final barra = Row(children: [
      if (ancho) ...[
        Boton.primario('Ver ficha', icono: Icons.person, soloIcono: compacto, onPressed: hay ? _verFicha : null, tooltip: 'Ver ficha (doble clic)'),
        const SizedBox(width: 8),
        Boton('Editar datos', icono: Icons.edit, soloIcono: compacto, onPressed: hay ? () => _abrirFormulario(_seleccionado) : null),
        const SizedBox(width: 8),
        Boton.peligro('Eliminar', icono: Icons.delete_outline, soloIcono: compacto, onPressed: hay ? _eliminar : null),
        const SizedBox(width: 8),
      ],
      Boton.exito(ancho ? 'Nuevo estudiante' : 'Nuevo', icono: Icons.add, onPressed: () => _abrirFormulario(null)),
      const Spacer(),
      Boton('Exportar lista (Excel)', icono: Icons.file_download_outlined, soloIcono: compacto, onPressed: _exportar),
      const SizedBox(width: 8),
      Boton('Importar desde Excel', icono: Icons.upload_file, soloIcono: compacto, onPressed: _importar),
    ]);

    Widget cuerpo;
    if (_cargando) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      cuerpo = EstadoVacio(icono: Icons.cloud_off, titulo: 'No se pudo cargar la lista', detalle: _error, error: true,
          accion: 'Reintentar', onAccion: _cargar);
    } else {
      cuerpo = RefreshIndicator(
        onRefresh: _cargar,
        child: Tabla<Paciente>(
          filas: filtrados,
          seleccionada: _seleccionado,
          igual: (a, b) => a.id == b.id,
          alSeleccionar: (e) => setState(() => _seleccionado = e),
          alAbrir: _verFicha,
          alMenu: _menu,
          vacio: _todos.isEmpty
              ? (auth.esPsicologo ? 'Todavía no hay estudiantes asignados a vos.' : 'Todavía no hay estudiantes registrados. Tocá "Nuevo estudiante".')
              : 'Ningún estudiante coincide con los filtros.',
          columnas: [
            Columna('ID', (e) => Columna.texto('${e.id}'), flex: 1, ordenarPor: (e) => e.id!),
            Columna('Nombre', (e) => Columna.texto(e.nombre), ordenarPor: (e) => _norm(e.nombre)),
            Columna('Apellido', (e) => Columna.texto(e.apellido), ordenarPor: (e) => _norm(e.apellido)),
            Columna('CI', (e) => Columna.texto(e.ci), ordenarPor: (e) => e.ci ?? ''),
            Columna('Teléfono', (e) => Columna.texto(e.telefono)),
            Columna('Género', (e) => Columna.texto(e.genero), ordenarPor: (e) => e.genero ?? ''),
            Columna('Curso', (e) => Tooltip(message: e.curso ?? '', child: Columna.texto(e.curso)), flex: 3, ordenarPor: (e) => e.curso ?? ''),
            Columna('Consent.', (e) => Columna.texto(e.consentimientoTutor ? 'Sí' : 'No'), flex: 1),
            Columna('Alerta', (e) => Columna.texto(_alerta(e, auth), siVacio: '', color: Tema.legible(context, Tema.ambar)),
                ordenarPor: (e) => _alerta(e, auth)),
          ],
          tarjeta: (e) => Row(children: [
            AvatarIniciales(nombre: e.nombreCompleto),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(e.curso ?? 'Sin curso asignado',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                if (_alerta(e, auth).isNotEmpty || !e.consentimientoTutor || (e.psicologoId != null && _profesionales[e.psicologoId] != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                      if (_alerta(e, auth).isNotEmpty)
                        const Pastilla(texto: 'Sin profesional asignado', color: Tema.ambar, icono: Icons.warning_amber_rounded),
                      if (e.psicologoId != null && _profesionales[e.psicologoId] != null)
                        Pastilla(texto: _profesionales[e.psicologoId]!, color: Tema.secundario, icono: Icons.person_outline),
                      if (!e.consentimientoTutor)
                        const Pastilla(texto: 'Sin consentimiento', color: Tema.rosa, icono: Icons.gpp_maybe_outlined),
                    ]),
                  ),
              ]),
            ),
            IconButton(tooltip: 'Más acciones', icon: const Icon(Icons.more_vert), onPressed: () => _menu(e, Offset.zero)),
          ]),
        ),
      );
    }

    return Tarjeta(
      titulo: 'Estudiantes registrados · ${filtrados.length}${filtrados.length != _todos.length ? ' de ${_todos.length}' : ''}',
      expandir: true,
      padding: EdgeInsets.fromLTRB(ancho ? 18 : 10, 14, ancho ? 18 : 10, ancho ? 10 : 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        barra,
        const SizedBox(height: 10),
        Expanded(child: cuerpo),
      ]),
    );
  }
}
