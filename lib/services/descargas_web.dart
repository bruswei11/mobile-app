import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

const bool disponible = true;

web.Blob _blob(List<int> bytes, String tipo) =>
    web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: tipo));

void guardar(List<int> bytes, String nombre, String tipo) {
  final url = web.URL.createObjectURL(_blob(bytes, tipo));
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..style.display = 'none';
  web.document.body!.append(enlace);
  enlace.click();
  enlace.remove();
  Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

void abrir(List<int> bytes, String nombre, String tipo) {
  final visible = tipo.startsWith('image/') || tipo.startsWith('application/pdf') || tipo.startsWith('text/plain');
  if (!visible) {
    guardar(bytes, nombre, tipo);
    return;
  }
  final url = web.URL.createObjectURL(_blob(bytes, tipo));
  web.window.open(url, '_blank');
  Future.delayed(const Duration(minutes: 5), () => web.URL.revokeObjectURL(url));
}
