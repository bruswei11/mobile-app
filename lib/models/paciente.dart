class Paciente {
  int? id;
  String nombre;
  String apellido;
  String? ci;
  String? telefono;
  String? fechaNacimiento; // yyyy-MM-dd
  String? genero;
  String? nombreTutor;
  String? ciTutor;
  String? direccion;
  String? motivoConsulta;
  String? curso;
  String? antecedentesPersonales;
  String? antecedentesFamiliares;
  String? anamnesis;
  int? psicologoId;
  bool consentimientoTutor;
  String? consentimientoFecha;
  String? creadoEn;

  Paciente({
    this.id,
    required this.nombre,
    required this.apellido,
    this.ci,
    this.telefono,
    this.fechaNacimiento,
    this.genero,
    this.nombreTutor,
    this.ciTutor,
    this.direccion,
    this.motivoConsulta,
    this.curso,
    this.antecedentesPersonales,
    this.antecedentesFamiliares,
    this.anamnesis,
    this.psicologoId,
    this.consentimientoTutor = false,
    this.consentimientoFecha,
    this.creadoEn,
  });

  factory Paciente.fromJson(Map<String, dynamic> j) => Paciente(
        id: j['id'],
        nombre: j['nombre'] ?? '',
        apellido: j['apellido'] ?? '',
        ci: j['ci'],
        telefono: j['telefono'],
        fechaNacimiento: j['fechaNacimiento'],
        genero: j['genero'],
        nombreTutor: j['nombreTutor'],
        ciTutor: j['ciTutor'],
        direccion: j['direccion'],
        motivoConsulta: j['motivoConsulta'],
        curso: j['curso'],
        antecedentesPersonales: j['antecedentesPersonales'],
        antecedentesFamiliares: j['antecedentesFamiliares'],
        anamnesis: j['anamnesis'],
        psicologoId: j['psicologoId'],
        consentimientoTutor: j['consentimientoTutor'] ?? false,
        consentimientoFecha: j['consentimientoFecha'],
        creadoEn: j['creadoEn'],
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'ci': ci,
        'telefono': telefono,
        'fechaNacimiento': fechaNacimiento,
        'genero': genero,
        'nombreTutor': nombreTutor,
        'ciTutor': ciTutor,
        'direccion': direccion,
        'motivoConsulta': motivoConsulta,
        'curso': curso,
        'antecedentesPersonales': antecedentesPersonales,
        'antecedentesFamiliares': antecedentesFamiliares,
        'anamnesis': anamnesis,
        'psicologoId': psicologoId,
        'consentimientoTutor': consentimientoTutor,
      };

  String get nombreCompleto => '$nombre $apellido';
}
