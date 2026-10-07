import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/paciente.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/borradores.dart';
import '../../services/descargas.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';
import '../../widgets/linea_de_tiempo.dart';
import '../agenda/formulario_cita.dart';
import 'formulario_estudiante.dart';
import 'pestana_adjuntos.dart';
import 'pestana_atenciones.dart';
import 'pestana_seguimiento.dart';

/// DetallePaciente del escritorio: encabezado con el nombre y las migas "Estudiantes › …", barra
/// Volver a la lista / Editar datos / Adjuntar archivos / Exportar ficha / Nueva cita, y las
/// pestañas Información Personal (datos básicos + línea de tiempo) / Seguimiento del Estudiante /
/// Atenciones / Adjuntos. Salir avisa si hay un borrador de seguimiento o atención sin guardar.
/// Atajos: Ctrl+S guarda y Ctrl+E exporta en la pestaña visible, Ctrl+1…4 cambia de pestaña.
class DetalleEstudiante extends StatefulWidget {
  final int pacienteId;
  final int pestanaInicial;
  const DetalleEstudiante({super.key, required this.pacienteId, this.pestanaInicial = 0});

  @override
  State<DetalleEstudiante> createState() => _DetalleEstudianteState();
}

class _DetalleEstudianteState extends State<DetalleEstudiante> with TickerProviderStateMixin {
  Paciente? _paciente;
  String? _profesional;
  bool _cargando = true;
  String? _error;
  TabController? _tabs;
  int _adjuntos = 0;
  bool _editando = false;
  GlobalKey<FormularioEstudianteState> _claveEditar = GlobalKey();
  final _claveLinea = GlobalKey<LineaDeTiempoState>();
  final _claveSeguimiento = GlobalKey<PestanaSeguimientoState>();
  final _claveAtenciones = GlobalKey<PestanaAtencionesState>();
  final _claveAdjuntos = GlobalKey<PestanaAdjuntosState>();
  late final Navegacion _nav;

  @override
  void initState() {
    super.initState();
    _nav = context.read<Navegacion>()..registrarEscape(_alEscape);
    _cargar();
  }

  @override
  void dispose() {
    _nav.quitarEscape(_alEscape);
    _tabs?.dispose();
    super.dispose();
  }

  bool _alEscape() {
    if (_editando) {
      _claveEditar.currentState?.pedirCierre();
      return true;
    }
    salir();
    return true;
  }

  Future<void> _cargar() async {
    try {
      final data = await ApiClient.instancia.get('/api/pacientes/${widget.pacienteId}');
      final p = Paciente.fromJson(data);
      String? profesional;
      if (p.psicologoId != null) {
        try {
          final ps = await ApiClient.instancia.get('/api/turnos/psicologos') as List;
          profesional = ps.cast<Map<String, dynamic>>().where((e) => e['id'] == p.psicologoId).map((e) => e['nombre'] as String).firstOrNull;
        } catch (_) {}
      }
      if (!mounted) return;
      final cantidad = context.read<AuthService>().esSecretaria ? 1 : 4;
      if (_tabs == null) {
        _tabs = TabController(length: cantidad, vsync: this, initialIndex: widget.pestanaInicial.clamp(0, cantidad - 1));
        _tabs!.addListener(() {
          // Como el escritorio: la línea de tiempo se recarga al volver a Información Personal.
          if (!_tabs!.indexIsChanging && _tabs!.index == 0) _claveLinea.currentState?.recargar();
          setState(() {});
        });
      }
      _nav.registrarReciente(p);
      if (cantidad > 1) {
        try {
          final docs = await ApiClient.instancia.get('/api/estudiantes/${p.id}/documentos') as List;
          _adjuntos = docs.length;
        } catch (_) {}
      }
      if (!mounted) return;
      final primeraCarga = _paciente == null;
      setState(() {
        _paciente = p;
        _profesional = profesional;
        _cargando = false;
        _error = null;
      });
      if (primeraCarga && cantidad > 1) _avisarBorradores();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  /// Si quedó una atención o un seguimiento sin guardar (pestaña cerrada, navegador cerrado…),
  /// se avisa al abrir la ficha y se lleva a la pestaña donde está el aviso para recuperarlo.
  Future<void> _avisarBorradores() async {
    final usuario = context.read<AuthService>().usuarioId ?? 0;
    final atencion = await Borradores.leer(Borradores.claveAtencion(usuario, widget.pacienteId));
    final seguimiento = await Borradores.leer(Borradores.claveSeguimiento(usuario, widget.pacienteId));
    if (!mounted || (atencion == null && seguimiento == null)) return;
    final pestana = atencion != null ? 2 : 1;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(atencion != null
            ? 'Hay una atención de este estudiante que quedó sin guardar.'
            : 'Hay una entrada de seguimiento de este estudiante que quedó sin guardar.'),
        action: SnackBarAction(label: 'Ver', onPressed: () => _tabs?.animateTo(pestana)),
      ));
  }

