class Sesion {
  int? id;
  int pacienteId;
  int? psicologoId;
  String? psicologoNombre;
  int? turnoId;
  String? subjetivo;
  String? objetivo;
  String? analisis;
  String? plan;
  String? notasPrivadas;
  int? duracionMinutos;
  int? duracionSegundos;
  String? fecha;

  Sesion({
    this.id,
    required this.pacienteId,
    this.psicologoId,
    this.psicologoNombre,
    this.turnoId,
    this.subjetivo,
    this.objetivo,
    this.analisis,
    this.plan,
    this.notasPrivadas,
    this.duracionMinutos,
    this.duracionSegundos,
    this.fecha,
  });

  factory Sesion.fromJson(Map<String, dynamic> j) => Sesion(
        id: j['id'],
        pacienteId: j['pacienteId'],
        psicologoId: j['psicologoId'],
        psicologoNombre: j['psicologoNombre'],
        turnoId: j['turnoId'],
        subjetivo: j['subjetivo'],
        objetivo: j['objetivo'],
        analisis: j['analisis'],
        plan: j['plan'],
        notasPrivadas: j['notasPrivadas'],
        duracionMinutos: j['duracionMinutos'],
        duracionSegundos: j['duracionSegundos'],
        fecha: j['fecha'],
      );

  Map<String, dynamic> toJson() => {
        'pacienteId': pacienteId,
        'turnoId': turnoId,
        'subjetivo': subjetivo,
        'objetivo': objetivo,
        'analisis': analisis,
        'plan': plan,
        'notasPrivadas': notasPrivadas,
        'duracionMinutos': duracionMinutos,
        'duracionSegundos': duracionSegundos,
      };

  String duracionTexto() {
    if (duracionMinutos == null) return '-';
    return '$duracionMinutos min ${(duracionSegundos ?? 0).toString().padLeft(2, '0')} seg';
  }
}
