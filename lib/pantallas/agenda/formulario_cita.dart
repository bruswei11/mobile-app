import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/paciente.dart';
import '../../models/turno.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';

/// Formulario de cita del panel lateral de Agenda: estudiante, profesional, fecha y hora (45 min),
/// estado y notas; aviso de superposición con "Guardar igual" y aviso antes de descartar.
class FormularioCita extends StatefulWidget {
  final Turno? turno;
  final Paciente? paciente;
  final DateTime? diaInicial;
  final void Function(bool guardado) alCerrar;
  final bool enHoja;

  const FormularioCita({super.key, this.turno, this.paciente, this.diaInicial, required this.alCerrar, this.enHoja = false});

  /// Nueva cita desde fuera de la Agenda (ficha, lista, Inicio): el mismo formulario en una hoja.
  static Future<void> mostrar(BuildContext context, {Paciente? paciente}) async {
    final nav = context.read<Navegacion>();
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
      pageBuilder: (ctx, _, _) => SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(esAncho(ctx) ? 24 : 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 520, maxHeight: esAncho(ctx) ? 720 : double.infinity),
              child: Material(
                borderRadius: BorderRadius.circular(esAncho(ctx) ? 10 : 0),
                clipBehavior: Clip.antiAlias,
                child: FormularioCita(
                  paciente: paciente,
                  enHoja: true,
                  alCerrar: (guardado) {
                    Navigator.pop(ctx);
                    if (guardado) nav.datosCambiados();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<FormularioCita> createState() => FormularioCitaState();
}

class FormularioCitaState extends State<FormularioCita> {
  List<Paciente> _estudiantes = [];
  Paciente? _estudiante;
  final _busqueda = TextEditingController();
  List<Psicologo> _psicologos = [];
  int? _psicologoId;
  late DateTime _fecha;
  TimeOfDay _hora = const TimeOfDay(hour: 8, minute: 0);
  String _estado = 'programado';
  final _notas = TextEditingController();
  bool _modificado = false;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.turno != null;

  @override
  void initState() {
    super.initState();
    final manana = DateTime.now().add(const Duration(days: 1));
    _fecha = widget.diaInicial ?? DateTime(manana.year, manana.month, manana.day);
    final t = widget.turno;
    if (t != null) {
      _psicologoId = t.psicologoId;
      _estado = t.estado;
      _notas.text = t.notas ?? '';
      _fecha = DateTime(t.fecha.year, t.fecha.month, t.fecha.day);
      _hora = TimeOfDay(hour: t.fecha.hour, minute: t.fecha.minute);
      _estudiante = Paciente(id: t.pacienteId, nombre: t.pacienteNombre ?? '', apellido: '', curso: t.curso);
    } else if (widget.paciente != null) {
      _estudiante = widget.paciente;
      _psicologoId = widget.paciente!.psicologoId;
    }
    _notas.addListener(() => _modificado = true);
    final auth = context.read<AuthService>();
    if (auth.esPsicologo) _psicologoId = auth.usuarioId;
    _cargar(auth);
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargar(AuthService auth) async {
    try {
      final est = await ApiClient.instancia.get('/api/pacientes') as List;
      final ps = auth.esPsicologo ? <dynamic>[] : await ApiClient.instancia.get('/api/turnos/psicologos') as List;
      if (!mounted) return;
      setState(() {
        _estudiantes = est.map((e) => Paciente.fromJson(e)).toList()
          ..sort((a, b) => a.nombreCompleto.toLowerCase().compareTo(b.nombreCompleto.toLowerCase()));
        _psicologos = ps.map((e) => Psicologo.fromJson(e)).toList();
      });
    } catch (_) {}
  }

  Future<bool> pedirCierre() async {
    if (!_modificado) {
      widget.alCerrar(false);
      return true;
    }
    final ok = await confirmar(context,
        titulo: 'Descartar cambios',
        mensaje: 'La cita tiene cambios sin guardar. Si cerrás el formulario se pierden.',
        accion: 'Descartar',
        cancelar: 'Seguir editando',
        peligroso: true);
    if (ok) widget.alCerrar(false);
    return ok;
  }

  DateTime get _fechaHora => DateTime(_fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);

  Future<void> _guardar({bool forzar = false}) async {
    if (_estudiante?.id == null) {
      setState(() => _error = 'Elegí un estudiante');
      return;
    }
    if (_psicologoId == null) {
      setState(() => _error = 'Elegí el profesional de psicología');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final body = {
      'pacienteId': _estudiante!.id,
      'psicologoId': _psicologoId,
      'fechaHora': Tema.isoLocal(_fechaHora),
      'estado': _estado,
      'notas': _notas.text.trim(),
    };
    try {
      if (_esEdicion) {
        await ApiClient.instancia.put('/api/turnos/${widget.turno!.id}', body, {'forzar': forzar});
      } else {
        await ApiClient.instancia.post('/api/turnos', body, {'forzar': forzar});
      }
      if (!mounted) return;
      Tema.aviso(context, _esEdicion ? 'Cita actualizada' : 'Cita agendada para el ${Tema.fecha(Tema.isoFecha(_fecha))} a las ${Tema.hora(_fechaHora)}');
      widget.alCerrar(true);
    } on ApiException catch (e) {
      if (e.statusCode == 409 && !forzar) {
        setState(() => _guardando = false);
        if (!mounted) return;
        final ok = await confirmar(context,
            titulo: 'Citas superpuestas', mensaje: '${e.mensaje}.\n\n¿Guardar de todos modos?', accion: 'Guardar igual');
        if (ok) await _guardar(forzar: true);
      } else {
        setState(() {
          _error = e.mensaje;
          _guardando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _guardando = false;
      });
    }
  }

  Widget _selectorEstudiante() {
    if (_esEdicion || widget.paciente != null) {
      return InputDecorator(
        decoration: decoracionCampo(context),
        child: Text('${_estudiante?.nombreCompleto.trim() ?? ''}${_estudiante?.curso != null ? ' — ${_estudiante!.curso}' : ''}',
            overflow: TextOverflow.ellipsis),
      );
    }
    return Autocomplete<Paciente>(
      displayStringForOption: (p) => '${p.nombreCompleto}${p.curso != null ? ' — ${p.curso}' : ''}',
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return _estudiantes.take(30);
        return _estudiantes.where((p) => '${p.nombre} ${p.apellido} ${p.ci ?? ''}'.toLowerCase().contains(q)).take(30);
      },
      onSelected: (p) => setState(() {
        _estudiante = p;
        _modificado = true;
        if (!context.read<AuthService>().esPsicologo && p.psicologoId != null) _psicologoId = p.psicologoId;
      }),
      fieldViewBuilder: (ctx, ctrl, foco, alEnviar) => TextField(
        controller: ctrl,
        focusNode: foco,
        onSubmitted: (_) => alEnviar(),
        onChanged: (_) {
          if (_estudiante != null) setState(() => _estudiante = null);
        },
        decoration: decoracionCampo(ctx, hint: 'Escribí nombre o CI y elegí de la lista', prefijo: const Icon(Icons.search, size: 20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final p = Paleta.de(context);
    final pasado = _fechaHora.isBefore(DateTime.now()) && _estado == 'programado';
    return PanelLateral(
      titulo: _esEdicion ? 'Cita del ${Tema.fecha(Tema.isoFecha(_fecha))} a las ${Tema.hora(_fechaHora)}' : 'Nueva cita',
      subtitulo: _esEdicion ? 'Cambiá lo que haga falta y tocá Guardar' : 'Completá los datos y tocá Guardar',
      onCerrar: pedirCierre,
      cuerpo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Campo('Estudiante*', _selectorEstudiante()),
        const SizedBox(height: 14),
        Campo('Profesional de Psicología*', auth.esPsicologo
            ? InputDecorator(decoration: decoracionCampo(context), child: Text(auth.nombre ?? ''))
            : DropdownButtonFormField<int>(
                key: ValueKey('ps_${_psicologos.length}_$_psicologoId'),
                initialValue: _psicologos.any((x) => x.id == _psicologoId) ? _psicologoId : null,
                isExpanded: true,
                decoration: decoracionCampo(context),
                items: _psicologos.map((x) => DropdownMenuItem(value: x.id, child: Text(x.nombre))).toList(),
                onChanged: (v) => setState(() {
                  _psicologoId = v;
                  _modificado = true;
                }),
              )),
        const SizedBox(height: 14),
        Campo('Fecha y hora*', Row(children: [
          Expanded(
            child: InputDecorator(
              decoration: decoracionCampo(context),
              child: Text('${Tema.fecha(Tema.isoFecha(_fecha))}  ${Tema.hora(_fechaHora)}'),
            ),
          ),
          const SizedBox(width: 8),
          Boton('Elegir…', icono: Icons.calendar_month, onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _fecha,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (d == null || !context.mounted) return;
            final h = await showTimePicker(
              context: context,
              initialTime: _hora,
              builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
            );
            setState(() {
              _fecha = d;
              if (h != null) _hora = h;
              _modificado = true;
            });
          }),
        ])),
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('${Tema.diaLegible(_fechaHora)} · ${Tema.hora(_fechaHora)} a ${Tema.hora(_fechaHora.add(const Duration(minutes: 45)))} (45 min)',
              style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
        ),
        if (pasado)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('La fecha ya pasó: al abrir la agenda, una cita "Programada" de un día anterior se marca como "No asistió".',
                style: TextStyle(fontSize: 12, color: Tema.legible(context, Tema.ambar))),
          ),
        const SizedBox(height: 14),
        Campo('Estado', DropdownButtonFormField<String>(
          initialValue: _estado,
          decoration: decoracionCampo(context),
          items: const ['programado', 'completado', 'cancelado', 'ausente']
              .map((e) => DropdownMenuItem(value: e, child: Text(Tema.etiquetaEstado(e))))
              .toList(),
          onChanged: (v) => setState(() {
            _estado = v ?? 'programado';
            _modificado = true;
          }),
        )),
        const SizedBox(height: 14),
        Campo('Notas', TextField(controller: _notas, maxLines: 3, minLines: 2, decoration: decoracionCampo(context))),
      ]),
      pie: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: Tema.peligro, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        Wrap(spacing: 8, children: [
          Boton.exito('Guardar', icono: Icons.check, cargando: _guardando, onPressed: () => _guardar()),
          Boton('Cancelar', onPressed: _guardando ? null : pedirCierre),
        ]),
      ]),
    );
  }
}
