import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/estructura_academica.dart';
import '../../models/turno.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/descargas.dart';
import '../../tema.dart';
import '../../ui/componentes.dart';

/// ImportarEstudiantes del escritorio: (1) cómo preparar la planilla + planilla modelo,
/// (2) vista previa fila por fila (Se importa / con advertencia / No se importa + motivo) con
/// "Profesional asignado a todos" antes de confirmar. El servidor vuelve a validar al confirmar.
class ImportarEstudiantes {
  /// Devuelve cuántos estudiantes se importaron (null si se canceló).
  static Future<int?> iniciar(BuildContext context) async {
    final elegido = await mostrarHoja<bool>(
      context,
      titulo: 'Importar estudiantes desde Excel',
      subtitulo: 'Cargá un curso entero de una vez',
      ancho: 640,
      contenido: (_) => const Text.rich(TextSpan(style: TextStyle(fontSize: 14.5, height: 1.45), children: [
        TextSpan(text: '1. ', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: 'En Excel, armá una planilla con una fila por estudiante. La primera fila tiene que tener los nombres de las columnas: '),
        TextSpan(text: 'Nombre', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: ' y '),
        TextSpan(text: 'Apellido', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: ' (obligatorias), y si querés '),
        TextSpan(text: 'CI, Teléfono, Género, Fecha de nacimiento', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: ' (dd/mm/aaaa), '),
        TextSpan(text: 'Curso, Tutor/a, CI del tutor/a', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: '.\n\n'),
        TextSpan(text: '2. ', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: 'Guardala con '),
        TextSpan(text: 'Archivo → Guardar como → CSV', style: TextStyle(fontStyle: FontStyle.italic)),
        TextSpan(text: '.\n\n'),
        TextSpan(text: '3. ', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: 'Tocá '),
        TextSpan(text: 'Elegir archivo', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: '. Antes de importar vas a ver fila por fila qué se carga.\n\n'),
        TextSpan(text: 'Si no tenés una planilla, '),
        TextSpan(text: 'Descargar planilla modelo', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: ' te da una con las columnas correctas (también sirve un listado exportado desde el sistema).'),
      ])),
      acciones: (ctx) => [
        Boton('Descargar planilla modelo', icono: Icons.file_download_outlined, onPressed: () => _planillaModelo(ctx)),
        Boton.primario('Elegir archivo…', icono: Icons.folder_open, onPressed: () => Navigator.pop(ctx, true)),
      ],
    );
    if (elegido != true || !context.mounted) return null;

    final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv', 'txt']);
    if (archivo == null || !context.mounted) return null;
    final bytes = await archivo.readAsBytes();
    if (!context.mounted) return null;
    Map<String, dynamic> resultado;
    try {
      resultado = await ApiClient.instancia.subir('/api/importacion/previsualizar', bytes, archivo.name) as Map<String, dynamic>;
    } catch (e) {
      if (context.mounted) Tema.aviso(context, 'No se pudo leer el archivo: $e', error: true);
      return null;
    }
    if (!context.mounted) return null;
    final filas = (resultado['filas'] as List).cast<Map<String, dynamic>>();
    final reconocidas = (resultado['columnasReconocidas'] as List).cast<String>();
    if (reconocidas.isEmpty || filas.isEmpty) {
      await confirmar(context,
          titulo: 'No hay nada para importar',
          mensaje: filas.isEmpty && reconocidas.isNotEmpty
              ? 'El archivo no tiene filas de estudiantes debajo de los encabezados.'
              : 'No se reconoció ninguna columna. La primera fila tiene que tener los nombres de las columnas (Nombre, Apellido, CI, Curso…).',
          accion: 'Entendido');
      return null;
    }
    return _vistaPrevia(context, archivo.name, resultado, filas);
  }

  static void _planillaModelo(BuildContext context) {
    if (!Descargas.disponible) {
      Tema.aviso(context, 'Disponible en la versión web (navegador)', error: true);
      return;
    }
    final cursos = <String>[
      EstructuraAcademica.etiquetaEEB(EstructuraAcademica.gradosEEB.first, EstructuraAcademica.seccionesEEB.first,
          EstructuraAcademica.turnoManana),
    ];
    Descargas.guardarTexto(
      'Apellido;Nombre;CI;Teléfono;Género;Fecha de nacimiento;Curso;Tutor/a;CI del tutor/a\r\n'
      'Pérez;Ana;5123456;0981 000000;Femenino;15/03/2011;${cursos.first};María González;1234567\r\n',
      'Planilla_modelo_importar_estudiantes.csv',
      'text/csv',
    );
    Tema.aviso(context, 'Planilla modelo descargada: Planilla_modelo_importar_estudiantes.csv');
  }

