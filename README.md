# Mptrack3 🎧

**Mptrack3** es un reproductor de música local con alma de terminal: fondo negro, verde brillante y una línea de comandos real (`mptrack3:~/Music$`) desde la que puedes navegar, buscar y organizar tu música. Hecho con Flutter para Android e iOS.

<p align="center">
  <img src="assets/icon.png" alt="Mptrack3" width="160">
</p>

<p align="center">
  <img src="assets/image-1.jpg" alt="Pantalla principal" width="300">
  &nbsp;
  <img src="assets/image-2.jpg" alt="Reproduciendo" width="300">
</p>

---

## ✨ Características

- **Navegador de carpetas.** La biblioteca se muestra como un árbol: entras a una carpeta y reproduces desde ahí.
- **Línea de comandos.** Escribe `cd`, `ls`, `play`, `mkdir`, `mv`, `rm`... Cualquier otro texto busca canciones y carpetas, sin importar tildes ni mayúsculas.
- **Organiza tu música.** Crea carpetas, mueve y borra canciones o carpetas completas (mantén pulsado un elemento o usa la barra superior).
- **Aleatorio de verdad.** No repite canciones hasta terminar el ciclo, "anterior" vuelve a lo que sonó y la lista se muestra en el orden en que va a sonar.
- **Pantalla "reproduciendo".** Carátula grande, lo que viene a continuación y gestos (desliza la carátula para cambiar de canción).
- **Biblioteca al día.** Detecta canciones nuevas sola, se refresca deslizando hacia abajo y recuerda tu última sesión.
- **Segundo plano.** Sigue sonando con la pantalla apagada, con controles en la notificación y en la pantalla de bloqueo.

## ⌨️ Comandos

Escribe `help` (o toca el botón **?**) para ver la lista dentro de la app.

| Comando | Qué hace |
|---|---|
| `menu` | vuelve al menú principal (carpetas raíz) |
| `cd <carpeta>` · `cd ..` · `cd ~` · `cd -` | navegar |
| `ls [carpeta]` · `pwd` | ver contenido / carpeta actual |
| `play [-s] [carpeta\|canción]` | reproducir (`-s` en aleatorio) |
| `pause` · `stop` · `next` · `prev` | controles |
| `shuffle [on\|off]` · `repeat [off\|one\|all]` | modos de reproducción |
| `find <texto>` (o solo escribir) | buscar |
| `mkdir <nombre>` | crear carpeta |
| `mv <canción> <carpeta>` | mover (usa comillas si hay espacios) |
| `rm <canción>` · `rm -r <carpeta>` · `rmdir <carpeta>` | borrar |
| `sleep <minutos\|off>` | temporizador de apagado |
| `sort <name\|date>` | ordenar canciones |
| `hide <carpeta>` · `unhide [carpeta]` | ocultar carpetas (notas de voz, etc.) |
| `refresh` · `clear` · `np` | refrescar, limpiar terminal, abrir "reproduciendo" |

## 📱 Plataformas

**Android**
- Lee la música con MediaStore usando solo el permiso `READ_MEDIA_AUDIO`, compatible con las políticas de Google Play.
- En Android 11+ el sistema pide confirmación al mover o borrar archivos.
- Android solo permite guardar música dentro de `Music/` (o `Podcasts/`, `Audiobooks/`...), así que las carpetas nuevas se crean ahí.

**iOS**
- iOS no permite leer la música de otras apps. La biblioteca de Mptrack3 es su carpeta en **Archivos → En mi iPhone → Mptrack3**: copia ahí tu música (con carpetas) y la app la detecta al volver a abrirla.

## 🛠️ Desarrollo

**Requisitos:** Flutter estable (Dart 3.9+), Android SDK 36, Xcode para iOS.

```bash
git clone https://github.com/ttmday/mptrack3.git
cd mptrack3
flutter pub get
flutter analyze
flutter test
flutter run
```

### Estructura

```
lib/
├── main.dart                 # arranque y providers
└── src/
    ├── library/              # lectura de la biblioteca (Android / iOS), búsqueda
    ├── model/                # Track y árbol de carpetas
    ├── player/               # audio_service + just_audio, orden aleatorio
    ├── browser/              # navegación por carpetas y búsqueda
    ├── terminal/             # intérprete de comandos
    ├── view/ y widget/       # pantallas y componentes
    └── l10n/                 # textos de la interfaz
android/.../MediaStoreBridge.kt   # acceso nativo a MediaStore
ios/Runner/AppDelegate.swift      # metadatos y carátulas en iOS
```

### Stack

- [just_audio](https://pub.dev/packages/just_audio): reproducción.
- [audio_service](https://pub.dev/packages/audio_service): segundo plano, notificación y pantalla de bloqueo.
- [Provider](https://pub.dev/packages/provider): estado de la app.
- [go_router](https://pub.dev/packages/go_router): navegación.
- Código nativo propio para MediaStore (Android) y AVFoundation (iOS).

## 🤝 Contribuir

Las contribuciones son bienvenidas. Lee [CONTRIBUTING.md](CONTRIBUTING.md) antes de abrir un pull request.

## 📄 Licencia

Mptrack3 se distribuye bajo la licencia **[PolyForm Noncommercial 1.0.0](LICENSE.md)**.

- ✅ Puedes usarla, estudiarla, modificarla, forkearla y compartirla **sin fines comerciales**.
- ✅ Si la compartes o publicas un fork, debes incluir la licencia y la línea `Required Notice` del autor.
- ❌ **No** puedes venderla ni usarla con fines comerciales (por ejemplo, publicarla de pago, con anuncios o como parte de un producto o servicio de una empresa).

Para cualquier uso comercial necesitas un permiso escrito del autor.

Copyright © 2024-2026 Eliezer Capuano ([@ttmday](https://github.com/ttmday)). Todos los derechos no concedidos expresamente por la licencia quedan reservados.

### Terceros

Las librerías de Flutter usadas y las fuentes incluidas mantienen sus propias licencias: **Ubuntu** ([Ubuntu Font Licence 1.0](https://ubuntu.com/legal/font-licence)) y **Jersey 10** ([SIL Open Font License 1.1](https://openfontlicense.org)).
