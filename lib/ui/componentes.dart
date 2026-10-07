import 'package:flutter/material.dart';
import '../tema.dart';

/// Los "ladrillos" visuales del escritorio (Vista/Tema.java) para la versión web: botones
/// Tema.botonPrimario/Secundario/Exito/Peligro, tarjetas con título en mayúsculas
/// (Tema.panelTarjeta), tablas con filas alternadas (Tema.estilizarTabla), el panel lateral
/// deslizable (PanelDeslizable), las hojas (Tema.mostrarHoja) y el encabezado con degradé y escudo
/// (Tema.panelEncabezado).

/// true en pantallas anchas (computadora, tablet apaisada): diseño de escritorio con tablas y
/// panel lateral. En el celular, listas en tarjetas y formularios a pantalla completa.
bool esAncho(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

class Paleta {
  final bool oscuro;
  const Paleta(this.oscuro);
  factory Paleta.de(BuildContext context) => Paleta(Tema.esOscuro(context));

  Color get fondo => oscuro ? const Color(0xFF1E1F22) : const Color(0xFFF4F3F9);
  Color get superficie => oscuro ? const Color(0xFF2B2D30) : Colors.white;
  Color get borde => oscuro ? const Color(0xFF52565A) : const Color(0xFFE2E6EC);
  Color get bordeSuave => oscuro ? const Color(0xFF3C3F43) : const Color(0xFFECEFF3);
  Color get zebra => oscuro ? const Color(0xFF32353A) : const Color(0xFFEDF0F5);
  Color get texto => oscuro ? const Color(0xFFE6E6E6) : const Color(0xFF1E232D);
  Color get textoSecundario => oscuro ? const Color(0xFF969696) : const Color(0xFF6C7582);
  Color get primario => oscuro ? Tema.primarioOscuro : Tema.primario;
  Color get secundario => oscuro ? Tema.secundarioOscuro : Tema.secundario;
  Color get seleccion => (oscuro ? Tema.primarioOscuro : Tema.primario).withValues(alpha: oscuro ? 0.28 : 0.13);
  Color get botonSuave => oscuro ? const Color(0xFF3A3650) : const Color(0xFFE7E4F3);
  Color get deshabilitado => oscuro ? const Color(0xFF34363A) : const Color(0xFFEBEDF0);
  Color get textoDeshabilitado => oscuro ? const Color(0xFF707070) : const Color(0xFFA0A7B1);
}

// ------------------------------------------------------------------ botones

enum EstiloBoton { primario, secundario, exito, peligro }

class Boton extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final EstiloBoton estilo;
  final String? tooltip;
  final bool soloIcono;
  final bool cargando;

  const Boton(this.texto, {super.key, this.icono, this.onPressed, this.estilo = EstiloBoton.secundario,
      this.tooltip, this.soloIcono = false, this.cargando = false});
  const Boton.primario(this.texto, {super.key, this.icono, this.onPressed, this.tooltip, this.soloIcono = false, this.cargando = false})
      : estilo = EstiloBoton.primario;
  const Boton.exito(this.texto, {super.key, this.icono, this.onPressed, this.tooltip, this.soloIcono = false, this.cargando = false})
      : estilo = EstiloBoton.exito;
  const Boton.peligro(this.texto, {super.key, this.icono, this.onPressed, this.tooltip, this.soloIcono = false, this.cargando = false})
      : estilo = EstiloBoton.peligro;

  @override
  Widget build(BuildContext context) {
    final p = Paleta.de(context);
    final habilitado = onPressed != null && !cargando;
    final (Color fondo, Color frente) = switch (estilo) {
      EstiloBoton.primario => (p.oscuro ? const Color(0xFF6F5FC4) : const Color(0xFF55439E), Colors.white),
      EstiloBoton.exito => (Tema.exito, Colors.white),
      EstiloBoton.peligro => (Tema.peligro, Colors.white),
      EstiloBoton.secundario => (p.botonSuave, p.oscuro ? const Color(0xFFCBC3F2) : Tema.primario),
    };
    final hijo = cargando
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: frente))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) Icon(icono, size: 17),
              if (icono != null && !soloIcono) const SizedBox(width: 7),
              if (!soloIcono) Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
            ],
          );
    final boton = FilledButton(
      onPressed: habilitado ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: fondo,
        foregroundColor: frente,
        disabledBackgroundColor: p.deshabilitado,
        disabledForegroundColor: p.textoDeshabilitado,
        minimumSize: Size(soloIcono ? 42 : 0, 38),
        padding: EdgeInsets.symmetric(horizontal: soloIcono ? 10 : 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        elevation: estilo == EstiloBoton.secundario ? 0 : 1,
      ),
      child: hijo,
    );
    final t = tooltip ?? (soloIcono ? texto : null);
    return t == null ? boton : Tooltip(message: t, child: boton);
  }
}

