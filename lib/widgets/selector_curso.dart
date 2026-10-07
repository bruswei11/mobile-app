import 'package:flutter/material.dart';
import '../models/estructura_academica.dart';
import '../tema.dart';

/// SelectorCursoSeccion del escritorio en versión táctil: pasos dependientes con chips
/// (Nivel → Grado + Sección, o Año + Modalidad + Especialidad → Turno). Solo se pueden formar
/// combinaciones que existen en el catálogo oficial. Informa la etiqueta canónica (null = sin
/// curso) y si quedó una selección a medias, que el formulario no deja guardar.
class SelectorCurso extends StatefulWidget {
  final String? inicial;
  final void Function(String? etiqueta, bool incompleto) alCambiar;
  const SelectorCurso({super.key, this.inicial, required this.alCambiar});

  @override
  State<SelectorCurso> createState() => _SelectorCursoState();
}

class _SelectorCursoState extends State<SelectorCurso> {
  late SeleccionCurso _s;
  bool _sinCurso = true;

  @override
  void initState() {
    super.initState();
    final parseado = EstructuraAcademica.parsear(widget.inicial);
    _s = parseado ?? SeleccionCurso();
    _sinCurso = parseado == null;
  }

  void _cambio(void Function() cambio) {
    setState(() {
      cambio();
      _s.ajustarTurno();
    });
    widget.alCambiar(_sinCurso ? null : _s.etiqueta, !_sinCurso && _s.etiqueta == null);
  }

  Widget _grupo(String titulo, List<String> opciones, String? elegido, ValueChanged<String> alElegir) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 12.5, color: Tema.textoSecundario(context))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: opciones
                .map((o) => ChoiceChip(
                      label: Text(o),
                      selected: o == elegido,
                      onSelected: (_) => alElegir(o),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final etiqueta = _s.etiqueta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'ninguno', label: Text('Sin curso')),
            ButtonSegment(value: 'eeb', label: Text('EEB')),
            ButtonSegment(value: 'bach', label: Text('Bachillerato')),
          ],
          selected: {_sinCurso ? 'ninguno' : (_s.esBachillerato ? 'bach' : 'eeb')},
          onSelectionChanged: (v) => _cambio(() {
            final elegido = v.first;
            _sinCurso = elegido == 'ninguno';
            if (!_sinCurso && (elegido == 'bach') != _s.esBachillerato) {
              _s = SeleccionCurso(esBachillerato: elegido == 'bach');
            }
          }),
        ),
        if (!_sinCurso && !_s.esBachillerato) ...[
          _grupo('Grado', EstructuraAcademica.gradosEEB, _s.grado, (v) => _cambio(() => _s.grado = v)),
          _grupo('Sección', EstructuraAcademica.seccionesEEB, _s.seccion, (v) => _cambio(() => _s.seccion = v)),
        ],
        if (!_sinCurso && _s.esBachillerato) ...[
          _grupo('Año', EstructuraAcademica.aniosBachillerato, _s.anio, (v) => _cambio(() => _s.anio = v)),
          _grupo('Modalidad', EstructuraAcademica.modalidades, _s.modalidad, (v) => _cambio(() {
                _s.modalidad = v;
                final esp = EstructuraAcademica.especialidadesPorModalidad(v);
                if (!esp.contains(_s.especialidad)) _s.especialidad = esp.length == 1 ? esp.first : null;
              })),
          if (_s.modalidad != null)
            _grupo('Especialidad', EstructuraAcademica.especialidadesPorModalidad(_s.modalidad), _s.especialidad,
                (v) => _cambio(() => _s.especialidad = v)),
        ],
        if (!_sinCurso && _s.turnosPosibles.isNotEmpty)
          _grupo('Turno', _s.turnosPosibles, _s.turno, (v) => _cambio(() => _s.turno = v)),
        if (!_sinCurso) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(etiqueta != null ? Icons.check_circle : Icons.info_outline,
                  size: 18, color: etiqueta != null ? Tema.exito : Tema.textoSecundario(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  etiqueta ?? 'Completá la selección para asignar el curso',
                  style: TextStyle(
                    fontWeight: etiqueta != null ? FontWeight.w600 : FontWeight.normal,
                    color: etiqueta != null ? null : Tema.textoSecundario(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
