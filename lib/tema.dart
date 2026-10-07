import 'package:flutter/material.dart';

/// Equivalente móvil de Vista/Tema.java del escritorio: una sola fuente para colores, textos de
/// rol/estado, formato de fechas y los "ladrillos" visuales que se repiten (encabezado con
/// degradé, tarjeta de sección, estado vacío, confirmaciones). Ninguna pantalla debería declarar
/// sus propios colores sueltos.
class Tema {
  Tema._();

  // Mismo violeta/azul del banner real del Departamento (ver Tema.PRIMARIO/SECUNDARIO).
  static const primario = Color(0xFF4B3A8C);
  static const primarioClaro = Color(0xFF5B48A3);
  static const secundario = Color(0xFF2F5AA8);
  static const exito = Color(0xFF0D9476);
  static const peligro = Color(0xFFC43A3A);
  static const ambar = Color(0xFFCA7106);
  static const rosa = Color(0xFFDB2777);

  // Variantes para modo oscuro (mismos valores que el escritorio).
  static const primarioOscuro = Color(0xFF8B7CD8);
  static const secundarioOscuro = Color(0xFF6D93DB);

  static ThemeData claro() => _tema(Brightness.light);
  static ThemeData oscuro() => _tema(Brightness.dark);

  static ThemeData _tema(Brightness brillo) {
    final oscuro = brillo == Brightness.dark;
    final esquema = ColorScheme.fromSeed(
      seedColor: primario,
      brightness: brillo,
      primary: oscuro ? primarioOscuro : primario,
      onPrimary: Colors.white,
      secondary: oscuro ? secundarioOscuro : secundario,
      onSecondary: Colors.white,
      error: oscuro ? const Color(0xFFE37070) : peligro,
      surface: oscuro ? const Color(0xFF1E1F22) : const Color(0xFFF6F5FB),
    );
    final base = ThemeData(colorScheme: esquema, useMaterial3: true, brightness: brillo);
    return base.copyWith(
      scaffoldBackgroundColor: esquema.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: esquema.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: oscuro ? const Color(0xFF2B2D30) : Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: oscuro ? const Color(0xFF3C3F43) : const Color(0xFFE2E6EC)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: oscuro ? const Color(0xFF2B2D30) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: oscuro ? const Color(0xFF52565A) : const Color(0xFFE2E6EC)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      // Transición suave entre pantallas (el equivalente de Tema.cambiarConFundido).
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }

  static bool esOscuro(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// Los colores de marca/estado son oscuros: sobre fondo oscuro se aclaran para que se lean.
  static Color legible(BuildContext context, Color c) => esOscuro(context) ? Color.lerp(c, Colors.white, 0.4)! : c;

  static Color textoSecundario(BuildContext context) =>
      esOscuro(context) ? const Color(0xFF969696) : const Color(0xFF6C7582);

  // ---------------------------------------------------------------- textos del colegio

  /// Mismas etiquetas que Tema.etiquetaRol del escritorio (el valor guardado no cambia).
  static String etiquetaRol(String? rol) {
    switch (rol) {
      case 'admin':
        return 'Administrador/a';
      case 'psicologo':
        return 'Profesional de Psicología';
      case 'secretaria':
        return 'Usuario autorizado';
      default:
        return rol ?? '';
    }
  }

  /// Mismas etiquetas que Tema.etiquetaEstadoCita del escritorio.
  static String etiquetaEstado(String? estado) {
    switch (estado) {
      case 'programado':
        return 'Programada';
      case 'completado':
        return 'Realizada';
      case 'cancelado':
        return 'Cancelada';
      case 'ausente':
        return 'No asistió';
      default:
        return estado ?? '';
    }
  }

  static Color colorEstado(String? estado) {
    switch (estado) {
      case 'completado':
        return exito;
      case 'cancelado':
        return peligro;
      case 'ausente':
        return ambar;
      default:
        return secundario;
    }
  }

  static IconData iconoEstado(String? estado) {
    switch (estado) {
      case 'completado':
        return Icons.check_circle_outline;
      case 'cancelado':
        return Icons.cancel_outlined;
      case 'ausente':
        return Icons.person_off_outlined;
      default:
        return Icons.schedule;
    }
  }

  // ---------------------------------------------------------------- fechas

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];
  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

  static DateTime? parsear(String? iso) => iso == null ? null : DateTime.tryParse(iso);

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// dd/MM/yyyy HH:mm, igual que las tablas del escritorio.
  static String fechaHora(String? iso) {
    final d = parsear(iso);
    if (d == null) return iso ?? '';
    return '${_dos(d.day)}/${_dos(d.month)}/${d.year} ${_dos(d.hour)}:${_dos(d.minute)}';
  }

  static String fecha(String? iso) {
    final d = parsear(iso);
    if (d == null) return iso ?? '';
    return '${_dos(d.day)}/${_dos(d.month)}/${d.year}';
  }

  static String hora(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';

  static String nombreMes(int mes) => _meses[mes - 1];

  static String mesAnio(DateTime d) {
    final m = _meses[d.month - 1];
    return '${m[0].toUpperCase()}${m.substring(1)} ${d.year}';
  }

  /// "Hoy", "Mañana", "Ayer" o "jueves 2 de octubre".
  static String diaLegible(DateTime d) {
    final hoy = DateTime.now();
    final soloFecha = DateTime(d.year, d.month, d.day);
    final diferencia = soloFecha.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Mañana';
    if (diferencia == -1) return 'Ayer';
    final dia = _dias[d.weekday - 1];
    final texto = '${dia[0].toUpperCase()}${dia.substring(1)} ${d.day} de ${_meses[d.month - 1]}';
    return d.year == hoy.year ? texto : '$texto de ${d.year}';
  }

  static String fechaLarga(DateTime d) {
    final t = '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]} de ${d.year}';
    return t[0].toUpperCase() + t.substring(1);
  }

  static String isoLocal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_dos(d.month)}-${_dos(d.day)}T${_dos(d.hour)}:${_dos(d.minute)}:00';

  static String isoFecha(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_dos(d.month)}-${_dos(d.day)}';

  static String saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  static String iniciales(String texto) {
    final partes = texto.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  // ---------------------------------------------------------------- avisos

  static void aviso(BuildContext context, String texto, {bool error = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: error ? peligro : null,
      ));
  }

  /// Como Tema.confirmar del escritorio: título, explicación y un botón de acción explícito.
  static Future<bool> confirmar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required String accion,
    bool peligroso = false,
    String cancelar = 'Cancelar',
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelar)),
          FilledButton(
            style: peligroso ? FilledButton.styleFrom(backgroundColor: peligro, minimumSize: const Size(0, 40)) : FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return r == true;
  }

  /// Pregunta antes de descartar un formulario con cambios (mismo texto que el escritorio).
  static Future<bool> confirmarDescartar(BuildContext context) => confirmar(
        context,
        titulo: 'Descartar cambios',
        mensaje: 'Hay datos sin guardar. Si salís ahora se pierden.',
        accion: 'Descartar',
        cancelar: 'Seguir editando',
        peligroso: true,
      );
}

