# Sistema de Gestión del Departamento de Psicología — pantallas web y Android

Interfaz del sistema del Departamento de Psicología del Colegio Nacional E.M.D. San Roque González de
Santacruz, hecha con **Flutter 3.47 / Dart 3.13**. Con el mismo código se genera:

- la **versión web**, publicada junto al servidor en https://psicologia-colegio.onrender.com
- la **app de Android** (`flutter build apk`).

Se conecta al servidor [backend-api](https://github.com/bruswei11/backend-api) (Spring Boot). El programa
de escritorio original está en [SistemaPsicologia](https://github.com/bruswei1/SistemaPsicologia).

## Carpetas

- `lib/pantallas` — menú, estudiantes (lista, ficha, atenciones, seguimiento, adjuntos), agenda, panel, reportes, configuración.
- `lib/services` — conexión con el servidor, sesión, bloqueo de pantalla, borradores automáticos.
- `lib/ui` — botones, tablas, paneles y estilos compartidos.
- `lib/models`, `lib/widgets` — datos y componentes (selector de curso, línea de tiempo).

## Compilar

```
flutter pub get
flutter build web --release
```

La carpeta `build/web` se copia a `backend-api/src/main/resources/static` (lo hace `backend-api/compilar-todo.bat`).
