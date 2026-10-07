import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/paciente.dart';
import '../../services/api_client.dart';
import '../../services/descargas.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';

/// Pestaña "Adjuntos" del escritorio: tabla Archivo / Subido por / Fecha con Adjuntar archivos
/// (varios a la vez) / Abrir / Descargar / Eliminar. Imágenes y PDF se abren en una pestaña del
/// navegador; el resto se descarga.
class PestanaAdjuntos extends StatefulWidget {
  final Paciente paciente;
  final ValueChanged<int> alCambiarCantidad;
  const PestanaAdjuntos({super.key, required this.paciente, required this.alCambiarCantidad});
  @override
  State<PestanaAdjuntos> createState() => PestanaAdjuntosState();
}

class PestanaAdjuntosState extends State<PestanaAdjuntos> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _documentos = [];
  Map<String, dynamic>? _seleccionado;
  bool _cargando = true;
  String? _subiendo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await ApiClient.instancia.get('/api/estudiantes/${widget.paciente.id}/documentos');
      if (!mounted) return;
      setState(() {
        _documentos = (data as List).cast<Map<String, dynamic>>();
        _cargando = false;
        if (_seleccionado != null) _seleccionado = _documentos.where((d) => d['id'] == _seleccionado!['id']).firstOrNull;
      });
      widget.alCambiarCantidad(_documentos.length);
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        Tema.aviso(context, e.toString(), error: true);
      }
    }
  }

  Future<void> adjuntar() async {
    final archivos = await FilePicker.pickFiles();
    if (archivos.isEmpty || !mounted) return;
    var subidos = 0;
    for (final a in archivos) {
      setState(() => _subiendo = a.name);
      try {
        final tam = await a.length() ?? 0;
        if (tam > 25 * 1024 * 1024) {
          if (mounted) Tema.aviso(context, '"${a.name}" supera los 25 MB y no se adjuntó', error: true);
          continue;
        }
        await ApiClient.instancia.subir('/api/estudiantes/${widget.paciente.id}/documentos', await a.readAsBytes(), a.name);
        subidos++;
      } catch (e) {
        if (mounted) Tema.aviso(context, 'No se pudo adjuntar "${a.name}": $e', error: true);
      }
    }
    if (!mounted) return;
    setState(() => _subiendo = null);
    if (subidos > 0) {
      Tema.aviso(context, subidos == 1 ? 'Archivo adjuntado' : '$subidos archivos adjuntados');
      context.read<Navegacion>().datosCambiados();
    }
    _cargar();
  }

  Future<void> _abrir(Map<String, dynamic>? d, {bool descargar = false}) async {
    if (d == null) return;
    if (!Descargas.disponible) {
      Tema.aviso(context, 'Abrir adjuntos está disponible en la versión web (navegador)', error: true);
      return;
    }
    try {
      final a = await ApiClient.instancia.descargar('/api/documentos/${d['id']}/descargar', {'ver': !descargar});
      descargar ? Descargas.guardar(a.bytes, a.nombre, a.tipo) : Descargas.abrir(a.bytes, a.nombre, a.tipo);
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    }
  }

  Future<void> _eliminar(Map<String, dynamic>? d) async {
    if (d == null) return;
    final ok = await confirmar(context,
        titulo: 'Eliminar adjunto',
        mensaje: '¿Eliminar "${d['nombreArchivo']}"? El archivo se borra del sistema.',
        accion: 'Eliminar',
        peligroso: true);
    if (!ok) return;
    try {
      await ApiClient.instancia.delete('/api/documentos/${d['id']}');
      if (!mounted) return;
      Tema.aviso(context, 'Adjunto eliminado');
      setState(() => _seleccionado = null);
      context.read<Navegacion>().datosCambiados();
      _cargar();
    } catch (e) {
      if (mounted) Tema.aviso(context, e.toString(), error: true);
    }
  }

  static IconData _icono(String? nombre) {
    final ext = (nombre ?? '').split('.').last.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext)) return Icons.image_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['doc', 'docx', 'odt', 'txt'].contains(ext)) return Icons.description_outlined;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    final hay = _seleccionado != null;
    return Padding(
      padding: EdgeInsets.all(ancho ? 16 : 10),
      child: Tarjeta(
        titulo: 'Archivos adjuntos (imágenes, artículos, documentos del caso)',
        expandir: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_subiendo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(child: Text('Subiendo "$_subiendo"…', overflow: TextOverflow.ellipsis)),
              ]),
            ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : Tabla<Map<String, dynamic>>(
                    filas: _documentos,
                    seleccionada: _seleccionado,
                    igual: (a, b) => a['id'] == b['id'],
                    alSeleccionar: (d) => setState(() => _seleccionado = d),
                    alAbrir: (d) => _abrir(d),
                    alMenu: (d, pos) {
                      setState(() => _seleccionado = d);
                      mostrarMenu(context, pos, [
                        ('Abrir', Icons.open_in_new, () => _abrir(d), false),
                        ('Descargar', Icons.file_download_outlined, () => _abrir(d, descargar: true), false),
                        ('Eliminar', Icons.delete_outline, () => _eliminar(d), true),
                      ]);
                    },
                    vacio: 'Todavía no hay adjuntos. Tocá "Adjuntar archivos".',
                    columnas: [
                      Columna('Archivo', (d) => Row(children: [
                            Icon(_icono(d['nombreArchivo']), size: 18, color: p.primario),
                            const SizedBox(width: 8),
                            Expanded(child: Columna.texto(d['nombreArchivo'])),
                          ]), flex: 5, ordenarPor: (d) => d['nombreArchivo'] ?? ''),
                      Columna('Subido por', (d) => Columna.texto(d['subidoPorNombre']), flex: 2),
                      Columna('Fecha', (d) => Columna.texto(Tema.fechaHora(d['subidoEn'])), flex: 2, ordenarPor: (d) => d['subidoEn'] ?? ''),
                    ],
                    tarjeta: (d) => Row(children: [
                      Icon(_icono(d['nombreArchivo']), color: p.primario),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['nombreArchivo'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${d['subidoPorNombre'] ?? ''} · ${Tema.fechaHora(d['subidoEn'])}',
                              style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                        ]),
                      ),
                      IconButton(tooltip: 'Más acciones', icon: const Icon(Icons.more_vert),
                          onPressed: () => mostrarMenu(context, Offset.zero, [
                                ('Abrir', Icons.open_in_new, () => _abrir(d), false),
                                ('Descargar', Icons.file_download_outlined, () => _abrir(d, descargar: true), false),
                                ('Eliminar', Icons.delete_outline, () => _eliminar(d), true),
                              ])),
                    ]),
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Boton.primario('Adjuntar archivos', icono: Icons.add, cargando: _subiendo != null, onPressed: adjuntar),
            if (ancho) ...[
              Boton('Abrir', icono: Icons.open_in_new, onPressed: hay ? () => _abrir(_seleccionado) : null),
              Boton('Descargar', icono: Icons.file_download_outlined, onPressed: hay ? () => _abrir(_seleccionado, descargar: true) : null),
              Boton.peligro('Eliminar', icono: Icons.delete_outline, onPressed: hay ? () => _eliminar(_seleccionado) : null),
            ],
          ]),
        ]),
      ),
    );
  }
}