// ------------------------------------------------------------------ tarjeta con título

/// Tarjeta blanca con título en mayúsculas grises (como "BUSCAR ESTUDIANTE" del escritorio).
class Tarjeta extends StatelessWidget {
  final String? titulo;
  final Widget child;
  final Widget? accion;
  final EdgeInsetsGeometry padding;
  final bool expandir;

  const Tarjeta({super.key, this.titulo, required this.child, this.accion,
      this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18), this.expandir = false});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.de(context);
    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: expandir ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (titulo != null) ...[
          Row(children: [
            Expanded(
              child: Text(titulo!.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.textoSecundario, letterSpacing: 0.4)),
            ),
            ?accion,
          ]),
          const SizedBox(height: 12),
        ],
        if (expandir) Expanded(child: child) else child,
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: p.superficie,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: p.oscuro ? 0.3 : 0.07), blurRadius: 3, offset: const Offset(0, 2)),
        ],
      ),
      padding: padding,
      child: contenido,
    );
  }
}

// ------------------------------------------------------------------ encabezado

/// Banner con degradé SECUNDARIO→PRIMARIO y el escudo del colegio a la derecha.
class Encabezado extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? izquierda;
  final List<Widget> acciones;

  const Encabezado({super.key, required this.titulo, this.subtitulo, this.izquierda, this.acciones = const []});

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final p = Paleta.de(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: p.oscuro
              ? const [Color(0xFF26407A), Color(0xFF45397A)]
              : const [Color(0xFF2F5AA8), Color(0xFF6A58AE)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(ancho ? 24 : 12, ancho ? 16 : 10, ancho ? 20 : 10, ancho ? 16 : 12),
          child: Row(
            children: [
              if (izquierda != null) ...[izquierda!, const SizedBox(width: 6)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: ancho ? 26 : 20, fontWeight: FontWeight.w800)),
                    if (subtitulo != null && subtitulo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(subtitulo!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: ancho ? 13.5 : 12.5)),
                      ),
                  ],
                ),
              ),
              ...acciones,
              const SizedBox(width: 8),
              Image.asset('assets/logo_colegio.png', height: ancho ? 50 : 38, filterQuality: FilterQuality.medium),
            ],
          ),
        ),
      ),
    );
  }
}

class BotonBlanco extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;
  const BotonBlanco({super.key, required this.icono, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icono, color: Colors.white));
}

// ------------------------------------------------------------------ pestañas

class Pestana {
  final String texto;
  final IconData icono;
  const Pestana(this.texto, this.icono);
}

