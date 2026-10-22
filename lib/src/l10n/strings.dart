/// User-facing copy for menus and dialogs (Spanish).
///
/// Terminal output stays in English on purpose, like a real shell.
class Strings {
  const Strings._();

  static const loading = 'Cargando...';
  static const empty = '404';
  static const emptyHint = 'No hay canciones aquí. Escribe "help" abajo.';
  static const searchHint = 'busca una canción o escribe "help"';
  static const noResults = 'Sin resultados';
  static const resultsFor = 'resultados';
  static const folders = 'carpetas';
  static const tracks = 'canciones';
  static const unknown = 'Desconocido';

  static const permissionTitle = 'Sin acceso a la música';
  static const permissionBody =
      'Mptrack3 necesita permiso para leer tus archivos de audio.';
  static const permissionGrant = 'Dar acceso';
  static const permissionSettings = 'Abrir ajustes';
  static const loadError = 'No se pudo leer la biblioteca';
  static const retry = 'Reintentar';

  static const play = 'Reproducir';
  static const playShuffled = 'Reproducir en aleatorio';
  static const moveTo = 'Mover a carpeta...';
  static const delete = 'Eliminar';
  static const hideFolder = 'Ocultar carpeta';
  static const removeFolder = 'Borrar carpeta vacía';
  static const newFolder = 'Nueva carpeta';
  static const folderName = 'Nombre de la carpeta';
  static const moveHere = 'Mover aquí';
  static const create = 'Crear';
  static const cancel = 'Cancelar';
  static const confirm = 'Confirmar';
  static const location = 'Ubicación';

  static const nowPlaying = 'reproduciendo';
  static const upNext = 'a continuación';
  static const queueEmpty = 'La cola está vacía';

  static const deleteFolder = 'Eliminar carpeta';
  static const newFolderHere = 'Nueva carpeta aquí';
  static const home = 'Menú principal';
  static const help = 'Comandos';
  static const helpHint = 'Toca un comando para escribirlo abajo.';
  static String confirmDeleteSong(String title) =>
      '¿Borrar "$title" para siempre?';
  static String confirmDeleteSongs(int count) =>
      '¿Borrar $count canciones para siempre?';
  static String confirmDeleteFolder(String label, int count) => count == 0
      ? '¿Borrar la carpeta $label?'
      : '¿Borrar la carpeta $label y sus $count canciones? No se puede deshacer.';
}
