/// User-facing command reference for the help sheet (Spanish copy).
library;

class CommandHelp {
  const CommandHelp(this.usage, this.description, {this.example});
  final String usage;
  final String description;

  /// Text inserted in the prompt when tapped (defaults to the command name).
  final String? example;
}

const Map<String, List<CommandHelp>> commandHelp = {
  'Navegar': [
    CommandHelp('menu', 'Vuelve al menú principal (las carpetas raíz).'),
    CommandHelp('cd <carpeta>', 'Entra a una carpeta. "cd .." sube, "cd -" vuelve a la anterior.',
        example: 'cd '),
    CommandHelp('ls [carpeta]', 'Muestra qué hay dentro de una carpeta.'),
    CommandHelp('pwd', 'Dice en qué carpeta estás.'),
  ],
  'Reproducir': [
    CommandHelp('play [carpeta|canción]', 'Reproduce la carpeta actual, otra carpeta o una canción.',
        example: 'play '),
    CommandHelp('play -s', 'Reproduce la carpeta actual en aleatorio.'),
    CommandHelp('pause · stop · next · prev', 'Controles básicos.', example: 'next'),
    CommandHelp('shuffle [on|off]', 'Activa o desactiva el aleatorio.', example: 'shuffle'),
    CommandHelp('repeat [off|one|all]', 'Repetir nada, una canción o toda la lista.',
        example: 'repeat '),
    CommandHelp('sleep <minutos|off>', 'Pausa la música después de X minutos.',
        example: 'sleep 30'),
    CommandHelp('np', 'Abre la pantalla de la canción que suena.'),
  ],
  'Buscar': [
    CommandHelp('<texto>', 'Cualquier texto que no sea un comando busca canciones y carpetas '
        '(sin importar tildes). Enter reproduce los resultados.', example: ''),
    CommandHelp('find <texto>', 'Igual que escribir el texto directamente.', example: 'find '),
  ],
  'Archivos': [
    CommandHelp('mkdir <nombre>', 'Crea una carpeta en la carpeta actual.', example: 'mkdir '),
    CommandHelp('mv <canción> <carpeta>', 'Mueve una canción. Usa comillas si hay espacios: '
        'mv "El Triste" Baladas', example: 'mv '),
    CommandHelp('rm <canción>', 'Borra una canción.', example: 'rm '),
    CommandHelp('rm -r <carpeta>', 'Borra una carpeta con todas sus canciones.', example: 'rm -r '),
    CommandHelp('rmdir <carpeta>', 'Borra una carpeta vacía.', example: 'rmdir '),
  ],
  'Biblioteca': [
    CommandHelp('refresh', 'Vuelve a buscar canciones nuevas.'),
    CommandHelp('sort <name|date>', 'Ordena por nombre o por fecha.', example: 'sort name'),
    CommandHelp('hide <carpeta>', 'Oculta una carpeta (notas de voz, etc.).', example: 'hide '),
    CommandHelp('unhide [carpeta]', 'Lista o recupera carpetas ocultas.', example: 'unhide'),
    CommandHelp('clear', 'Limpia los mensajes de la terminal.'),
  ],
};
