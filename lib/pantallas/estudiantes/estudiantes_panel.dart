import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/navegacion.dart';
import '../../ui/componentes.dart';
import '../agenda/agenda.dart';
import '../menu_principal.dart';
import '../reportes/reportes_archivos.dart';
import 'detalle_estudiante.dart';
import 'gestion_estudiantes.dart';

/// EstudiantesPanel del escritorio: encabezado "Estudiantes", pestañas Lista de Estudiantes /
/// Agenda / Reportes y archivos, y la ficha (DetallePaciente) que se muestra en lugar de la lista.
/// La lista queda viva debajo de la ficha: al volver conserva filtros y selección.
class EstudiantesPanel extends StatefulWidget {
  const EstudiantesPanel({super.key});
  @override
  State<EstudiantesPanel> createState() => _EstudiantesPanelState();
}

class _EstudiantesPanelState extends State<EstudiantesPanel> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final Navegacion _nav;

  @override
  void initState() {
    super.initState();
    _nav = context.read<Navegacion>();
    _tabs = TabController(length: 3, vsync: this, initialIndex: _nav.pestana.index);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && _nav.pestana.index != _tabs.index) {
        _nav.pestana = PestanaEstudiantes.values[_tabs.index];
      }
    });
    _nav.addListener(_sincronizar);
  }

  @override
  void dispose() {
    _nav.removeListener(_sincronizar);
    _tabs.dispose();
    super.dispose();
  }

  void _sincronizar() {
    if (_tabs.index != _nav.pestana.index) _tabs.animateTo(_nav.pestana.index);
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<Navegacion>();
    final ficha = nav.fichaAbierta;
    final lista = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Encabezado(
          titulo: 'Estudiantes',
          subtitulo: 'Datos, seguimiento, atenciones, agenda y reportes',
          izquierda: flechaAtras(context, nav.irAlMenu),
        ),
        BarraPestanas(controller: _tabs, pestanas: const [
          Pestana('Lista de Estudiantes', Icons.person),
          Pestana('Agenda', Icons.calendar_month),
          Pestana('Reportes y archivos', Icons.description),
        ]),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _Viva(child: GestionEstudiantes()),
              _Viva(child: Agenda()),
              _Viva(child: ReportesArchivos()),
            ],
          ),
        ),
        PieVolver(onVolver: nav.irAlMenu),
      ],
    );
    // expand: con la lista oculta (Offstage mide 0) la ficha igual ocupa toda la sección.
    return Stack(fit: StackFit.expand, children: [
      Offstage(offstage: ficha != null, child: TickerMode(enabled: ficha == null, child: lista)),
      if (ficha != null)
        Positioned.fill(
          child: Material(
            color: Paleta.de(context).fondo,
            child: DetalleEstudiante(key: ValueKey('ficha_$ficha'), pacienteId: ficha, pestanaInicial: nav.pestanaFicha),
          ),
        ),
    ]);
  }
}

/// Mantiene viva cada pestaña al cambiar (como las cartas del escritorio: no se recargan).
class _Viva extends StatefulWidget {
  final Widget child;
  const _Viva({required this.child});
  @override
  State<_Viva> createState() => _VivaState();
}

class _VivaState extends State<_Viva> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
