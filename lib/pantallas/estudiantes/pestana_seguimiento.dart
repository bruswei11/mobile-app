import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/historia.dart';
import '../../models/paciente.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/borradores.dart';
import '../../services/descargas.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';

/// Pestaña "Seguimiento del Estudiante" del escritorio: formulario en dos columnas (Antecedentes /
/// Motivo de la atención con motivos frecuentes / Observaciones generales / Diagnóstico situacional
/// / Plan de intervención), Clasificación (CIE-10, tipo de acoso, ¿es reiterado?), Guardar / Nueva
/// entrada / Exportar Reporte y la tabla de entradas registradas. Cada Guardar crea una entrada
/// NUEVA; al elegir una entrada de la tabla se muestra en modo solo lectura. Lo escrito se guarda
/// solo como borrador en el dispositivo (cada 5 s) para recuperarlo si se cierra la pestaña.
class PestanaSeguimiento extends StatefulWidget {
  final Paciente paciente;
  const PestanaSeguimiento({super.key, required this.paciente});
  @override
  State<PestanaSeguimiento> createState() => PestanaSeguimientoState();
}

class PestanaSeguimientoState extends State<PestanaSeguimiento> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final _antecedentes = TextEditingController();
  final _motivo = TextEditingController();
  final _observaciones = TextEditingController();
  final _diagnostico = TextEditingController();
  final _plan = TextEditingController();
  final _cie10 = TextEditingController();
  final _buscar = TextEditingController();
  String? _tipoAcoso;
  bool _reiterado = false;

  List<Historia> _entradas = [];
  Historia? _viendo; // entrada guardada que se muestra (solo lectura)
  bool _cargando = true;
  bool _guardando = false;

  Timer? _autoguardado;
  late final String _claveBorrador;
  String? _ultimoBorrador;
  Map<String, dynamic>? _borradorPendiente;
  bool _descartado = false;

  @override
  bool get wantKeepAlive => true;

  List<TextEditingController> get _campos => [_antecedentes, _motivo, _observaciones, _diagnostico, _plan, _cie10];

  bool get hayBorrador => _viendo == null && (_campos.any((c) => c.text.trim().isNotEmpty) || _tipoAcoso != null || _reiterado);

  @override
  void initState() {
    super.initState();
    _claveBorrador = Borradores.claveSeguimiento(context.read<AuthService>().usuarioId ?? 0, widget.paciente.id!);
    WidgetsBinding.instance.addObserver(this);
    _cargar();
    _buscarBorrador();
    _autoguardado = Timer.periodic(const Duration(seconds: 5), (_) => _guardarBorrador());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      _guardarBorrador();
    }
  }

  @override
  void dispose() {
    _autoguardado?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _guardarBorrador();
    for (final c in [..._campos, _buscar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final data = await ApiClient.instancia.get('/api/estudiantes/${widget.paciente.id}/seguimientos');
      if (!mounted) return;
      setState(() {
        _entradas = (data as List).map((e) => Historia.fromJson(e)).toList();
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
        'antecedentes': _antecedentes.text,
        'motivo': _motivo.text,
        'observaciones': _observaciones.text,
        'diagnostico': _diagnostico.text,
        'plan': _plan.text,
        'cie10': _cie10.text,
        'tipoAcoso': _tipoAcoso,
        'reiterado': _reiterado,
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
      _antecedentes.text = b['antecedentes'] ?? '';
      _motivo.text = b['motivo'] ?? '';
      _observaciones.text = b['observaciones'] ?? '';
      _diagnostico.text = b['diagnostico'] ?? '';
      _plan.text = b['plan'] ?? '';
      _cie10.text = b['cie10'] ?? '';
      _tipoAcoso = b['tipoAcoso'] as String?;
      _reiterado = b['reiterado'] == true;
      _borradorPendiente = null;
    });
    Tema.aviso(context, 'Entrada de seguimiento recuperada. Revisala y tocá Guardar.');
  }

  Future<void> _descartarPendiente() async {
    final ok = await confirmar(context,
        titulo: 'Descartar el borrador',
        mensaje: 'Se borra la entrada de seguimiento que había quedado sin guardar. No se puede recuperar después.',
        accion: 'Descartar',
        peligroso: true);
    if (!ok) return;
    await _borrarBorrador();
    if (mounted) setState(() => _borradorPendiente = null);
  }

  Widget _avisoBorrador(Paleta p) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Tema.ambar.withValues(alpha: p.oscuro ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Tema.ambar.withValues(alpha: 0.5)),
        ),
        child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Icon(Icons.restore, color: Tema.legible(context, Tema.ambar)),
          Text('Hay una entrada de seguimiento sin guardar del ${Tema.fechaHora(_borradorPendiente!['guardadoEn'])}.',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Boton.primario('Recuperar', icono: Icons.restore, onPressed: _recuperarBorrador),
          Boton('Descartar', onPressed: _descartarPendiente),
        ]),
      );

  void mostrarEntrada(Object? dato) {
    if (dato is Historia) _ver(dato);
  }

  Future<void> _ver(Historia h) async {
    if (hayBorrador && !await _confirmarDescarte()) return;
    if (_viendo == null) await _borrarBorrador();
    setState(() {
      _viendo = h;
      _antecedentes.text = h.antecedentes ?? '';
      _motivo.text = h.motivoConsulta ?? '';
      _observaciones.text = h.observacionesGenerales ?? '';
      _diagnostico.text = h.diagnostico ?? '';
      _plan.text = h.tratamiento ?? '';
      _cie10.text = h.codigoCie10 ?? '';
      _tipoAcoso = h.tipoAcoso;
      _reiterado = h.esReiterado;
    });
  }

  Future<bool> _confirmarDescarte() => confirmar(context,
      titulo: 'Descartar la entrada',
      mensaje: 'La entrada de seguimiento que estás escribiendo no se guardó. Si seguís, se pierde.',
      accion: 'Descartar',
      cancelar: 'Seguir editando',
      peligroso: true);

  Future<void> nuevaEntrada() async {
    if (hayBorrador && !await _confirmarDescarte()) return;
    if (_viendo == null) await _borrarBorrador();
    setState(() {
      _viendo = null;
      for (final c in _campos) {
        c.clear();
      }
      _tipoAcoso = null;
      _reiterado = false;
    });
  }

  Future<void> guardar() async {
    if (_viendo != null) {
      Tema.aviso(context, 'Esta entrada ya está guardada y no se modifica. Tocá "Nueva entrada" para escribir otra.');
      return;
    }
    if (!hayBorrador) {
      Tema.aviso(context, 'La entrada está vacía', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await ApiClient.instancia.post('/api/seguimientos', Historia(
        pacienteId: widget.paciente.id!,
        antecedentes: _antecedentes.text.trim(),
        motivoConsulta: _motivo.text.trim(),
        observacionesGenerales: _observaciones.text.trim(),
        diagnostico: _diagnostico.text.trim(),
        tratamiento: _plan.text.trim(),
        codigoCie10: _cie10.text.trim().isEmpty ? null : _cie10.text.trim().toUpperCase(),
        tipoAcoso: _tipoAcoso,
        esReiterado: _reiterado,
      ).toJson());
      await _borrarBorrador();
      if (!mounted) return;
      Tema.aviso(context, 'Entrada de seguimiento guardada');
      setState(() {
        for (final c in _campos) {
          c.clear();
        }
        _tipoAcoso = null;
        _reiterado = false;
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
    if (hayBorrador) {
      Tema.aviso(context, 'Guardá la entrada antes de exportar: el reporte usa la última entrada guardada', error: true);
      return;
    }
    try {
      final a = await ApiClient.instancia.descargar('/api/reportes/ficha/${widget.paciente.id}');
      Descargas.guardar(a.bytes, a.nombre, a.tipo);
      if (mounted) Tema.aviso(context, 'Reporte exportado: ${a.nombre} — quedó en Descargas');
      if (mounted) context.read<Navegacion>().datosCambiados();
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    }
  }

  Widget _area(String etiqueta, TextEditingController c, {Widget? encima}) {
    final soloLectura = _viendo != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(etiqueta, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
      const SizedBox(height: 5),
      ?encima,
      TextField(
        controller: c,
        readOnly: soloLectura,
        minLines: 4,
        maxLines: 6,
        onChanged: (_) => setState(() {}),
        decoration: decoracionCampo(context).copyWith(filled: true, fillColor: soloLectura ? Paleta.de(context).zebra : null),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    final soloLectura = _viendo != null;
    final motivos = DropdownButtonFormField<String>(
      initialValue: null,
      isExpanded: true,
      hint: const Text('Seleccionar un motivo frecuente…'),
      decoration: decoracionCampo(context),
      items: motivosFrecuentes.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: soloLectura
          ? null
          : (v) {
              if (v == null) return;
              // Como el escritorio: se agrega al texto (una línea por motivo), no lo reemplaza.
              setState(() => _motivo.text = _motivo.text.trim().isEmpty ? v : '${_motivo.text.trim()}\n$v');
            },
    );
    final formulario = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_borradorPendiente != null) _avisoBorrador(p),
      if (soloLectura)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.seleccion, borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 18, color: p.primario),
            const SizedBox(width: 8),
            Expanded(child: Text('Entrada del ${Tema.fechaHora(_viendo!.fechaCreacion)} · ${_viendo!.psicologoNombre ?? ''} — solo lectura')),
          ]),
        ),
      FilaDoble(_area('Antecedentes', _antecedentes), _area('Motivo de la atención', _motivo, encima: Padding(padding: const EdgeInsets.only(bottom: 6), child: motivos))),
      const SizedBox(height: 12),
      FilaDoble(_area('Observaciones generales', _observaciones), _area('Diagnóstico situacional', _diagnostico)),
      const SizedBox(height: 12),
      FilaDoble(_area('Plan de intervención', _plan), const SizedBox()),
      const SizedBox(height: 14),
      Text('Clasificación (opcional)', style: TextStyle(fontWeight: FontWeight.w800, color: p.primario)),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Código CIE-10: '),
          SizedBox(
            width: 120,
            child: TextField(controller: _cie10, readOnly: soloLectura, onChanged: (_) => setState(() {}),
                decoration: decoracionCampo(context, hint: 'Ej. Z55')),
          ),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Tipo de acoso: '),
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('acoso_${_viendo?.id}_$_tipoAcoso'),
              initialValue: _tipoAcoso,
              isExpanded: true,
              decoration: decoracionCampo(context),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('No aplica')),
                ...tiposAcoso.entries.map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
              ],
              onChanged: soloLectura ? null : (v) => setState(() => _tipoAcoso = v),
            ),
          ),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Checkbox(value: _reiterado, onChanged: soloLectura ? null : (v) => setState(() => _reiterado = v ?? false)),
          const Text('¿Es reiterado? (Ley 4633/2012)'),
        ]),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Boton.exito('Guardar', icono: Icons.check, cargando: _guardando, onPressed: soloLectura ? null : guardar, tooltip: 'Ctrl+S'),
        Boton.primario('Nueva entrada', icono: Icons.add, onPressed: nuevaEntrada),
        Boton.primario('Exportar Reporte', icono: Icons.file_download_outlined, onPressed: exportar, tooltip: 'Ctrl+E'),
      ]),
    ]);

    final q = _buscar.text.trim().toLowerCase();
    final filtradas = _entradas
        .where((h) => q.isEmpty || '${Tema.fechaHora(h.fechaCreacion)} ${h.psicologoNombre ?? ''} ${h.motivoConsulta ?? ''}'.toLowerCase().contains(q))
        .toList();
    final registradas = Tarjeta(
      titulo: 'Entradas de seguimiento registradas · ${_entradas.length}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (ancho) const Text('Buscar:  '),
          Expanded(child: TextField(controller: _buscar, onChanged: (_) => setState(() {}),
              decoration: decoracionCampo(context, hint: 'Fecha, profesional o motivo', prefijo: const Icon(Icons.search, size: 20)))),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: ancho ? 220 : 280,
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : Tabla<Historia>(
                  filas: filtradas,
                  seleccionada: _viendo,
                  igual: (a, b) => a.id == b.id,
                  alSeleccionar: _ver,
                  alAbrir: _ver,
                  vacio: 'Todavía no hay entradas de seguimiento.',
                  columnas: [
                    Columna('ID', (h) => Columna.texto('${h.id}'), flex: 1, ordenarPor: (h) => h.id ?? 0),
                    Columna('Fecha', (h) => Columna.texto(Tema.fechaHora(h.fechaCreacion)), flex: 2, ordenarPor: (h) => h.fechaCreacion ?? ''),
                    Columna('Profesional', (h) => Columna.texto(h.psicologoNombre), flex: 2),
                    Columna('Motivo', (h) => Columna.texto((h.motivoConsulta ?? '').split('\n').first), flex: 3),
                    Columna('Reiterado', (h) => Columna.texto(h.esReiterado ? 'Sí' : 'No'), flex: 1),
                  ],
                  tarjeta: (h) => Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((h.motivoConsulta ?? '').trim().isEmpty ? 'Sin motivo especificado' : h.motivoConsulta!.split('\n').first,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${Tema.fechaHora(h.fechaCreacion)} · ${h.psicologoNombre ?? ''}',
                            style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                      ]),
                    ),
                    if (h.esReiterado) const Pastilla(texto: 'Reiterado', color: Tema.peligro),
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
