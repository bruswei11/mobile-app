const bool disponible = false;

void guardar(List<int> bytes, String nombre, String tipo) =>
    throw UnsupportedError('Descargar archivos está disponible en la versión web (navegador).');

void abrir(List<int> bytes, String nombre, String tipo) => guardar(bytes, nombre, tipo);
