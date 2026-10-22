# Mptrack3 🎧

**Mptrack3** es un reproductor de música local potente y minimalista desarrollado con Flutter. Diseñado para ofrecer una experiencia de audio premium, gestiona eficientemente la biblioteca del dispositivo y garantiza una reproducción ininterrumpida mediante servicios de audio en segundo plano.

<p align="center">
  <img src="assets/icon.png" alt="Mptrack3 Icon" width="200">
</p>

---

## ✨ Características Principales
* **Navegador de carpetas:** la biblioteca se muestra como un árbol; entra a una carpeta y reproduce desde ahí.
* **Línea de comandos real:** `mptrack3:~/Music$` entiende comandos (`cd`, `ls`, `play`, `mkdir`, `mv`, `rm`...). Cualquier otro texto es una búsqueda.
* **Gestión de archivos:** crear carpetas, mover y borrar canciones (mantén pulsado una canción o carpeta).
* **Aleatorio de verdad:** no repite canciones hasta terminar el ciclo, "anterior" vuelve a lo que sonó y la lista no se reordena.
* **Pantalla "reproduciendo":** carátula grande, cola de lo que sigue y gestos. Temporizador con `sleep`.
* **Biblioteca siempre al día:** detecta canciones nuevas, refresco manual (desliza hacia abajo) y recuerda la última sesión.
* **Segundo plano y notificación:** controles en la pantalla de bloqueo.

### Comandos

| Comando | Qué hace |
|---|---|
| `menu` | vuelve al menú principal (carpetas raíz) |
| `ls [carpeta]` | lista una carpeta |
| `cd <carpeta>` · `cd ..` · `cd ~` · `cd -` | navegar |
| `play [-s] [carpeta\|canción]` | reproducir (`-s` en aleatorio) |
| `pause` · `stop` · `next` · `prev` | transporte |
| `shuffle [on\|off]` · `repeat [off\|one\|all]` | modos |
| `find <texto>` (o solo escribir) | buscar sin importar tildes |
| `mkdir <nombre>` | crear carpeta aquí |
| `mv <canción> <carpeta>` | mover (usa comillas si hay espacios) |
| `rm <canción>` · `rm -r <carpeta>` · `rmdir <carpeta>` | borrar canción, carpeta con contenido o carpeta vacía |
| `sleep <min\|off>` | temporizador |
| `sort <name\|date>` | orden de las canciones |
| `hide <carpeta>` · `unhide [carpeta]` | ocultar carpetas (notas de voz, etc.) |
| `refresh` · `clear` · `np` · `pwd` | utilidades |
| `help` | abre la lista de comandos (también con el botón ?) |

### Plataformas
* **Android:** lee la música con MediaStore usando solo `READ_MEDIA_AUDIO` (compatible con las políticas de Google Play). En Android 11+ el sistema pide confirmación al mover o borrar. Por reglas de Android, la música solo puede moverse a carpetas dentro de `Music/` (o `Podcasts/`, `Audiobooks/`...).
* **iOS:** la biblioteca es la carpeta de la app en *Archivos → En mi iPhone → Mptrack3*. Copia ahí tu música (con carpetas) y la app la detecta al volver a abrirla.

---

## 🛠️ Stack Tecnológico

El rendimiento de **Mptrack3** se basa en la combinación de tres potentes motores de audio y un gestor de estado reactivo:

### 1. MediaStore / AVFoundation (código nativo propio)
`MediaStoreBridge.kt` (Android) y `AppDelegate.swift` (iOS) leen la biblioteca, las carátulas y hacen las operaciones de archivos.

### 2. [just_audio](https://pub.dev/packages/just_audio)
El motor de reproducción de alta fidelidad. Es responsable de la decodificación del audio, el manejo de la lista de reproducción (playlists), el control de volumen y la navegación entre pistas (seek/skip) con latencia mínima.

### 3. [audio_service](https://pub.dev/packages/audio_service)
La pieza clave para una experiencia profesional. Esta librería envuelve a `just_audio` en un servicio de fondo, permitiendo que el sistema operativo reconozca a Mptrack3 como un reproductor activo, habilitando los controles externos y manteniendo el proceso vivo aunque la app no esté en primer plano.

### 4. [Provider](https://pub.dev/packages/provider)
Utilizado para la gestión de estados global. Sincroniza la posición de la barra de progreso, el estado de pausa/play y la información de la canción actual en todas las pantallas de la aplicación.

---

<p align="center">
  <img src="assets/image-1.jpg" alt="App Image" width="360">
</p>


<p align="center">
  <img src="assets/image-2.jpg" alt="App Image" width="360">
</p>
