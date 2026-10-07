import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../services/descargas.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';
import '../estudiantes/importar_estudiantes.dart';

/// "Reportes y archivos" del escritorio. En la web los archivos se descargan en el dispositivo
/// (no hay carpetas del servidor para abrir): las acciones rápidas exportan la planilla de
/// estudiantes, importan desde Excel y descargan un respaldo de sus datos; "Documentos generados" es el
/// registro de lo exportado, y una ficha o nota se puede volver a descargar.
class ReportesArchivos extends StatefulWidget {
  const ReportesArchivos({super.key});
  @override
  State<ReportesArchivos> createState() => _ReportesArchivosState();
}

class _ReportesArchivosState extends State<ReportesArchivos> {
  List<Map<String, dynamic>> _documentos = [];
  bool _cargando = true;
  String? _error;
  final _busqueda = TextEditingController();
  String _tipo = 'Todos los tipos';
  Map<String, dynamic>? _seleccionado;
  bool _trabajando = false;
  late final Navegacion _nav;
  int _versionVista = -1;

  static const _tipos = {
    'EXPORTAR_ESTUDIANTES': 'Listado de estudiantes',
    'EXPORTAR_FICHA': 'Ficha del estudiante',
    'EXPORTAR_NOTA': 'Nota de atención',
    'EXPORTAR_RESPALDO': 'Respaldo',
  };

  @override
  void initState() {
    super.initState();
    _nav = context.read<Navegacion>()..addListener(_alNavegar);
    _cargar();
  }

  @override
  void dispose() {
    _nav.removeListener(_alNavegar);
    _busqueda.dispose();
    super.dispose();
  }

  void _alNavegar() {
    if (_nav.version != _versionVista) _cargar();
  }

