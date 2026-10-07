import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dashboard.dart';
import '../../models/turno.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/navegacion.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';
import '../menu_principal.dart';

/// Dashboard del escritorio ("Panel General"): Período + Actualizar, las cuatro tarjetas, Alertas,
/// Comparativa, nuevos estudiantes de 6 meses y las tablas. Solo números agregados, nunca texto
/// clínico, y todo lleva a algún lado (tarjetas a la lista/agenda, cursos a la lista filtrada,
/// citas y seguimientos a la ficha). Un profesional ve solo lo suyo.
class PanelGeneral extends StatefulWidget {
  const PanelGeneral({super.key});
  @override
  State<PanelGeneral> createState() => _PanelGeneralState();
}

class _PanelGeneralState extends State<PanelGeneral> {
  Dashboard? _d;
  bool _cargando = true;
  String? _error;
  String _periodo = 'todo';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = _d == null);
    try {
      final data = await ApiClient.instancia.get('/api/dashboard', {'periodo': _periodo});
      if (!mounted) return;
      setState(() {
        _d = Dashboard.fromJson(data);
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final nav = context.read<Navegacion>();
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    final barra = Container(
      color: p.superficie,
      padding: EdgeInsets.symmetric(horizontal: ancho ? 22 : 10, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        const Text('Período: ', style: TextStyle(fontSize: 14.5)),
        const SizedBox(width: 6),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            initialValue: _periodo,
            decoration: decoracionCampo(context),
            items: const [
              DropdownMenuItem(value: 'todo', child: Text('Todo')),
              DropdownMenuItem(value: 'mes', child: Text('Este mes')),
            ],
            onChanged: (v) {
              setState(() => _periodo = v ?? 'todo');
              _cargar();
            },
          ),
        ),
        const SizedBox(width: 10),
        Boton('Actualizar', icono: Icons.refresh, onPressed: _cargar),
      ]),
    );
    Widget cuerpo;
    if (_cargando) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      cuerpo = EstadoVacio(icono: Icons.cloud_off, titulo: 'No se pudo cargar el panel', detalle: _error, error: true, accion: 'Reintentar', onAccion: _cargar);
    } else {
      cuerpo = RefreshIndicator(onRefresh: _cargar, child: _contenido(_d!, auth, nav, ancho, p));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Encabezado(
        titulo: 'Panel General',
        subtitulo: auth.esPsicologo ? 'Tus estudiantes, citas y atenciones' : 'Resumen general del Departamento de Psicología',
        izquierda: flechaAtras(context, nav.irAlMenu),
      ),
      barra,
      Divider(height: 1, color: p.borde),
      Expanded(child: cuerpo),
      if (ancho) Container(color: p.superficie, child: PieVolver(texto: 'Volver', onVolver: nav.irAlMenu)),
    ]);
  }

  Widget _contenido(Dashboard d, AuthService auth, Navegacion nav, bool ancho, Paleta p) {
    final tiles = [
      _tile(p, 'Estudiantes', d.totalEstudiantes, Icons.person, const Color(0xFF3B6BC4), () => nav.verPestana(PestanaEstudiantes.lista)),
      _tile(p, 'Atenciones', d.totalAtenciones, Icons.chat, const Color(0xFF5B3FA0), null),
      _tile(p, 'Citas', d.totalCitas, Icons.calendar_month, Tema.exito, () => nav.verPestana(PestanaEstudiantes.agenda)),
      _tile(p, 'Profesionales', d.totalProfesionales, Icons.badge, const Color(0xFF4F75D1), null),
    ];
    final alertas = [
      _tile(p, 'Casos pendientes', d.casosPendientes, Icons.warning_rounded, Tema.peligro, () => nav.verPestana(PestanaEstudiantes.agenda),
          ayuda: 'Citas de días anteriores que siguen como "Programada"'),
      if (d.seguimientosVencidosTotal != null)
        _tile(p, 'Seguimientos vencidos', d.seguimientosVencidosTotal!, Icons.warning_rounded, Tema.peligro, null,
            ayuda: 'Casos reiterados sin una entrada nueva hace más de 15 días'),
    ];
    Widget grilla(List<Widget> ws, int columnas) => ancho
        ? Row(children: [for (var i = 0; i < ws.length; i++) ...[Expanded(child: ws[i]), if (i < ws.length - 1) const SizedBox(width: 20)]])
        : GridView.count(
            crossAxisCount: columnas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: ws,
          );
    final tablas = <Widget>[
      _tablaTarjeta('Estudiantes por curso', d.porCurso.isEmpty,
          Tabla<MapEntry<String, int>>(
            filas: (d.porCurso.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
            alAbrir: (e) => nav.verListaFiltrada(e.key),
            alSeleccionar: (e) => nav.verListaFiltrada(e.key),
            columnas: [
              Columna('Curso', (e) => Columna.texto(e.key), flex: 5),
              Columna('Estudiantes', (e) => Columna.texto('${e.value}'), flex: 2),
            ],
            tarjeta: (e) => Row(children: [Expanded(child: Text(e.key)), Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800)), const Icon(Icons.chevron_right)]),
          ),
          d.porCurso.length),
      _tablaTarjeta('Próximas citas', d.proximasCitas.isEmpty,
          Tabla<Turno>(
            filas: d.proximasCitas,
            alAbrir: (t) => nav.abrirFicha(t.pacienteId),
            alSeleccionar: (t) => nav.abrirFicha(t.pacienteId),
            columnas: [
              Columna('Estudiante', (t) => Columna.texto(t.pacienteNombre), flex: 3),
              Columna('Curso', (t) => Columna.texto(t.curso), flex: 3),
              Columna('Profesional', (t) => Columna.texto(t.psicologoNombre), flex: 2),
              Columna('Fecha y hora', (t) => Columna.texto(Tema.fechaHora(t.fechaHora)), flex: 2),
            ],
            tarjeta: (t) => Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.pacienteNombre ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${Tema.diaLegible(t.fecha)} ${Tema.hora(t.fecha)}${auth.esPsicologo ? '' : ' · ${t.psicologoNombre ?? ''}'}',
                    style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
              ])),
              const Icon(Icons.chevron_right),
            ]),
          ),
          d.proximasCitas.length),
      if (d.seguimientosVencidosLista != null)
        _tablaTarjeta('Seguimientos pendientes', d.seguimientosVencidosLista!.isEmpty,
            Tabla<CasoPendiente>(
              filas: d.seguimientosVencidosLista!,
              alAbrir: (c) => c.pacienteId == null ? null : nav.abrirFicha(c.pacienteId!, pestanaInicial: 1),
              alSeleccionar: (c) => c.pacienteId == null ? null : nav.abrirFicha(c.pacienteId!, pestanaInicial: 1),
              columnas: [
                Columna('Estudiante', (c) => Columna.texto(c.estudiante), flex: 3),
                Columna('Curso', (c) => Columna.texto(c.curso), flex: 3),
                Columna('Última entrada reiterada', (c) => Columna.texto(c.ultimoSeguimiento), flex: 3),
              ],
              tarjeta: (c) => Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Tema.ambar),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.estudiante, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${c.curso ?? 'Sin curso'} · última: ${c.ultimoSeguimiento}', style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                ])),
              ]),
            ),
            d.seguimientosVencidosLista!.length),
      if (!auth.esSecretaria)
        _tablaTarjeta('Casos por motivo de atención', d.porMotivo.isEmpty,
            Tabla<MapEntry<String, int>>(
              filas: d.porMotivo.entries.toList(),
              columnas: [
                Columna('Motivo de la atención', (e) => Tooltip(message: e.key, child: Columna.texto(e.key)), flex: 5),
                Columna('Casos', (e) => Columna.texto('${e.value}'), flex: 1),
              ],
              tarjeta: (e) => Row(children: [Expanded(child: Text(e.key)), Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800))]),
            ),
            d.porMotivo.length),
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(ancho ? 36 : 10, ancho ? 24 : 12, ancho ? 36 : 10, 20),
      children: [
        grilla(tiles, 2),
        const SizedBox(height: 14),
        Text('Alertas', style: TextStyle(color: Tema.legible(context, Tema.peligro), fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        grilla(alertas, 2),
        const SizedBox(height: 18),
        ancho
            ? SizedBox(height: 260, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: Tarjeta(titulo: 'Comparativa', expandir: true, child: _comparativa(d, p))),
                const SizedBox(width: 16),
                Expanded(child: Tarjeta(titulo: 'Nuevos estudiantes (6 meses)', expandir: true, child: _tendencia(d, p))),
              ]))
            : Column(children: [
                SizedBox(height: 240, child: Tarjeta(titulo: 'Comparativa', expandir: true, child: _comparativa(d, p))),
                const SizedBox(height: 12),
                SizedBox(height: 240, child: Tarjeta(titulo: 'Nuevos estudiantes (6 meses)', expandir: true, child: _tendencia(d, p))),
              ]),
        const SizedBox(height: 16),
        if (ancho)
          Wrap(spacing: 16, runSpacing: 16, children: [
            for (final t in tablas) SizedBox(width: (MediaQuery.sizeOf(context).width - 72 - 16) / 2, child: t),
          ])
        else
          ...tablas.map((t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: t)),
      ],
    );
  }

  Widget _tablaTarjeta(String titulo, bool vacia, Widget tabla, int filas) => Tarjeta(
        titulo: titulo,
        child: vacia
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text('Sin datos', textAlign: TextAlign.center,
                    style: TextStyle(fontStyle: FontStyle.italic, color: Paleta.de(context).textoSecundario)),
              )
            : SizedBox(height: esAncho(context) ? 230 : (filas * 70.0).clamp(80.0, 360.0), child: tabla),
      );

  Widget _tile(Paleta p, String titulo, int numero, IconData icono, Color colorBase, VoidCallback? onTap, {String? ayuda}) {
    final color = Tema.legible(context, colorBase);
    final tile = Material(
      color: p.superficie,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: colorBase, width: 4))),
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: colorBase, borderRadius: BorderRadius.circular(7)),
              child: Icon(icono, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 12),
            Text(titulo, style: TextStyle(fontSize: 14, color: p.textoSecundario), overflow: TextOverflow.ellipsis),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Text('$numero', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: color, height: 1.15))),
              if (onTap != null) Icon(Icons.chevron_right, color: p.textoSecundario),
            ]),
          ]),
        ),
      ),
    );
    return ayuda == null ? tile : Tooltip(message: ayuda, child: tile);
  }

  Widget _barras(Paleta p, List<(String, int, Color)> datos) {
    final maximo = datos.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (final (etiqueta, valor, color) in datos)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('$valor', style: TextStyle(fontWeight: FontWeight.w800, color: Tema.legible(context, color))),
              const SizedBox(height: 4),
              Flexible(
                child: FractionallySizedBox(
                  heightFactor: maximo == 0 ? 0.02 : (valor / maximo).clamp(0.02, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [color.withValues(alpha: 0.75), color]),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(etiqueta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textoSecundario)),
            ]),
          ),
        ),
    ]);
  }

  Widget _comparativa(Dashboard d, Paleta p) => _barras(p, [
        ('Estudiantes', d.totalEstudiantes, const Color(0xFF3B6BC4)),
        ('Atenciones', d.totalAtenciones, const Color(0xFF5B3FA0)),
        ('Citas', d.totalCitas, Tema.exito),
        ('Profesionales', d.totalProfesionales, const Color(0xFF4F75D1)),
      ]);

  Widget _tendencia(Dashboard d, Paleta p) => _barras(p, [
        for (final e in d.nuevosPorMes.entries)
          (e.key.split('-').length == 2 ? Tema.nombreMes(int.parse(e.key.split('-')[1])).substring(0, 3) : e.key, e.value, p.primario),
      ]);
}
