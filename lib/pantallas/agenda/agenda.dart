import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/turno.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';
import 'formulario_cita.dart';

/// Agenda del escritorio: barra Nueva cita / Eliminar / Ver calendario, tabla "CITAS" (ID,
/// Estudiante, Curso, Profesional, Fecha y hora, Estado) y el formulario en el panel lateral, que
/// se abre al tocar una cita o "Nueva cita". El calendario mensual marca los días con citas; tocar
/// un día filtra la lista a ese día.
class Agenda extends StatefulWidget {
  const Agenda({super.key});
  @override
  State<Agenda> createState() => _AgendaState();
}

class _AgendaState extends State<Agenda> {
  List<Turno> _citas = [];
  bool _cargando = true;
  String? _error;
  Turno? _seleccionada;
  bool _calendario = false;
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _dia;

  bool _formulario = false;
  Turno? _enFormulario;
  DateTime? _diaNueva;
  GlobalKey<FormularioCitaState> _claveFormulario = GlobalKey<FormularioCitaState>();

  late final Navegacion _nav;
  int _versionVista = -1;

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _nav = context.read<Navegacion>()..registrarEscape(_alEscape);
    _nav.addListener(_alNavegar);
    _cargar();
  }

  @override
  void dispose() {
    _nav.quitarEscape(_alEscape);
    _nav.removeListener(_alNavegar);
    super.dispose();
  }

  bool _alEscape() {
    if (_formulario && _nav.fichaAbierta == null && _nav.pestana == PestanaEstudiantes.agenda) {
      _claveFormulario.currentState?.pedirCierre();
      return true;
    }
    return false;
  }

  void _alNavegar() {
    if (_nav.version != _versionVista) _cargar(silencioso: true);
  }

  Future<void> _cargar({bool silencioso = false}) async {
    _versionVista = _nav.version;
    if (!silencioso) setState(() => _cargando = true);
    try {
      final data = await ApiClient.instancia.get('/api/turnos');
      if (!mounted) return;
      setState(() {
        _citas = (data as List).map((e) => Turno.fromJson(e)).toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
        _cargando = false;
        _error = null;
        if (_seleccionada != null) _seleccionada = _citas.where((c) => c.id == _seleccionada!.id).firstOrNull;
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

  List<Turno> get _visibles => _dia == null ? _citas : _citas.where((c) => _soloFecha(c.fecha) == _dia).toList();

  Future<void> _abrir(Turno? t, {DateTime? dia}) async {
    if (_formulario && !(await _claveFormulario.currentState?.pedirCierre() ?? true)) return;
    setState(() {
      _seleccionada = t;
      _enFormulario = t;
      _diaNueva = dia;
      _formulario = true;
      _claveFormulario = GlobalKey<FormularioCitaState>(); // formulario nuevo para cada cita
    });
  }

  void _alCerrarFormulario(bool guardado) {
    setState(() => _formulario = false);
    if (guardado) {
      _nav.datosCambiados();
      _cargar(silencioso: true);
    }
  }

  Future<void> _eliminar([Turno? t]) async {
    final c = t ?? _seleccionada;
    if (c == null) return;
    final ok = await confirmar(context,
        titulo: 'Eliminar cita',
        mensaje: '¿Eliminar la cita de ${c.pacienteNombre ?? 'este estudiante'} del ${Tema.fechaHora(c.fechaHora)}?',
        accion: 'Eliminar',
        peligroso: true);
    if (!ok) return;
    try {
      await ApiClient.instancia.delete('/api/turnos/${c.id}');
      if (!mounted) return;
      Tema.aviso(context, 'Cita eliminada');
      setState(() {
        _seleccionada = null;
        _formulario = false;
      });
      _nav.datosCambiados();
      _cargar(silencioso: true);
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    final panel = _formulario
        ? FormularioCita(key: _claveFormulario, turno: _enFormulario, diaInicial: _diaNueva, alCerrar: _alCerrarFormulario)
        : null;
    final barra = Row(children: [
      Boton.exito('Nueva cita', icono: Icons.add, onPressed: () => _abrir(null, dia: _dia)),
      const SizedBox(width: 8),
      Boton.peligro('Eliminar', icono: Icons.delete_outline, soloIcono: !ancho, onPressed: _seleccionada == null ? null : _eliminar),
      if (ancho && !_formulario) ...[
        const SizedBox(width: 10),
        Expanded(
          child: Text('Tocá una cita para verla o editarla',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: p.textoSecundario)),
        ),
      ] else
        const Spacer(),
      Boton(_calendario ? 'Ver lista' : 'Ver calendario', icono: _calendario ? Icons.view_list : Icons.calendar_month,
          onPressed: () => setState(() => _calendario = !_calendario)),
    ]);
    return Padding(
      padding: EdgeInsets.all(ancho ? 16 : 10),
      child: ConPanelLateral(
        panel: panel,
        contenido: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          barra,
          const SizedBox(height: 12),
          if (_calendario) ...[_calendarioMensual(p), const SizedBox(height: 12)],
          Expanded(child: _lista(p, ancho)),
        ]),
      ),
    );
  }

  Widget _lista(Paleta p, bool ancho) {
    Widget cuerpo;
    if (_cargando) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      cuerpo = EstadoVacio(icono: Icons.cloud_off, titulo: 'No se pudo cargar la agenda', detalle: _error, error: true,
          accion: 'Reintentar', onAccion: _cargar);
    } else {
      final auth = context.read<AuthService>();
      cuerpo = RefreshIndicator(
        onRefresh: _cargar,
        child: Tabla<Turno>(
          filas: _visibles,
          seleccionada: _seleccionada,
          igual: (a, b) => a.id == b.id,
          alSeleccionar: (t) => _abrir(t),
          alAbrir: (t) => _abrir(t),
          alMenu: (t, pos) {
            setState(() => _seleccionada = t);
            mostrarMenu(context, pos, [
              ('Ver / editar cita', Icons.edit_calendar_outlined, () => _abrir(t), false),
              ('Ver ficha del estudiante', Icons.person_outline, () => _nav.abrirFicha(t.pacienteId), false),
              ('Eliminar', Icons.delete_outline, () => _eliminar(t), true),
            ]);
          },
          vacio: _dia != null ? 'No hay citas el ${Tema.fecha(Tema.isoFecha(_dia!))}.' : 'No hay citas registradas. Tocá "Nueva cita".',
          columnas: [
            Columna('ID', (t) => Columna.texto('${t.id}'), flex: 1, ordenarPor: (t) => t.id!),
            Columna('Estudiante', (t) => Columna.texto(t.pacienteNombre), flex: 3, ordenarPor: (t) => t.pacienteNombre ?? ''),
            Columna('Curso', (t) => Tooltip(message: t.curso ?? '', child: Columna.texto(t.curso)), flex: 3),
            Columna('Profesional', (t) => Columna.texto(t.psicologoNombre), flex: 3, ordenarPor: (t) => t.psicologoNombre ?? ''),
            Columna('Fecha y hora', (t) => Columna.texto(Tema.fechaHora(t.fechaHora)), flex: 3, ordenarPor: (t) => t.fechaHora),
            Columna('Estado', (t) => EtiquetaEstado(t.estado), flex: 2, ordenarPor: (t) => t.estado),
          ],
          tarjeta: (t) => Row(children: [
            Container(width: 4, height: 46, color: Tema.colorEstado(t.estado)),
            const SizedBox(width: 10),
            Column(children: [
              Text(Tema.hora(t.fecha), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              Text(Tema.fecha(Tema.isoFecha(t.fecha)).substring(0, 5), style: TextStyle(fontSize: 12, color: p.textoSecundario)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.pacienteNombre ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text([Tema.diaLegible(t.fecha), if (!auth.esPsicologo) t.psicologoNombre ?? ''].join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
              ]),
            ),
            EtiquetaEstado(t.estado),
          ]),
        ),
      );
    }
    return Tarjeta(
      titulo: _dia == null ? 'Citas' : 'Citas del ${Tema.fecha(Tema.isoFecha(_dia!))}',
      accion: _dia == null ? null : TextButton(onPressed: () => setState(() => _dia = null), child: const Text('Ver todas las citas')),
      expandir: true,
      padding: EdgeInsets.fromLTRB(ancho ? 18 : 10, 14, ancho ? 18 : 10, 8),
      child: cuerpo,
    );
  }

  Widget _calendarioMensual(Paleta p) {
    final porDia = <DateTime, List<Turno>>{};
    for (final t in _citas) {
      porDia.putIfAbsent(_soloFecha(t.fecha), () => []).add(t);
    }
    final primero = DateTime(_mes.year, _mes.month, 1);
    final dias = DateTime(_mes.year, _mes.month + 1, 0).day;
    final desplazamiento = primero.weekday - 1;
    final hoy = _soloFecha(DateTime.now());
    final celdas = ((desplazamiento + dias) / 7).ceil() * 7;
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(children: [
        Row(children: [
          Boton('Mes anterior', icono: Icons.chevron_left, soloIcono: true,
              onPressed: () => setState(() => _mes = DateTime(_mes.year, _mes.month - 1))),
          Expanded(
            child: Text(Tema.mesAnio(_mes), textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.texto)),
          ),
          Boton('Mes siguiente', icono: Icons.chevron_right, soloIcono: true,
              onPressed: () => setState(() => _mes = DateTime(_mes.year, _mes.month + 1))),
        ]),
        const SizedBox(height: 6),
        Row(
          children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
              .map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, color: p.textoSecundario)))))
              .toList(),
        ),
        const SizedBox(height: 4),
        for (var fila = 0; fila < celdas ~/ 7; fila++)
          Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(child: _celda(p, fila * 7 + col - desplazamiento + 1, dias, porDia, hoy)),
          ]),
      ]),
    );
  }

  Widget _celda(Paleta p, int n, int dias, Map<DateTime, List<Turno>> porDia, DateTime hoy) {
    if (n < 1 || n > dias) return const SizedBox(height: 44);
    final dia = DateTime(_mes.year, _mes.month, n);
    final citas = porDia[dia] ?? const [];
    final elegido = dia == _dia;
    return InkWell(
      onTap: () => setState(() => _dia = elegido ? null : dia),
      onDoubleTap: () => _abrir(null, dia: dia),
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: elegido ? p.primario : (citas.isNotEmpty ? p.seleccion : null),
          borderRadius: BorderRadius.circular(6),
          border: dia == hoy ? Border.all(color: p.primario, width: 1.5) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$n', style: TextStyle(fontWeight: dia == hoy || elegido ? FontWeight.w800 : null, color: elegido ? Colors.white : p.texto)),
          if (citas.isNotEmpty)
            Text('${citas.length} cita${citas.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 10, color: elegido ? Colors.white : p.primario)),
        ]),
      ),
    );
  }
}