  static Future<int?> _vistaPrevia(BuildContext context, String nombreArchivo, Map<String, dynamic> resultado,
      List<Map<String, dynamic>> filas) async {
    final auth = context.read<AuthService>();
    List<Psicologo> profesionales = [];
    if (!auth.esPsicologo) {
      try {
        profesionales = ((await ApiClient.instancia.get('/api/turnos/psicologos')) as List).map((e) => Psicologo.fromJson(e)).toList();
      } catch (_) {}
    }
    if (!context.mounted) return null;
    final aImportar = filas.where((f) => f['estado'] != 'ERROR').toList();
    final conAdvertencia = filas.where((f) => f['estado'] == 'ADVERTENCIA').length;
    final ignoradas = (resultado['columnasIgnoradas'] as List).cast<String>();
    int? profesionalId;
    bool importando = false;

    return mostrarHoja<int>(
      context,
      titulo: 'Vista previa: $nombreArchivo',
      subtitulo: '${aImportar.length} se importan'
          '${conAdvertencia > 0 ? ' ($conAdvertencia con advertencia)' : ''} · ${filas.length - aImportar.length} no se importan',
      ancho: 900,
      conScroll: false,
      contenido: (ctx) => StatefulBuilder(builder: (ctx, setEstado) {
        final p = Paleta.de(ctx);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Columnas reconocidas: ${(resultado['columnasReconocidas'] as List).join(', ')}'
              '${ignoradas.isEmpty ? '' : '   ·   Ignoradas: ${ignoradas.join(', ')}'}',
              style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
          const SizedBox(height: 10),
          SizedBox(
            height: 330,
            child: Tabla<Map<String, dynamic>>(
              filas: filas,
              vacio: 'Sin filas',
              columnas: [
                Columna('Fila', (f) => Columna.texto('${f['numeroLinea']}'), flex: 1),
                Columna('Estudiante', (f) => Columna.texto('${f['paciente']['apellido'] ?? ''}, ${f['paciente']['nombre'] ?? ''}'), flex: 3),
                Columna('CI', (f) => Columna.texto(f['paciente']['ci']), flex: 2),
                Columna('Curso', (f) => Columna.texto(f['paciente']['curso']), flex: 3),
                Columna('Resultado', (f) => _resultado(ctx, f), flex: 2),
                Columna('Observaciones', (f) => Tooltip(
                      message: (f['observaciones'] as List).join(' · '),
                      child: Columna.texto((f['observaciones'] as List).isEmpty ? 'Listo para importar' : (f['observaciones'] as List).join(' · ')),
                    ), flex: 5),
              ],
              tarjeta: (f) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${f['paciente']['apellido'] ?? ''}, ${f['paciente']['nombre'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700))),
                  _resultado(ctx, f),
                ]),
                Text('Fila ${f['numeroLinea']} · ${(f['observaciones'] as List).isEmpty ? 'Listo para importar' : (f['observaciones'] as List).join(' · ')}',
                    style: TextStyle(fontSize: 12.5, color: p.textoSecundario)),
              ]),
            ),
          ),
          if (!auth.esPsicologo) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Text('Profesional asignado a todos: '),
              const SizedBox(width: 8),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<int?>(
                  initialValue: profesionalId,
                  isExpanded: true,
                  decoration: decoracionCampo(ctx),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Sin asignar')),
                    ...profesionales.map((x) => DropdownMenuItem<int?>(value: x.id, child: Text(x.nombre))),
                  ],
                  onChanged: (v) => setEstado(() => profesionalId = v),
                ),
              ),
            ]),
          ],
        ]);
      }),
      acciones: (ctx) => [
        Boton('Cancelar', onPressed: () => Navigator.pop(ctx)),
        StatefulBuilder(
          builder: (ctx2, setEstado) => Boton.exito(
            'Importar ${aImportar.length} estudiante${aImportar.length == 1 ? '' : 's'}',
            icono: Icons.check,
            cargando: importando,
            onPressed: aImportar.isEmpty
                ? null
                : () async {
                    setEstado(() => importando = true);
                    try {
                      final r = await ApiClient.instancia.post('/api/importacion/confirmar', {
                        'archivo': nombreArchivo,
                        'psicologoId': profesionalId,
                        'pacientes': aImportar.map((f) => f['paciente']).toList(),
                      });
                      if (!ctx.mounted) return;
                      final omitidos = (r['omitidos'] as List).length;
                      Tema.aviso(ctx, '${r['importados']} estudiante(s) importados${omitidos > 0 ? ' · $omitidos omitidos' : ''}');
                      Navigator.pop(ctx, r['importados'] as int);
                    } catch (e) {
                      setEstado(() => importando = false);
                      if (ctx.mounted) Tema.aviso(ctx, e.toString(), error: true);
                    }
                  },
          ),
        ),
      ],
    );
  }

  static Widget _resultado(BuildContext context, Map<String, dynamic> f) {
    final (texto, color) = switch (f['estado']) {
      'OK' => ('Se importa', Tema.exito),
      'ADVERTENCIA' => ('Con advertencia', Tema.ambar),
      _ => ('No se importa', Tema.peligro),
    };
    return Pastilla(texto: texto, color: color);
  }
}
