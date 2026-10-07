import 'package:flutter/material.dart';
import '../models/historia.dart';
import '../models/sesion.dart';
import '../models/turno.dart';
import '../services/api_client.dart';
import '../tema.dart';

enum TipoEvento { atencion, seguimiento, cita, adjunto }

class EventoCaso {
  final TipoEvento tipo;
  final DateTime fecha;
  final String titulo;
  final String? detalle;
  final Object? dato;
  EventoCaso(this.tipo, this.fecha, this.titulo, this.detalle, [this.dato]);
}

/// LineaDeTiempo del escritorio: atenciones, entradas de seguimiento, citas y adjuntos del
/// estudiante en orden cronológico, agrupados por mes, con filtros por tipo. Solo metadatos
/// (nunca el texto de las notas). Para "Usuario autorizado" solo citas.
class LineaDeTiempo extends StatefulWidget {
  final int pacienteId;
  final bool soloCitas;
  final void Function(EventoCaso evento) alTocar;
  const LineaDeTiempo({super.key, required this.pacienteId, required this.soloCitas, required this.alTocar});

  @override
  State<LineaDeTiempo> createState() => LineaDeTiempoState();
}

class LineaDeTiempoState extends State<LineaDeTiempo> {
  List<EventoCaso> _eventos = [];
  bool _cargando = true;
  String? _error;
  final Set<TipoEvento> _ocultos = {};

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final id = widget.pacienteId;
      final api = ApiClient.instancia;
      final eventos = <EventoCaso>[];
      final citas = await api.get('/api/turnos', {'pacienteId': id}) as List;
      for (final j in citas) {
        final t = Turno.fromJson(j);
        eventos.add(EventoCaso(TipoEvento.cita, t.fecha, 'Cita ${Tema.etiquetaEstado(t.estado).toLowerCase()}',
            t.psicologoNombre, t));
      }
      if (!widget.soloCitas) {
        final resultados = await Future.wait([
          api.get('/api/estudiantes/$id/atenciones'),
          api.get('/api/estudiantes/$id/seguimientos'),
          api.get('/api/estudiantes/$id/documentos'),
        ]);
        for (final j in resultados[0] as List) {
          final s = Sesion.fromJson(j);
          final f = Tema.parsear(s.fecha);
          if (f != null) {
            eventos.add(EventoCaso(TipoEvento.atencion, f, 'Atención registrada',
                [if (s.duracionMinutos != null) s.duracionTexto(), s.psicologoNombre].whereType<String>().join(' · '), s));
          }
        }
        for (final j in resultados[1] as List) {
          final h = Historia.fromJson(j);
          final f = Tema.parsear(h.fechaCreacion);
          if (f != null) {
            eventos.add(EventoCaso(TipoEvento.seguimiento, f,
                h.esReiterado ? 'Seguimiento (situación reiterada)' : 'Entrada de seguimiento', h.psicologoNombre, h));
          }
        }
        for (final j in resultados[2] as List) {
          final f = Tema.parsear(j['fechaSubida'] ?? j['subidoEn'] ?? j['creadoEn']);
          if (f != null) {
            eventos.add(EventoCaso(TipoEvento.adjunto, f, 'Adjunto: ${j['nombreArchivo'] ?? j['nombre'] ?? 'archivo'}', null, j));
          }
        }
      }
      eventos.sort((a, b) => b.fecha.compareTo(a.fecha));
      if (!mounted) return;
      setState(() {
        _eventos = eventos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  static const _info = {
    TipoEvento.atencion: ('Atenciones', Icons.forum_outlined, Tema.primario),
    TipoEvento.seguimiento: ('Seguimiento', Icons.timeline, Tema.rosa),
    TipoEvento.cita: ('Citas', Icons.event, Tema.secundario),
    TipoEvento.adjunto: ('Adjuntos', Icons.attach_file, Tema.ambar),
  };

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    if (_error != null) return Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error));

    final tipos = widget.soloCitas ? [TipoEvento.cita] : TipoEvento.values;
    final visibles = _eventos.where((e) => !_ocultos.contains(e.tipo)).toList();
    final hijos = <Widget>[];
    if (!widget.soloCitas) {
      hijos.add(Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tipos.map((t) {
          final (nombre, icono, color) = _info[t]!;
          final n = _eventos.where((e) => e.tipo == t).length;
          return FilterChip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(icono, size: 16, color: Tema.legible(context, color)),
            label: Text('$nombre ($n)'),
            selected: !_ocultos.contains(t),
            showCheckmark: false,
            onSelected: (v) => setState(() => v ? _ocultos.remove(t) : _ocultos.add(t)),
          );
        }).toList(),
      ));
      hijos.add(const SizedBox(height: 8));
    }
    if (visibles.isEmpty) {
      hijos.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_eventos.isEmpty ? 'Todavía no hay registros para este estudiante.' : 'Nada para mostrar con estos filtros.',
            style: TextStyle(color: Tema.textoSecundario(context))),
      ));
    }
    String? mesActual;
    for (final e in visibles) {
      final mes = Tema.mesAnio(e.fecha);
      if (mes != mesActual) {
        mesActual = mes;
        hijos.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(mes.toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Tema.textoSecundario(context), letterSpacing: 0.5)),
        ));
      }
      final (_, icono, colorBase) = _info[e.tipo]!;
      final color = e.tipo == TipoEvento.cita && e.dato is Turno ? Tema.colorEstado((e.dato as Turno).estado) : colorBase;
      hijos.add(InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: e.tipo == TipoEvento.adjunto ? null : () => widget.alTocar(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: Tema.esOscuro(context) ? 0.28 : 0.13),
                child: Icon(icono, size: 17, color: Tema.esOscuro(context) ? Color.lerp(color, Colors.white, 0.35) : color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      [Tema.fechaHora(Tema.isoLocal(e.fecha)), if (e.detalle != null && e.detalle!.isNotEmpty) e.detalle!].join(' · '),
                      style: TextStyle(fontSize: 12.5, color: Tema.textoSecundario(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos);
  }
}