/// Banner superior con degradé SECUNDARIO→PRIMARIO (Tema.panelEncabezado del escritorio).
class EncabezadoDegradado extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? arriba;
  final Widget? abajo;
  final List<Widget> acciones;
  final Widget? inicio;

  const EncabezadoDegradado({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.arriba,
    this.abajo,
    this.acciones = const [],
    this.inicio,
  });

  @override
  Widget build(BuildContext context) {
    final oscuro = Tema.esOscuro(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: oscuro
              ? [const Color(0xFF26407A), const Color(0xFF3B2E70)]
              : [Tema.secundario, Tema.primario],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?arriba,
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (inicio != null) ...[inicio!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        if (subtitulo != null && subtitulo!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitulo!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5)),
                          ),
                      ],
                    ),
                  ),
                  ...acciones,
                ],
              ),
              if (abajo != null) ...[const SizedBox(height: 12), Padding(padding: const EdgeInsets.only(right: 8), child: abajo!)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón de ícono blanco para usar sobre el encabezado degradado.
class BotonEncabezado extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;
  const BotonEncabezado({super.key, required this.icono, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icono, color: Colors.white),
      );
}

/// Tarjeta con título de sección en el color de marca (Tema.tituloSeccion del escritorio).
class TarjetaSeccion extends StatelessWidget {
  final String titulo;
  final IconData? icono;
  final Widget child;
  final Widget? accion;
  final EdgeInsetsGeometry padding;
  final String? numero;

  const TarjetaSeccion({
    super.key,
    required this.titulo,
    required this.child,
    this.icono,
    this.accion,
    this.numero,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (numero != null) ...[
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: color,
                    child: Text(numero!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                ] else if (icono != null) ...[
                  Icon(icono, size: 18, color: color),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14.5)),
                ),
                ?accion,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Mensaje centrado para listas vacías o errores, con acción opcional.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? detalle;
  final String? accion;
  final VoidCallback? onAccion;
  final bool error;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
    this.onAccion,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = error ? Theme.of(context).colorScheme.error : Tema.textoSecundario(context);
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 52, color: color.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (detalle != null) ...[
              const SizedBox(height: 6),
              Text(detalle!, textAlign: TextAlign.center, style: TextStyle(color: Tema.textoSecundario(context))),
            ],
            if (accion != null && onAccion != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAccion, child: Text(accion!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pastilla de color con texto (estado de cita, alertas de la lista).
class Pastilla extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;
  const Pastilla({super.key, required this.texto, required this.color, this.icono});

  @override
  Widget build(BuildContext context) {
    final c = Tema.legible(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: Tema.esOscuro(context) ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 13, color: c), const SizedBox(width: 4)],
          Flexible(
            child: Text(texto,
                overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Círculo con iniciales en el color de marca.
class AvatarIniciales extends StatelessWidget {
  final String nombre;
  final double radio;
  final Color? color;
  const AvatarIniciales({super.key, required this.nombre, this.radio = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: radio,
      backgroundColor: c.withValues(alpha: Tema.esOscuro(context) ? 0.3 : 0.14),
      child: Text(Tema.iniciales(nombre),
          style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: radio * 0.72)),
    );
  }
}
