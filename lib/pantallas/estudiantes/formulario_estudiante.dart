import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/paciente.dart';
import '../../models/turno.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';
import '../../widgets/selector_curso.dart';

/// Panel lateral "Nuevo / Editar estudiante" de GestionPacientes: tres secciones numeradas, barra
/// "Datos completos: n de 7", validación en el momento, "Guardar y agregar otro" y aviso antes de
/// descartar cambios. [pedirCierre] (vía GlobalKey) lo usa quien lo contiene para Esc/cambiar de fila.
class FormularioEstudiante extends StatefulWidget {
  final Paciente? paciente;
  final void Function(int? idGuardado) alCerrar;
  const FormularioEstudiante({super.key, this.paciente, required this.alCerrar});

  @override
  State<FormularioEstudiante> createState() => FormularioEstudianteState();
}

class FormularioEstudianteState extends State<FormularioEstudiante> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _ci = TextEditingController();
  final _telefono = TextEditingController();
  final _nombreTutor = TextEditingController();
  final _ciTutor = TextEditingController();
  String _genero = 'Masculino';
  String? _curso;
  bool _cursoIncompleto = false;
  int? _profesionalId;
  List<Psicologo> _profesionales = [];
  bool _consentimiento = false;

  bool _cargando = false;
  bool _modificado = false;
  bool _guardando = false;
  int? _ultimoGuardado;
  String? _error;
  int _version = 0;

  bool get _esEdicion => widget.paciente?.id != null;

  @override
  void initState() {
    super.initState();
    _llenar(widget.paciente);
    for (final c in [_nombre, _apellido, _ci, _telefono, _nombreTutor, _ciTutor]) {
      c.addListener(_alModificar);
    }
    if (!context.read<AuthService>().esPsicologo) _cargarProfesionales();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _ci, _telefono, _nombreTutor, _ciTutor]) {
      c.dispose();
    }
    super.dispose();
  }

  void _llenar(Paciente? p) {
    _cargando = true;
    _nombre.text = p?.nombre ?? '';
    _apellido.text = p?.apellido ?? '';
    _ci.text = p?.ci ?? '';
    _telefono.text = p?.telefono ?? '';
    _nombreTutor.text = p?.nombreTutor ?? '';
    _ciTutor.text = p?.ciTutor ?? '';
    final g = p?.genero;
    _genero = (g == 'Masculino' || g == 'Femenino' || g == 'Otro') ? g! : (p == null ? 'Masculino' : 'Otro');
    _curso = p?.curso;
    _cursoIncompleto = false;
    _profesionalId = p?.psicologoId;
    _consentimiento = p?.consentimientoTutor ?? false;
    _modificado = false;
    _cargando = false;
  }

  Future<void> _cargarProfesionales() async {
    try {
      final data = await ApiClient.instancia.get('/api/turnos/psicologos');
      if (mounted) setState(() => _profesionales = (data as List).map((e) => Psicologo.fromJson(e)).toList());
    } catch (_) {}
  }

  void _alModificar() {
    if (_cargando) return;
    setState(() => _modificado = true);
  }

  /// true si se puede cerrar (no había cambios o el usuario aceptó descartarlos).
  Future<bool> pedirCierre() async {
    if (!_modificado) {
      widget.alCerrar(_ultimoGuardado);
      return true;
    }
    final ok = await confirmar(context,
        titulo: 'Descartar cambios',
        mensaje: 'Hay datos sin guardar en el formulario. Si lo cerrás se pierden.',
        accion: 'Descartar',
        cancelar: 'Seguir editando',
        peligroso: true);
    if (ok) widget.alCerrar(_ultimoGuardado);
    return ok;
  }

  (int, int) get _completitud {
    final campos = [_nombre, _apellido, _ci, _telefono, _nombreTutor, _ciTutor];
    return (campos.where((c) => c.text.trim().isNotEmpty).length + (_consentimiento ? 1 : 0), campos.length + 1);
  }

  static String? _texto(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar({bool otro = false}) async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Revisá los campos marcados en rojo');
      return;
    }
    if (_cursoIncompleto) {
      setState(() => _error = 'Completá la selección del curso (o elegí "Sin curso")');
      return;
    }
    setState(() => _guardando = true);
    final auth = context.read<AuthService>();
    final base = widget.paciente;
    final datos = Paciente(
      id: base?.id,
      nombre: _nombre.text.trim(),
      apellido: _apellido.text.trim(),
      ci: _texto(_ci),
      telefono: _texto(_telefono),
      fechaNacimiento: base?.fechaNacimiento,
      genero: _genero,
      curso: _curso,
      nombreTutor: _texto(_nombreTutor),
      ciTutor: _texto(_ciTutor),
      consentimientoTutor: _consentimiento,
      psicologoId: auth.esPsicologo ? auth.usuarioId : _profesionalId,
    );
    try {
      final resp = _esEdicion
          ? await ApiClient.instancia.put('/api/pacientes/${base!.id}', datos.toJson())
          : await ApiClient.instancia.post('/api/pacientes', datos.toJson());
      if (!mounted) return;
      _ultimoGuardado = resp is Map ? resp['id'] as int? : null;
      if (otro) {
        final curso = _curso;
        final profesional = _profesionalId;
        _formKey.currentState!.reset();
        setState(() {
          _llenar(null);
          _curso = curso;
          _profesionalId = profesional;
          _guardando = false;
          _version++;
        });
        Tema.aviso(context, 'Estudiante guardado. Podés cargar el siguiente.');
      } else {
        Tema.aviso(context, _esEdicion ? 'Estudiante actualizado exitosamente' : 'Estudiante registrado exitosamente');
        widget.alCerrar(_ultimoGuardado);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _guardando = false;
        });
      }
    }
  }

  Widget _tituloSeccion(String numero, String texto) {
    final p = Paleta.de(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(children: [
        CircleAvatar(radius: 12, backgroundColor: p.primario,
            child: Text(numero, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold))),
        const SizedBox(width: 9),
        Text(texto, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.texto)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final p = Paleta.de(context);
    final (completos, total) = _completitud;
    final fraccion = completos / total;

    return PanelLateral(
      titulo: _esEdicion ? 'Editar estudiante' : 'Nuevo estudiante',
      subtitulo: _esEdicion
          ? '${widget.paciente!.nombreCompleto} · los cambios se aplican al tocar Guardar'
          : 'Completá los datos y tocá Guardar',
      onCerrar: pedirCierre,
      debajoDelTitulo: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraccion,
            minHeight: 6,
            color: fraccion >= 1 ? Tema.exito : p.primario,
            backgroundColor: p.bordeSuave,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          completos == total ? 'Todos los datos completos' : 'Datos completos: $completos de $total  ·  obligatorios: nombre y apellido',
          style: TextStyle(fontSize: 12, color: p.textoSecundario),
        ),
      ]),
      cuerpo: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tituloSeccion('1', 'Datos del estudiante'),
            FilaDoble(
              Campo('Nombre *', TextFormField(
                controller: _nombre,
                autofocus: esAncho(context),
                textCapitalization: TextCapitalization.words,
                decoration: decoracionCampo(context),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              )),
              Campo('Apellido *', TextFormField(
                controller: _apellido,
                textCapitalization: TextCapitalization.words,
                decoration: decoracionCampo(context),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El apellido es obligatorio' : null,
              )),
              siempre: true,
            ),
            const SizedBox(height: 12),
            FilaDoble(
              Campo('CI', TextFormField(
                controller: _ci,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: decoracionCampo(context, hint: 'Solo números'),
              )),
              Campo('Teléfono', TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-]'))],
                decoration: decoracionCampo(context),
              )),
              siempre: true,
            ),
            const SizedBox(height: 12),
            FilaDoble(
              Campo('Género', DropdownButtonFormField<String>(
                initialValue: _genero,
                key: ValueKey('genero_$_version'),
                decoration: decoracionCampo(context),
                items: const ['Masculino', 'Femenino', 'Otro'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() {
                  _genero = v ?? 'Otro';
                  _modificado = true;
                }),
              )),
              Campo('Profesional asignado', auth.esPsicologo
                  ? Tooltip(
                      message: 'Los estudiantes que cargás quedan asignados a vos',
                      child: InputDecorator(decoration: decoracionCampo(context), child: Text(auth.nombre ?? '')),
                    )
                  : DropdownButtonFormField<int?>(
                      key: ValueKey('prof_${_profesionales.length}_$_version'),
                      initialValue: _profesionales.any((x) => x.id == _profesionalId) ? _profesionalId : null,
                      isExpanded: true,
                      decoration: decoracionCampo(context),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Sin asignar')),
                        ..._profesionales.map((x) => DropdownMenuItem<int?>(value: x.id, child: Text(x.nombre))),
                      ],
                      onChanged: (v) => setState(() {
                        _profesionalId = v;
                        _modificado = true;
                      }),
                    )),
              siempre: true,
            ),
            const SizedBox(height: 18),
            _tituloSeccion('2', 'Curso y sección'),
            SelectorCurso(
              key: ValueKey('curso_$_version'),
              inicial: _curso,
              alCambiar: (etiqueta, incompleto) => setState(() {
                _curso = etiqueta;
                _cursoIncompleto = incompleto;
                _modificado = true;
              }),
            ),
            const SizedBox(height: 18),
            _tituloSeccion('3', 'Padre, madre o tutor'),
            Campo('Nombre completo', TextFormField(
              controller: _nombreTutor,
              textCapitalization: TextCapitalization.words,
              decoration: decoracionCampo(context),
            )),
            const SizedBox(height: 12),
            FilaDoble(
              Campo('CI', TextFormField(
                controller: _ciTutor,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: decoracionCampo(context, hint: 'Solo números'),
              )),
              const SizedBox(),
              siempre: true,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consentimiento,
              onChanged: (v) => setState(() {
                _consentimiento = v ?? false;
                _modificado = true;
              }),
              title: const Text.rich(TextSpan(children: [
                TextSpan(text: 'El padre, madre o tutor '),
                TextSpan(text: 'autorizó', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' el seguimiento psicológico del estudiante'),
              ])),
              subtitle: _esEdicion && widget.paciente!.consentimientoFecha != null && _consentimiento
                  ? Text('Registrado el ${Tema.fechaHora(widget.paciente!.consentimientoFecha)}')
                  : null,
            ),
          ],
        ),
      ),
      pie: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: Tema.peligro, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Boton.exito('Guardar', icono: Icons.check, cargando: _guardando, onPressed: () => _guardar()),
          if (!_esEdicion)
            Boton('Guardar y agregar otro', icono: Icons.add, onPressed: _guardando ? null : () => _guardar(otro: true)),
          Boton('Cancelar', onPressed: _guardando ? null : pedirCierre),
        ]),
      ]),
    );
  }
}
