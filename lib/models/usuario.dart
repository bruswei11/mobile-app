class Usuario {
  final int id;
  final String usuario;
  final String nombre;
  final String rol;
  final bool activo;

  Usuario(this.id, this.usuario, this.nombre, this.rol, this.activo);

  factory Usuario.fromJson(Map<String, dynamic> j) =>
      Usuario(j['id'], j['usuario'], j['nombre'], j['rol'], j['activo'] ?? true);

  static String etiquetaRol(String rol) {
    switch (rol) {
      case 'admin':
        return 'Administrador/a';
      case 'psicologo':
        return 'Profesional de Psicología';
      case 'secretaria':
        return 'Usuario autorizado';
      default:
        return rol;
    }
  }
}

class RegistroAuditoria {
  final int id;
  final String usuarioNombre;
  final String accion;
  final String entidad;
  final int? entidadId;
  final String? detalle;
  final String fecha;

  RegistroAuditoria(this.id, this.usuarioNombre, this.accion, this.entidad, this.entidadId, this.detalle, this.fecha);

  factory RegistroAuditoria.fromJson(Map<String, dynamic> j) => RegistroAuditoria(
        j['id'],
        j['usuarioNombre'],
        j['accion'],
        j['entidad'],
        j['entidadId'],
        j['detalle'],
        j['fecha'],
      );
}