  Future<void> _cargar() async {
    _versionVista = _nav.version;
    try {
      final data = await ApiClient.instancia.get('/api/reportes/historial');
      if (!mounted) return;
      setState(() {
        _documentos = (data as List).cast<Map<String, dynamic>>();
        _cargando = false;
        _error = null;
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

  List<Map<String, dynamic>> get _filtrados {
    final q = _busqueda.text.trim().toLowerCase();
    return _documentos.where((d) {
      if (_tipo != 'Todos los tipos' && _tipos[d['accion']] != _tipo) return false;
      if (q.isEmpty) return true;
      return '${d['detalle'] ?? ''} ${d['usuarioNombre'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _descargar(String ruta, [Map<String, dynamic>? query]) async {
    if (!Descargas.disponible) {
      Tema.aviso(context, 'Descargar archivos está disponible en la versión web (navegador)', error: true);
      return;
    }
    setState(() => _trabajando = true);
    try {
      final a = await ApiClient.instancia.descargar(ruta, query);
      Descargas.guardar(a.bytes, a.nombre, a.tipo);
      if (mounted) Tema.aviso(context, 'Archivo guardado en Descargas: ${a.nombre}');
      _nav.datosCambiados();
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  /// Ficha y nota se pueden volver a generar (con los datos de hoy); el listado se exporta completo.
  VoidCallback? _accionDescargar(Map<String, dynamic>? d) {
    if (d == null || d['entidadId'] == null) return null;
    return switch (d['accion']) {
      'EXPORTAR_FICHA' => () => _descargar('/api/reportes/ficha/${d['entidadId']}'),
      'EXPORTAR_NOTA' => () => _descargar('/api/reportes/nota/${d['entidadId']}'),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    final tarjetas = <Widget>[
      _tarjetaAccion(p, 'Exportar estudiantes', 'Planilla de Excel con todos los estudiantes', Icons.file_download_outlined,
          Tema.exito, () => _descargar('/api/reportes/estudiantes', {'descripcion': 'todos'})),
      _tarjetaAccion(p, 'Importar desde Excel', 'Cargar un curso entero desde una planilla', Icons.upload_file, Tema.secundario,
          () async {
        final n = await ImportarEstudiantes.iniciar(context);
        if (n != null && n > 0) _nav.datosCambiados();
      }),
      _tarjetaAccion(p, 'Ficha o nota', 'Desde la ficha de cada estudiante (Seguimiento / Atenciones)', Icons.description_outlined,
          Tema.ambar, () => _nav.verPestana(PestanaEstudiantes.lista)),
      _tarjetaAccion(p, 'Respaldar mis datos', 'Copia de seguridad de tus estudiantes (planillas en un .zip)', Icons.verified_outlined,
          Tema.rosa, () => _descargar('/api/reportes/respaldo')),
    ];
    return Padding(
      padding: EdgeInsets.all(ancho ? 16 : 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Tarjeta(
          titulo: 'Acciones rápidas',
          child: ancho
              ? Row(children: [for (final t in tarjetas) ...[Expanded(child: t), if (t != tarjetas.last) const SizedBox(width: 12)]])
              : Column(children: [for (final t in tarjetas) Padding(padding: const EdgeInsets.only(bottom: 8), child: t)]),
        ),
        const SizedBox(height: 16),
        Expanded(child: _documentosGenerados(p, ancho)),
        if (ancho)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Los archivos se descargan en la carpeta Descargas de este dispositivo.',
                style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: p.textoSecundario)),
          ),
      ]),
    );
  }

  Widget _tarjetaAccion(Paleta p, String titulo, String detalle, IconData icono, Color color, VoidCallback onTap) {
    return Material(
      color: p.superficie,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _trabajando ? null : onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: p.borde)),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: p.oscuro ? 0.25 : 0.14),
              child: Icon(icono, color: Tema.legible(context, color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: TextStyle(fontWeight: FontWeight.w800, color: p.texto)),
                const SizedBox(height: 4),
                Text(detalle, style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _documentosGenerados(Paleta p, bool ancho) {
    final filtrados = _filtrados;
    final filtros = Row(children: [
      if (ancho) const Text('Buscar:  '),
      Expanded(
        flex: 3,
        child: TextField(
          controller: _busqueda,
          onChanged: (_) => setState(() {}),
          decoration: decoracionCampo(context, hint: 'Nombre del estudiante o del archivo', prefijo: const Icon(Icons.search, size: 20)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: DropdownButtonFormField<String>(
          initialValue: _tipo,
          isExpanded: true,
          decoration: decoracionCampo(context),
          items: ['Todos los tipos', ..._tipos.values]
              .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _tipo = v ?? 'Todos los tipos'),
        ),
      ),
      const SizedBox(width: 8),
      Boton('Actualizar', icono: Icons.refresh, soloIcono: !ancho, onPressed: _cargar),
      if (ancho) ...[const SizedBox(width: 10), Text('${filtrados.length} documentos', style: TextStyle(color: p.textoSecundario))],
    ]);
    Widget cuerpo;
    if (_cargando) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      cuerpo = EstadoVacio(icono: Icons.cloud_off, titulo: 'No se pudo cargar', detalle: _error, error: true, accion: 'Reintentar', onAccion: _cargar);
    } else {
      cuerpo = Tabla<Map<String, dynamic>>(
        filas: filtrados,
        seleccionada: _seleccionado,
        igual: (a, b) => a['id'] == b['id'],
        alSeleccionar: (d) => setState(() => _seleccionado = d),
        alAbrir: (d) => _accionDescargar(d)?.call(),
        vacio: 'Todavía no se generó ningún documento. Exportá una ficha o nota desde la ficha de un estudiante.',
        columnas: [
          Columna('Documento', (d) => Tooltip(message: d['detalle'] ?? '', child: Columna.texto(d['detalle'])), flex: 5),
          Columna('Tipo', (d) => Columna.texto(_tipos[d['accion']] ?? d['accion']), flex: 3, ordenarPor: (d) => d['accion'] ?? ''),
          Columna('Generado por', (d) => Columna.texto(d['usuarioNombre']), flex: 3, ordenarPor: (d) => d['usuarioNombre'] ?? ''),
          Columna('Fecha', (d) => Columna.texto(Tema.fechaHora(d['fecha'])), flex: 2, ordenarPor: (d) => d['fecha'] ?? ''),
        ],
        tarjeta: (d) => Row(children: [
          Icon(Icons.description_outlined, color: p.primario),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['detalle'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${_tipos[d['accion']] ?? ''} · ${Tema.fechaHora(d['fecha'])}',
                  style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
            ]),
          ),
          if (_accionDescargar(d) != null)
            IconButton(tooltip: 'Descargar de nuevo', icon: const Icon(Icons.file_download_outlined), onPressed: _accionDescargar(d)),
        ]),
      );
    }
    return Tarjeta(
      titulo: 'Documentos generados',
      expandir: true,
      padding: EdgeInsets.fromLTRB(ancho ? 18 : 10, 14, ancho ? 18 : 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        filtros,
        const SizedBox(height: 10),
        Expanded(child: cuerpo),
        if (ancho) ...[
          const SizedBox(height: 8),
          Row(children: [
            Boton.primario('Descargar de nuevo', icono: Icons.file_download_outlined, onPressed: _accionDescargar(_seleccionado)),
            const SizedBox(width: 10),
            Text('Doble clic para descargar de nuevo una ficha o nota (con los datos actuales)',
                style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: p.textoSecundario)),
          ]),
        ],
      ]),
    );
  }
}