/// Pestañas alineadas a la izquierda con ícono, como el JTabbedPane del escritorio.
class BarraPestanas extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<Pestana> pestanas;
  const BarraPestanas({super.key, required this.controller, required this.pestanas});

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final p = Paleta.de(context);
    return Container(
      decoration: BoxDecoration(color: p.oscuro ? const Color(0xFF26272B) : const Color(0xFFF0F0F2),
          border: Border(bottom: BorderSide(color: p.borde))),
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerHeight: 0,
        labelColor: p.texto,
        unselectedLabelColor: p.texto.withValues(alpha: 0.8),
        labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13.5),
        indicator: BoxDecoration(
          color: p.superficie,
          border: Border(bottom: BorderSide(color: p.oscuro ? Tema.secundarioOscuro : const Color(0xFF5B8BD6), width: 3)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: pestanas
            .map((t) => Tab(
                  height: 44,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.icono, size: 17, color: p.primario),
                    const SizedBox(width: 7),
                    Text(t.texto),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}

// ------------------------------------------------------------------ tabla

class Columna<T> {
  final String titulo;
  final int flex;
  final Widget Function(T fila) celda;
  final Comparable Function(T fila)? ordenarPor;
  final bool enCelular;
  const Columna(this.titulo, this.celda, {this.flex = 2, this.ordenarPor, this.enCelular = true});

  static Widget texto(String? valor, {bool negrita = false, Color? color, String siVacio = 'N/A'}) => Text(
        (valor == null || valor.isEmpty) ? siVacio : valor,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13.5, fontWeight: negrita ? FontWeight.w600 : null, color: color),
      );
}

/// Tabla del escritorio (encabezado en mayúsculas, filas alternadas, selección, orden por
/// columna, doble clic). En pantallas angostas se dibuja como lista de tarjetas con [tarjeta].
class Tabla<T> extends StatefulWidget {
  final List<Columna<T>> columnas;
  final List<T> filas;
  final T? seleccionada;
  final ValueChanged<T>? alSeleccionar;
  final ValueChanged<T>? alAbrir;
  final void Function(T fila, Offset posicion)? alMenu;
  final String vacio;
  final Widget Function(T fila)? tarjeta;
  final bool Function(T a, T b)? igual;

  const Tabla({super.key, required this.columnas, required this.filas, this.seleccionada, this.alSeleccionar,
      this.alAbrir, this.alMenu, this.vacio = 'Sin datos', this.tarjeta, this.igual});

  @override
  State<Tabla<T>> createState() => _TablaState<T>();
}

class _TablaState<T> extends State<Tabla<T>> {
  int? _orden;
  bool _ascendente = true;
  T? _ultimoClic;
  DateTime _momentoClic = DateTime(2000);

  /// Doble clic propio: onDoubleTap de Flutter demora 300 ms cada clic simple (la selección se
  /// sentía lenta) e ignora dobles clics muy rápidos.
  void _clic(T f) {
    final ahora = DateTime.now();
    final mismo = _ultimoClic != null && (widget.igual?.call(f, _ultimoClic as T) ?? f == _ultimoClic);
    if (mismo && ahora.difference(_momentoClic).inMilliseconds < 500 && widget.alAbrir != null) {
      _ultimoClic = null;
      widget.alAbrir!(f);
      return;
    }
    _ultimoClic = f;
    _momentoClic = ahora;
    widget.alSeleccionar?.call(f);
  }

  bool _esSeleccionada(T f) =>
      widget.seleccionada != null && (widget.igual?.call(f, widget.seleccionada as T) ?? f == widget.seleccionada);

  List<T> get _ordenadas {
    final i = _orden;
    if (i == null || widget.columnas[i].ordenarPor == null) return widget.filas;
    final clave = widget.columnas[i].ordenarPor!;
    final lista = [...widget.filas]..sort((a, b) => clave(a).compareTo(clave(b)));
    return _ascendente ? lista : lista.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.de(context);
    final filas = _ordenadas;
    if (!esAncho(context) && widget.tarjeta != null) {
      if (filas.isEmpty) return _vacio(p);
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 90),
        itemCount: filas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final f = filas[i];
          return Material(
            color: _esSeleccionada(f) ? p.seleccion : p.superficie,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => widget.alAbrir != null ? widget.alAbrir!(f) : widget.alSeleccionar?.call(f),
              onLongPress: widget.alMenu == null ? null : () => widget.alMenu!(f, Offset.zero),
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10), border: Border.all(color: p.bordeSuave)),
                padding: const EdgeInsets.all(12),
                child: widget.tarjeta!(f),
              ),
            ),
          );
        },
      );
    }
    final columnas = widget.columnas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.borde, width: 1.5))),
          child: Row(
            children: [
              for (var i = 0; i < columnas.length; i++)
                Expanded(
                  flex: columnas[i].flex,
                  child: InkWell(
                    onTap: columnas[i].ordenarPor == null
                        ? null
                        : () => setState(() {
                              if (_orden == i) {
                                _ascendente = !_ascendente;
                              } else {
                                _orden = i;
                                _ascendente = true;
                              }
                            }),
                    child: Container(
                      decoration: BoxDecoration(
                          border: i == 0 ? null : Border(left: BorderSide(color: p.bordeSuave))),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      alignment: Alignment.center,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(columnas[i].titulo.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.textoSecundario)),
                        ),
                        if (_orden == i)
                          Icon(_ascendente ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 18, color: p.textoSecundario),
                      ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filas.isEmpty
              ? _vacio(p)
              : ListView.builder(
                  itemCount: filas.length,
                  itemExtent: 36,
                  itemBuilder: (_, i) {
                    final f = filas[i];
                    final sel = _esSeleccionada(f);
                    return GestureDetector(
                      onSecondaryTapDown: widget.alMenu == null
                          ? null
                          : (d) {
                              widget.alSeleccionar?.call(f);
                              widget.alMenu!(f, d.globalPosition);
                            },
                      child: Material(
                        color: sel ? p.seleccion : (i.isOdd ? p.zebra : p.superficie),
                        child: InkWell(
                          onTap: () => _clic(f),
                          child: Row(
                            children: [
                              for (final c in columnas)
                                Expanded(
                                  flex: c.flex,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Align(alignment: Alignment.centerLeft, child: c.celda(f)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _vacio(PaletaAlias p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(widget.vacio,
              textAlign: TextAlign.center,
              style: TextStyle(fontStyle: FontStyle.italic, color: p.textoSecundario)),
        ),
      );
}

typedef PaletaAlias = Paleta;

/// Muestra un menú contextual (clic derecho / pulsación larga) con las acciones dadas.
Future<void> mostrarMenu(BuildContext context, Offset posicion, List<(String, IconData, VoidCallback?, bool)> items) async {
  if (!esAncho(context) || posicion == Offset.zero) {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map((it) => ListTile(
                    enabled: it.$3 != null,
                    leading: Icon(it.$2, color: it.$4 ? Tema.peligro : null),
                    title: Text(it.$1, style: TextStyle(color: it.$4 ? Tema.peligro : null)),
                    onTap: it.$3 == null
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            it.$3!();
                          },
                  ))
              .toList(),
        ),
      ),
    );
    return;
  }
  final elegido = await showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(posicion.dx, posicion.dy, posicion.dx + 1, posicion.dy + 1),
    items: [
      for (var i = 0; i < items.length; i++)
        PopupMenuItem(
          value: i,
          enabled: items[i].$3 != null,
          height: 38,
          child: Row(children: [
            Icon(items[i].$2, size: 18, color: items[i].$4 ? Tema.peligro : null),
            const SizedBox(width: 10),
            Text(items[i].$1, style: TextStyle(color: items[i].$4 ? Tema.peligro : null)),
          ]),
        ),
    ],
  );
  if (elegido != null) items[elegido].$3?.call();
}

// ------------------------------------------------------------------ panel lateral

/// PanelDeslizable del escritorio: título/subtítulo, X, cuerpo con scroll y pie fijo.
class PanelLateral extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final VoidCallback onCerrar;
  final Widget cuerpo;
  final Widget? pie;
  final Widget? debajoDelTitulo;

  const PanelLateral({super.key, required this.titulo, this.subtitulo, required this.onCerrar, required this.cuerpo,
      this.pie, this.debajoDelTitulo});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.de(context);
    return Container(
      decoration: BoxDecoration(
        color: p.superficie,
        borderRadius: esAncho(context) ? BorderRadius.circular(10) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2F5AA8), Color(0xFF6A58AE)])),
          ),
          SafeArea(
            bottom: false,
            top: !esAncho(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 10, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(titulo, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.texto)),
                      if (subtitulo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(subtitulo!, style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                        ),
                    ]),
                  ),
                  IconButton(tooltip: 'Cerrar (Esc)', onPressed: onCerrar, icon: const Icon(Icons.close)),
                ],
              ),
            ),
          ),
          if (debajoDelTitulo != null) Padding(padding: const EdgeInsets.fromLTRB(22, 4, 22, 4), child: debajoDelTitulo),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 10, 22, 16), child: cuerpo)),
          if (pie != null)
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.borde))),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: SafeArea(top: false, child: pie!),
            ),
        ],
      ),
    );
  }
}

