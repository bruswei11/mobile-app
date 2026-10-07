/// Motivos frecuentes de atención -- misma lista que util.MotivosAtencion en el escritorio, para
/// que el conteo por motivo del Panel siga coincidiendo sin importar desde qué app se cargó.
const List<String> motivosFrecuentes = [
  'Incumplimiento de las normas de convivencia',
  'Agresión física a un compañero/a',
  'Agresión verbal o insultos',
  'Bullying o acoso escolar',
  'Conflicto entre compañeros',
  'Falta de respeto a un docente o autoridad',
  'Conducta disruptiva en el aula',
  'Uso inadecuado de dispositivos electrónicos',
  'Inasistencias o impuntualidad reiteradas',
  'Incumplimiento de tareas o materiales escolares',
  'Daño a bienes o materiales del colegio',
  'Uso de vocabulario inapropiado',
  'Consumo o posesión de sustancias prohibidas',
  'Situación familiar o emocional que afecta al estudiante',
];

const Map<String, String> tiposAcoso = {
  'directo': 'Acoso directo (físico)',
  'indirecto': 'Acoso indirecto (daño a bienes)',
  'verbal': 'Acoso verbal',
};

class Historia {
  int? id;
  int pacienteId;
  int? psicologoId;
  String? psicologoNombre;
  String? antecedentes;
  String? motivoConsulta;
  String? observacionesGenerales;
  String? diagnostico;
  String? tratamiento;
  String? codigoCie10;
  String? tipoAcoso;
  bool esReiterado;
  String? fechaCreacion;

  Historia({
    this.id,
    required this.pacienteId,
    this.psicologoId,
    this.psicologoNombre,
    this.antecedentes,
    this.motivoConsulta,
    this.observacionesGenerales,
    this.diagnostico,
    this.tratamiento,
    this.codigoCie10,
    this.tipoAcoso,
    this.esReiterado = false,
    this.fechaCreacion,
  });

  factory Historia.fromJson(Map<String, dynamic> j) => Historia(
        id: j['id'],
        pacienteId: j['pacienteId'],
        psicologoId: j['psicologoId'],
        psicologoNombre: j['psicologoNombre'],
        antecedentes: j['antecedentes'],
        motivoConsulta: j['motivoConsulta'],
        observacionesGenerales: j['observacionesGenerales'],
        diagnostico: j['diagnostico'],
        tratamiento: j['tratamiento'],
        codigoCie10: j['codigoCie10'],
        tipoAcoso: j['tipoAcoso'],
        esReiterado: j['esReiterado'] ?? false,
        fechaCreacion: j['fechaCreacion'],
      );

  Map<String, dynamic> toJson() => {
        'pacienteId': pacienteId,
        'antecedentes': antecedentes,
        'motivoConsulta': motivoConsulta,
        'observacionesGenerales': observacionesGenerales,
        'diagnostico': diagnostico,
        'tratamiento': tratamiento,
        'codigoCie10': codigoCie10,
        'tipoAcoso': tipoAcoso,
        'esReiterado': esReiterado,
      };
}