  bool get _hayBorrador =>
      (_claveSeguimiento.currentState?.hayBorrador ?? false) || (_claveAtenciones.currentState?.hayBorrador ?? false);

  /// Volver a la lista: avisa si queda un borrador (y detiene el cronómetro de la atención).
  Future<void> salir() async {
    if (_hayBorrador) {
      final atencionEnCurso = _claveAtenciones.currentState?.cronometroEnMarcha ?? false;
      final ok = await confirmar(context,
          titulo: 'Hay cambios sin guardar',
          mensaje: atencionEnCurso
              ? 'La atención está en curso (cronómetro en marcha) y no se guardó. Si salís ahora se pierde.'
              : 'Hay una entrada de seguimiento o una atención escrita que no se guardó. Si salís ahora se pierde.',
          accion: 'Salir sin guardar',
          cancelar: 'Seguir editando',
          peligroso: true);
      if (!ok) return;
      // Eligió salir sin guardar: no se ofrece recuperar después lo que descartó a propósito.
      await _claveSeguimiento.currentState?.descartarBorrador();
      await _claveAtenciones.currentState?.descartarBorrador();
    }
    _claveAtenciones.currentState?.detenerCronometro();
    _nav.cerrarFicha();
  }

  Future<void> _exportarFicha() async {
    if (!Descargas.disponible) {
      Tema.aviso(context, 'Exportar está disponible en la versión web (navegador)', error: true);
      return;
    }
    try {
      final a = await ApiClient.instancia.descargar('/api/reportes/ficha/${widget.pacienteId}');
      Descargas.guardar(a.bytes, a.nombre, a.tipo);
      if (mounted) Tema.aviso(context, 'Ficha exportada: ${a.nombre} — quedó en Descargas');
      _nav.datosCambiados();
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    }
  }

