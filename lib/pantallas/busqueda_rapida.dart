import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/paciente.dart';
import '../services/api_client.dart';
import '../services/navegacion.dart';
import '../ui/componentes.dart';

/// BusquedaRapida del escritorio (Ctrl+K): hoja con búsqueda mientras se escribe (el servidor ya
/// filtra por rol), ↑/↓ para moverse, Enter abre la ficha (si todavía está buscando, abre el primer
/// resultado cuando llega), y con el campo vacío los estudiantes abiertos en esta sesión.
class BusquedaRapida {
  static Future<void> mostrar(BuildContext context) {
    final nav = context.read<Navegacion>();
    return mostrarHoja(
      context,
      titulo: 'Buscar estudiante',
      subtitulo: 'Abrí la ficha de cualquier estudiante desde donde estés',
      ancho: 640,
      alto: 560,
      conScroll: false,
      contenido: (ctx) => _Busqueda(alElegir: (p) {
        Navigator.pop(ctx);
        nav.abrirFicha(p.id!);
      }),
      acciones: (ctx) => [Boton('Cerrar', onPressed: () => Navigator.pop(ctx))],
    );
  }
}

class _Busqueda extends StatefulWidget {
  final ValueChanged<Paciente> alElegir;
  const _Busqueda({required this.alElegir});
  @override
  State<_Busqueda> createState() => _BusquedaState();
}

class _BusquedaState extends State<_Busqueda> {
  final _ctrl = TextEditingController();
  Timer? _espera;
  List<Paciente> _resultados = [];
  bool _buscando = false;
  bool _enterPendiente = false;
  int _elegido = 0;
  int _consulta = 0;
  String? _error;

  @override
  void dispose() {
    _espera?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _alEscribir(String t) {
    _espera?.cancel();
    setState(() {
      _elegido = 0;
      if (t.trim().isEmpty) {
        _resultados = [];
        _buscando = false;
      }
    });
    if (t.trim().isNotEmpty) _espera = Timer(const Duration(milliseconds: 220), () => _buscar(t.trim()));
  }

  Future<void> _buscar(String q) async {
    final esta = ++_consulta;
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final data = await ApiClient.instancia.get('/api/pacientes/search', {'q': q});
      if (!mounted || esta != _consulta) return;
      setState(() {
        _resultados = (data as List).map((e) => Paciente.fromJson(e)).toList();
        _buscando = false;
      });
      if (_enterPendiente && _resultados.isNotEmpty) widget.alElegir(_resultados.first);
      _enterPendiente = false;
    } catch (e) {
      if (!mounted || esta != _consulta) return;
      setState(() {
        _error = e.toString();
        _buscando = false;
      });
    }
  }

  List<Paciente> get _lista => _ctrl.text.trim().isEmpty ? context.read<Navegacion>().recientes : _resultados;

  KeyEventResult _tecla(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final lista = _lista;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown && lista.isNotEmpty) {
      setState(() => _elegido = (_elegido + 1) % lista.length);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp && lista.isNotEmpty) {
      setState(() => _elegido = (_elegido - 1 + lista.length) % lista.length);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (lista.isNotEmpty) {
        widget.alElegir(lista[_elegido.clamp(0, lista.length - 1)]);
      } else if (_buscando || _espera?.isActive == true) {
        _enterPendiente = true;
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.de(context);
    final vacio = _ctrl.text.trim().isEmpty;
    final lista = _lista;
    String titulo;
    if (_error != null) {
      titulo = 'NO SE PUDO BUSCAR';
    } else if (vacio) {
      titulo = lista.isEmpty ? 'EMPEZÁ A ESCRIBIR PARA BUSCAR' : 'ABIERTOS RECIENTEMENTE';
    } else if (_buscando && lista.isEmpty) {
      titulo = 'BUSCANDO…';
    } else {
      titulo = lista.isEmpty ? 'SIN RESULTADOS' : '${lista.length} RESULTADO(S)';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          onKeyEvent: _tecla,
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _alEscribir,
            decoration: decoracionCampo(context,
                hint: 'Nombre, apellido, CI o teléfono del estudiante', prefijo: const Icon(Icons.search)),
          ),
        ),
        if (_buscando) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
        const SizedBox(height: 10),
        Text(titulo, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.textoSecundario)),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            itemCount: lista.length,
            itemBuilder: (_, i) {
              final e = lista[i];
              return Material(
                color: i == _elegido ? p.seleccion : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: p.seleccion,
                    child: Text(e.nombre.isEmpty ? '?' : e.nombre[0].toUpperCase(),
                        style: TextStyle(color: p.primario, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(e.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([e.curso ?? 'Sin curso asignado', if (e.ci != null) 'CI ${e.ci}'].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => widget.alElegir(e),
                ),
              );
            },
          ),
        ),
        if (esAncho(context))
          Text('↑ ↓ para moverte  ·  Enter abre la ficha  ·  Esc cierra',
              style: TextStyle(fontSize: 12, color: p.textoSecundario)),
      ],
    );
  }
}
