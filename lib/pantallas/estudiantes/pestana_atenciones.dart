import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/paciente.dart';
import '../../models/sesion.dart';
import '../../models/turno.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/borradores.dart';
import '../../services/bloqueo_service.dart';
import '../../services/descargas.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';

/// Pestaña "Atenciones" del escritorio: cita asociada, cronómetro (Iniciar atención / Pausar),
/// los cuatro campos SOAP con las etiquetas del colegio, "Seguimiento y notas privadas" (no forman
/// parte del informe), Guardar atención / Nueva atención / Exportar nota, y la tabla de atenciones
/// registradas. Guardar ligada a una cita "Programada" la marca "Realizada". Mientras corre el
/// cronómetro la sesión no se bloquea sola. Lo escrito se guarda solo como borrador en el
/// dispositivo cada 5 segundos (y al pasar a segundo plano): si se cierra la pestaña o el teléfono
/// cierra el navegador, al volver se ofrece recuperarlo.
class PestanaAtenciones extends StatefulWidget {
  final Paciente paciente;
  const PestanaAtenciones({super.key, required this.paciente});
  @override
  State<PestanaAtenciones> createState() => PestanaAtencionesState();
}

class PestanaAtencionesState extends State<PestanaAtenciones> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _subjetivo = TextEditingController();
  final _objetivo = TextEditingController();
  final _analisis = TextEditingController();
  final _plan = TextEditingController();
  final _notas = TextEditingController();
  final _buscar = TextEditingController();
  List<Turno> _citas = [];
  int? _citaId;
  List<Sesion> _atenciones = [];
  Sesion? _viendo;
  bool _cargando = true;
  bool _guardando = false;

  Timer? _timer;
  int _segundos = 0;
  bool _corriendo = false;
  late final BloqueoService _bloqueo;

  Timer? _autoguardado;
  late final String _claveBorrador;
  String? _ultimoBorrador; // último contenido escrito en el borrador (para no reescribir lo mismo)
  Map<String, dynamic>? _borradorPendiente; // borrador encontrado al abrir, a recuperar o descartar
  bool _descartado = false;

  @override
  bool get wantKeepAlive => true;

  List<TextEditingController> get _campos => [_subjetivo, _objetivo, _analisis, _plan, _notas];
  bool get cronometroEnMarcha => _corriendo;
  bool get hayBorrador => _viendo == null && (_segundos > 0 || _campos.any((c) => c.text.trim().isNotEmpty));

  @override
  void initState() {
    super.initState();
    _bloqueo = context.read<BloqueoService>();
    _claveBorrador = Borradores.claveAtencion(context.read<AuthService>().usuarioId ?? 0, widget.paciente.id!);
    WidgetsBinding.instance.addObserver(this);
    _cargar();
    _buscarBorrador();
    _autoguardado = Timer.periodic(const Duration(seconds: 5), (_) => _guardarBorrador());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Antes de que el sistema pueda cerrar el navegador/la app, se guarda lo último escrito.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      _guardarBorrador();
    }
  }

  @override
  void dispose() {
    _autoguardado?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _guardarBorrador();
    detenerCronometro();
    for (final c in [..._campos, _buscar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final r = await Future.wait([
        ApiClient.instancia.get('/api/estudiantes/${widget.paciente.id}/atenciones'),
        ApiClient.instancia.get('/api/turnos', {'pacienteId': widget.paciente.id}),
      ]);
      if (!mounted) return;
      setState(() {
        _atenciones = (r[0] as List).map((e) => Sesion.fromJson(e)).toList();
        _citas = (r[1] as List).map((e) => Turno.fromJson(e)).toList()..sort((a, b) => b.fecha.compareTo(a.fecha));
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        Tema.aviso(context, e.toString(), error: true);
      }
    }
  }

  Map<String, dynamic> get _contenidoBorrador => {
        'subjetivo': _subjetivo.text,
        'objetivo': _objetivo.text,
        'analisis': _analisis.text,
        'plan': _plan.text,
        'notas': _notas.text,
        'citaId': _citaId,
        'segundos': _segundos,
      };

  Future<void> _guardarBorrador() async {
    if (_descartado || _viendo != null || _borradorPendiente != null) return;
    if (!hayBorrador) {
      if (_ultimoBorrador != null) {
        _ultimoBorrador = null;
        await Borradores.borrar(_claveBorrador);
      }
      return;
    }
    final contenido = _contenidoBorrador;
    final firma = contenido.toString();
    if (firma == _ultimoBorrador) return;
    _ultimoBorrador = firma;
    await Borradores.guardar(_claveBorrador, contenido);
  }

  Future<void> _borrarBorrador() async {
    _ultimoBorrador = null;
    await Borradores.borrar(_claveBorrador);
  }

  /// Al salir de la ficha descartando lo escrito: el borrador no debe quedar guardado.
  Future<void> descartarBorrador() async {
    _descartado = true;
    await _borrarBorrador();
  }

  Future<void> _buscarBorrador() async {
    final b = await Borradores.leer(_claveBorrador);
    if (b != null && mounted && !hayBorrador) setState(() => _borradorPendiente = b);
  }

  void _recuperarBorrador() {
    final b = _borradorPendiente;
    if (b == null) return;
    setState(() {
      _viendo = null;
      _subjetivo.text = b['subjetivo'] ?? '';
      _objetivo.text = b['objetivo'] ?? '';
      _analisis.text = b['analisis'] ?? '';
      _plan.text = b['plan'] ?? '';
      _notas.text = b['notas'] ?? '';
      _citaId = b['citaId'] as int?;
      _segundos = (b['segundos'] as num?)?.toInt() ?? 0;
      _borradorPendiente = null;
    });
    Tema.aviso(context, _segundos > 0
        ? 'Atención recuperada. El cronómetro quedó en pausa en ${_reloj(_segundos)}: tocá "Iniciar atención" para seguir.'
        : 'Atención recuperada');
  }

  Future<void> _descartarBorrador() async {
    final ok = await confirmar(context,
        titulo: 'Descartar el borrador',
        mensaje: 'Se borra la atención que había quedado sin guardar. No se puede recuperar después.',
        accion: 'Descartar',
        peligroso: true);
    if (!ok) return;
    await _borrarBorrador();
    if (mounted) setState(() => _borradorPendiente = null);
  }

  Widget _avisoBorrador(Paleta p) {
    final fecha = Tema.fechaHora(_borradorPendiente!['guardadoEn']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tema.ambar.withValues(alpha: p.oscuro ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Tema.ambar.withValues(alpha: 0.5)),
      ),
      child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Icon(Icons.restore, color: Tema.legible(context, Tema.ambar)),
        Text('Hay una atención sin guardar del $fecha.', style: const TextStyle(fontWeight: FontWeight.w700)),
        Boton.primario('Recuperar', icono: Icons.restore, onPressed: _recuperarBorrador),
        Boton('Descartar', onPressed: _descartarBorrador),
      ]),
    );
  }

  void _iniciar() {
    if (_corriendo || _viendo != null) return;
    _bloqueo.atencionesEnCurso++;
    setState(() => _corriendo = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _segundos++));
  }

  void detenerCronometro() {
    _timer?.cancel();
    if (_corriendo) _bloqueo.atencionesEnCurso = (_bloqueo.atencionesEnCurso - 1).clamp(0, 99);
    _corriendo = false;
    if (mounted) setState(() {});
  }

  void mostrarAtencion(Object? dato) {
    if (dato is Sesion) _ver(dato);
  }

  Future<bool> _confirmarDescarte() => confirmar(context,
      titulo: 'Descartar la atención',
      mensaje: _corriendo
          ? 'La atención está en curso (cronómetro en marcha) y no se guardó. Si seguís, se pierde.'
          : 'La atención que estás escribiendo no se guardó. Si seguís, se pierde.',
      accion: 'Descartar',
      cancelar: 'Seguir editando',
      peligroso: true);

  Future<void> _ver(Sesion s) async {
    if (hayBorrador && !await _confirmarDescarte()) return;
    if (_viendo == null) await _borrarBorrador();
    detenerCronometro();
    setState(() {
      _viendo = s;
      _subjetivo.text = s.subjetivo ?? '';
      _objetivo.text = s.objetivo ?? '';
      _analisis.text = s.analisis ?? '';
      _plan.text = s.plan ?? '';
      _notas.text = s.notasPrivadas ?? '';
      _citaId = s.turnoId;
      _segundos = (s.duracionMinutos ?? 0) * 60 + (s.duracionSegundos ?? 0);
    });
  }

  Future<void> nuevaAtencion() async {
    if (hayBorrador && !await _confirmarDescarte()) return;
    if (_viendo == null) await _borrarBorrador();
    detenerCronometro();
    setState(() {
      _viendo = null;
      for (final c in _campos) {
        c.clear();
      }
      _citaId = null;
      _segundos = 0;
    });
  }

  Future<void> guardar() async {
    if (_viendo != null) {
      Tema.aviso(context, 'Esta atención ya está guardada y no se modifica. Tocá "Nueva atención" para registrar otra.');
      return;
    }
    if (!hayBorrador) {
      Tema.aviso(context, 'La atención está vacía', error: true);
      return;
    }
    detenerCronometro();
    setState(() => _guardando = true);
    try {
      final r = await ApiClient.instancia.post('/api/atenciones', Sesion(
        pacienteId: widget.paciente.id!,
        turnoId: _citaId,
        subjetivo: _subjetivo.text.trim(),
        objetivo: _objetivo.text.trim(),
        analisis: _analisis.text.trim(),
        plan: _plan.text.trim(),
        notasPrivadas: _notas.text.trim(),
        duracionMinutos: _segundos ~/ 60,
        duracionSegundos: _segundos % 60,
      ).toJson());
      await _borrarBorrador();
      if (!mounted) return;
      Tema.aviso(context, r['turnoCompletado'] == true
          ? 'Atención guardada. La cita asociada se marcó como realizada.'
          : 'Atención guardada');
      setState(() {
        for (final c in _campos) {
          c.clear();
        }
        _citaId = null;
        _segundos = 0;
        _guardando = false;
      });
      context.read<Navegacion>().datosCambiados();
      _cargar();
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        Tema.aviso(context, e.toString(), error: true);
      }
    }
  }

  Future<void> exportar() async {
    if (!Descargas.disponible) {
      Tema.aviso(context, 'Exportar está disponible en la versión web (navegador)', error: true);
      return;
    }
    final s = _viendo;
    if (s == null) {
      Tema.aviso(context, hayBorrador
          ? 'Guardá la atención antes de exportar la nota'
          : 'Elegí una atención de la tabla para exportar su nota', error: true);
      return;
    }
    try {
      final a = await ApiClient.instancia.descargar('/api/reportes/nota/${s.id}');
      Descargas.guardar(a.bytes, a.nombre, a.tipo);
      if (mounted) Tema.aviso(context, 'Nota exportada: ${a.nombre} — quedó en Descargas');
      if (mounted) context.read<Navegacion>().datosCambiados();
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    }
  }

  static String _reloj(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _area(String etiqueta, TextEditingController c) {
    final lectura = _viendo != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(etiqueta, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
      const SizedBox(height: 5),
      TextField(
        controller: c,
        readOnly: lectura,
        minLines: 4,
        maxLines: 6,
        onChanged: (_) => setState(() {}),
        decoration: decoracionCampo(context).copyWith(filled: true, fillColor: lectura ? Paleta.de(context).zebra : null),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    final lectura = _viendo != null;
    final cita = DropdownButtonFormField<int?>(
      key: ValueKey('cita_${_viendo?.id}_${_citaId}_${_citas.length}'),
      initialValue: _citas.any((c) => c.id == _citaId) ? _citaId : null,
      isExpanded: true,
      decoration: decoracionCampo(context),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('(Sin cita asociada)')),
        ..._citas.map((c) => DropdownMenuItem<int?>(
            value: c.id, child: Text('${Tema.fechaHora(c.fechaHora)} — ${Tema.etiquetaEstado(c.estado)}', overflow: TextOverflow.ellipsis))),
      ],
      onChanged: lectura ? null : (v) => setState(() => _citaId = v),
    );
    final cronometro = Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('Cronómetro: ', style: TextStyle(fontSize: 14.5)),
      Text(_reloj(_segundos), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: p.primario)),
      const SizedBox(width: 10),
      Boton.exito('Iniciar atención', onPressed: _corriendo || lectura ? null : _iniciar),
      const SizedBox(width: 6),
      Boton.peligro('Pausar', onPressed: _corriendo ? detenerCronometro : null),
    ]);
    final formulario = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_borradorPendiente != null) _avisoBorrador(p),
      if (lectura)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.seleccion, borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 18, color: p.primario),
            const SizedBox(width: 8),
            Expanded(child: Text('Atención del ${Tema.fechaHora(_viendo!.fecha)} · ${_viendo!.duracionTexto()} — solo lectura')),
          ]),
        ),
      if (ancho)
        Row(children: [
          const Text('Cita asociada (opcional):  ', style: TextStyle(fontSize: 14.5)),
          Expanded(child: cita),
          const SizedBox(width: 12),
          cronometro,
        ])
      else ...[
        Campo('Cita asociada (opcional)', cita),
        const SizedBox(height: 10),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: cronometro),
      ],
      const SizedBox(height: 12),
      FilaDoble(_area('Relato del estudiante (Subjetivo)', _subjetivo), _area('Observación profesional (Objetivo)', _objetivo)),
      const SizedBox(height: 12),
      FilaDoble(_area('Análisis de la situación', _analisis), _area('Acuerdos y recomendaciones (Plan)', _plan)),
      const SizedBox(height: 12),
      _area('Seguimiento y notas privadas (uso interno, no forman parte del informe)', _notas),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Boton.exito('Guardar atención', icono: Icons.check, cargando: _guardando, onPressed: lectura ? null : guardar, tooltip: 'Ctrl+S'),
        Boton.primario('Nueva atención', icono: Icons.add, onPressed: nuevaAtencion),
        Boton.primario('Exportar nota', icono: Icons.file_download_outlined, onPressed: exportar, tooltip: 'Ctrl+E'),
      ]),
    ]);

    final q = _buscar.text.trim().toLowerCase();
    final filtradas = _atenciones.where((s) => q.isEmpty || '${s.id} ${Tema.fechaHora(s.fecha)} ${s.psicologoNombre ?? ''}'.toLowerCase().contains(q)).toList();
    final registradas = Tarjeta(
      titulo: 'Atenciones registradas · ${_atenciones.length}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (ancho) const Text('Buscar:  '),
          Expanded(child: TextField(controller: _buscar, onChanged: (_) => setState(() {}),
              decoration: decoracionCampo(context, hint: 'Fecha o profesional', prefijo: const Icon(Icons.search, size: 20)))),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: ancho ? 220 : 280,
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : Tabla<Sesion>(
                  filas: filtradas,
                  seleccionada: _viendo,
                  igual: (a, b) => a.id == b.id,
                  alSeleccionar: _ver,
                  alAbrir: _ver,
                  vacio: 'Todavía no hay atenciones registradas.',
                  columnas: [
                    Columna('ID', (s) => Columna.texto('${s.id}'), flex: 1, ordenarPor: (s) => s.id ?? 0),
                    Columna('Fecha', (s) => Columna.texto(Tema.fechaHora(s.fecha)), flex: 2, ordenarPor: (s) => s.fecha ?? ''),
                    Columna('Duración', (s) => Columna.texto(s.duracionTexto()), flex: 2),
                    Columna('Profesional', (s) => Columna.texto(s.psicologoNombre), flex: 2),
                  ],
                  tarjeta: (s) => Row(children: [
                    Icon(Icons.chat_outlined, color: p.primario),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(Tema.fechaHora(s.fecha), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${s.duracionTexto()} · ${s.psicologoNombre ?? ''}', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                      ]),
                    ),
                  ]),
                ),
        ),
      ]),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(ancho ? 16 : 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Tarjeta(child: formulario),
        const SizedBox(height: 14),
        registradas,
      ]),
    );
  }
}