  void _atajo(int accion) {
    final i = _tabs?.index ?? 0;
    if (accion == 0) {
      // Ctrl+S
      if (i == 1) _claveSeguimiento.currentState?.guardar();
      if (i == 2) _claveAtenciones.currentState?.guardar();
    } else {
      // Ctrl+E
      if (i == 0) _exportarFicha();
      if (i == 1) _claveSeguimiento.currentState?.exportar();
      if (i == 2) _claveAtenciones.currentState?.exportar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    if (_cargando || _error != null || _paciente == null) {
      return Column(children: [
        Encabezado(titulo: 'Ficha del estudiante', izquierda: flechaAtrasFicha(context, salir)),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : EstadoVacio(icono: Icons.error_outline, titulo: 'No se pudo abrir la ficha', detalle: _error, error: true,
                  accion: 'Volver a la lista', onAccion: () => _nav.cerrarFicha()),
        ),
      ]);
    }
    final e = _paciente!;
    final secretaria = auth.esSecretaria;
    final pestanas = [
      const Pestana('Información Personal', Icons.person),
      if (!secretaria) ...[
        const Pestana('Seguimiento del Estudiante', Icons.folder),
        const Pestana('Atenciones', Icons.chat),
        Pestana(_adjuntos > 0 ? 'Adjuntos ($_adjuntos)' : 'Adjuntos', Icons.folder_copy),
      ],
    ];
    final barra = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (ancho) Boton('Volver a la lista', icono: Icons.arrow_back, onPressed: salir, tooltip: 'Esc'),
      Boton.primario('Editar datos', icono: Icons.edit, onPressed: () => setState(() {
            _editando = true;
            _claveEditar = GlobalKey();
          })),
      if (!secretaria) ...[
        Boton('Adjuntar archivos', icono: Icons.add, soloIcono: !ancho, onPressed: () {
          final yaVisible = _tabs?.index == 3;
          _tabs?.animateTo(3);
          // La pestaña se arma al mostrarse: se espera un instante antes de abrir el selector.
          Future.delayed(Duration(milliseconds: yaVisible ? 0 : 400), () => _claveAdjuntos.currentState?.adjuntar());
        }),
        Boton('Exportar ficha', icono: Icons.file_download_outlined, soloIcono: !ancho, onPressed: _exportarFicha),
      ],
      Boton('Nueva cita', icono: Icons.event_available, soloIcono: !ancho, onPressed: () async {
        await FormularioCita.mostrar(context, paciente: e);
        _claveLinea.currentState?.recargar();
      }),
    ]);

    final contenido = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: EdgeInsets.fromLTRB(ancho ? 22 : 10, 14, ancho ? 22 : 10, 12), child: barra),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: ancho ? 14 : 0),
        child: BarraPestanas(controller: _tabs!, pestanas: pestanas),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _informacion(e, secretaria, ancho, p),
            if (!secretaria) ...[
              PestanaSeguimiento(key: _claveSeguimiento, paciente: e),
              PestanaAtenciones(key: _claveAtenciones, paciente: e),
              PestanaAdjuntos(key: _claveAdjuntos, paciente: e, alCambiarCantidad: (n) {
                if (n != _adjuntos) setState(() => _adjuntos = n);
              }),
            ],
          ],
        ),
      ),
      if (ancho)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(
            secretaria
                ? 'Atajos: Esc vuelve a la lista de estudiantes'
                : 'Atajos: Ctrl+S guarda · Ctrl+E exporta · Ctrl+1…4 cambia de pestaña · Esc vuelve a la lista',
            style: TextStyle(fontSize: 11.5, color: p.textoSecundario),
          ),
        ),
    ]);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () => _atajo(0),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () => _atajo(1),
        for (var i = 0; i < pestanas.length; i++)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () => _tabs?.animateTo(i),
      },
      child: Column(children: [
        Encabezado(
          titulo: e.nombreCompleto,
          subtitulo: 'Estudiantes  ›  ${e.nombreCompleto}${e.curso != null ? '  ·  ${e.curso}' : ''}',
          izquierda: flechaAtrasFicha(context, salir),
        ),
        Expanded(
          child: ConPanelLateral(
            contenido: contenido,
            panel: _editando
                ? Padding(
                    padding: EdgeInsets.all(ancho ? 16 : 0),
                    child: FormularioEstudiante(
                      key: _claveEditar,
                      paciente: e,
                      alCerrar: (guardado) {
                        setState(() => _editando = false);
                        if (guardado != null) {
                          _nav.datosCambiados();
                          _cargar();
                        }
                      },
                    ),
                  )
                : null,
          ),
        ),
      ]),
    );
  }

  Widget _informacion(Paciente e, bool secretaria, bool ancho, Paleta p) {
    final datos = Tarjeta(
      titulo: 'Datos básicos',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _dato(p, 'Nombre Completo', e.nombreCompleto),
        _dato(p, 'Curso', e.curso),
        _dato(p, 'CI', e.ci),
        _dato(p, 'Teléfono', e.telefono),
        _dato(p, 'Género', e.genero),
        if (e.fechaNacimiento != null) _dato(p, 'Fecha de nacimiento', Tema.fecha(e.fechaNacimiento)),
        _dato(p, 'Profesional asignado', _profesional ?? (e.psicologoId == null ? 'Sin profesional asignado' : null)),
        _dato(p, 'Nombre padre/madre/tutor', e.nombreTutor),
        _dato(p, 'CI padre/madre/tutor', e.ciTutor),
        _dato(p, 'Consentimiento del tutor',
            e.consentimientoTutor ? 'Sí (registrado el ${Tema.fechaHora(e.consentimientoFecha)})' : 'No registrado'),
      ]),
    );
    final nota = Padding(
      padding: const EdgeInsets.only(top: 8, right: 4),
      child: Text(
        secretaria
            ? 'Los datos clínicos (seguimiento, atenciones y adjuntos) solo los ve el profesional de psicología.'
            : 'El motivo de la atención, antecedentes y anamnesis se registran en la pestaña "Seguimiento del Estudiante".',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: p.textoSecundario),
      ),
    );
    final linea = Tarjeta(
      titulo: secretaria ? 'Citas del estudiante' : 'Línea de tiempo del caso',
      child: LineaDeTiempo(
        key: _claveLinea,
        pacienteId: e.id!,
        soloCitas: secretaria,
        alTocar: (ev) {
          switch (ev.tipo) {
            case TipoEvento.seguimiento:
              _tabs?.animateTo(1);
              _claveSeguimiento.currentState?.mostrarEntrada(ev.dato);
              break;
            case TipoEvento.atencion:
              _tabs?.animateTo(2);
              _claveAtenciones.currentState?.mostrarAtencion(ev.dato);
              break;
            case TipoEvento.adjunto:
              if (!secretaria) _tabs?.animateTo(3);
              break;
            case TipoEvento.cita:
              _nav.verPestana(PestanaEstudiantes.agenda);
              break;
          }
        },
      ),
    );
    return RefreshIndicator(
      onRefresh: () async {
        await _cargar();
        await _claveLinea.currentState?.recargar();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(ancho ? 16 : 10),
        child: ancho
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [datos, nota])),
                const SizedBox(width: 16),
                Expanded(child: linea),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [datos, nota, const SizedBox(height: 12), linea]),
      ),
    );
  }

  Widget _dato(Paleta p, String etiqueta, String? valor) {
    final vacio = valor == null || valor.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: esAncho(context) ? 190 : 130,
          child: Text('$etiqueta:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: p.primario)),
        ),
        Expanded(
          child: Text(vacio ? 'No especificado' : valor,
              style: TextStyle(fontSize: 13.5, color: vacio ? p.textoSecundario : p.texto, fontStyle: vacio ? FontStyle.italic : null)),
        ),
      ]),
    );
  }
}

Widget? flechaAtrasFicha(BuildContext context, VoidCallback onVolver) =>
    esAncho(context) ? null : BotonBlanco(icono: Icons.arrow_back, tooltip: 'Volver a la lista', onPressed: onVolver);