/// Coloca el panel lateral a la derecha del contenido (pantalla ancha) o encima, a pantalla
/// completa (celular). El panel entra deslizándose.
class ConPanelLateral extends StatelessWidget {
  final Widget contenido;
  final Widget? panel;
  final double anchoPanel;
  const ConPanelLateral({super.key, required this.contenido, this.panel, this.anchoPanel = 460});

  @override
  Widget build(BuildContext context) {
    final ancho = esAncho(context);
    final animado = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(anim),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: panel ?? const SizedBox.shrink(key: ValueKey('sin_panel')),
    );
    if (ancho) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: contenido),
          if (panel != null) ...[const SizedBox(width: 16), SizedBox(width: anchoPanel, child: animado)],
        ],
      );
    }
    return Stack(children: [
      Positioned.fill(child: contenido),
      if (panel != null) Positioned.fill(child: Material(child: animado)),
    ]);
  }
}

// ------------------------------------------------------------------ hoja

/// Tema.mostrarHoja: tarjeta centrada sobre fondo oscurecido, con título, subtítulo, X y
/// botones abajo a la derecha. En el celular ocupa casi toda la pantalla.
Future<R?> mostrarHoja<R>(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  required Widget Function(BuildContext ctx) contenido,
  List<Widget> Function(BuildContext ctx)? acciones,
  double ancho = 620,
  double? alto,
  bool conScroll = true,
}) {
  return showGeneralDialog<R>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, anim, _, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, _) {
      final p = Paleta.de(ctx);
      final tam = MediaQuery.sizeOf(ctx);
      final cuerpo = contenido(ctx);
      return SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(tam.width < 600 ? 10 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ancho, maxHeight: alto ?? tam.height * 0.9),
              child: Material(
                color: p.superficie,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 10, 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.texto)),
                            if (subtitulo != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(subtitulo, style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
                              ),
                          ]),
                        ),
                        IconButton(tooltip: 'Cerrar (Esc)', onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ]),
                    ),
                    Divider(height: 1, color: p.borde),
                    Flexible(
                      child: conScroll
                          ? SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 16, 22, 16), child: cuerpo)
                          : Padding(padding: const EdgeInsets.fromLTRB(22, 16, 22, 16), child: cuerpo),
                    ),
                    if (acciones != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                        child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: acciones(ctx)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Tema.confirmar con el estilo de las hojas.
Future<bool> confirmar(BuildContext context,
    {required String titulo, required String mensaje, required String accion, bool peligroso = false,
    String cancelar = 'Cancelar'}) async {
  final r = await mostrarHoja<bool>(
    context,
    titulo: titulo,
    ancho: 460,
    contenido: (_) => Text(mensaje, style: const TextStyle(fontSize: 14.5)),
    acciones: (ctx) => [
      Boton(cancelar, onPressed: () => Navigator.pop(ctx, false)),
      peligroso
          ? Boton.peligro(accion, onPressed: () => Navigator.pop(ctx, true))
          : Boton.primario(accion, onPressed: () => Navigator.pop(ctx, true)),
    ],
  );
  return r == true;
}

// ------------------------------------------------------------------ campos

/// Etiqueta arriba + campo, como los formularios del escritorio.
class Campo extends StatelessWidget {
  final String etiqueta;
  final Widget child;
  const Campo(this.etiqueta, this.child, {super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 13, color: Paleta.de(context).textoSecundario, fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          child,
        ],
      );
}

InputDecoration decoracionCampo(BuildContext context, {String? hint, Widget? prefijo, Widget? sufijo, String? error}) =>
    InputDecoration(
      hintText: hint,
      prefixIcon: prefijo,
      suffixIcon: sufijo,
      errorText: error,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Paleta.de(context).borde)),
    );

/// Fila de dos campos en pantalla ancha, uno debajo del otro en el celular.
class FilaDoble extends StatelessWidget {
  final Widget a;
  final Widget b;
  final bool siempre;
  const FilaDoble(this.a, this.b, {super.key, this.siempre = false});

  @override
  Widget build(BuildContext context) {
    if (!siempre && MediaQuery.sizeOf(context).width < 520) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 12), b]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ]);
  }
}

/// Pastilla de estado de cita, como el renderer de la columna ESTADO del escritorio.
class EtiquetaEstado extends StatelessWidget {
  final String estado;
  const EtiquetaEstado(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = Tema.colorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: Tema.esOscuro(context) ? 0.25 : 0.12)),
      child: Text(Tema.etiquetaEstado(estado),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(color: Tema.legible(context, color), fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}
