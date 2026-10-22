# Cómo contribuir a Mptrack3

¡Gracias por querer ayudar! Esta guía explica cómo proponer cambios para que sea fácil revisarlos y aceptarlos.

## Antes de empezar

- Revisa los [issues](https://github.com/ttmday/mptrack3/issues) abiertos para ver si alguien ya está trabajando en lo mismo.
- Para cambios grandes (nuevas pantallas, cambios de arquitectura, nuevas dependencias) abre primero un issue y coméntalo. Así evitas trabajar en algo que luego no encaje.
- Los errores pequeños, typos y mejoras de documentación pueden ir directo a un pull request.

## Preparar el entorno

```bash
git clone https://github.com/<tu-usuario>/mptrack3.git
cd mptrack3
flutter pub get
flutter run
```

Necesitas Flutter estable (Dart 3.9+). Para iOS necesitas un Mac con Xcode.

## Flujo de trabajo

1. Haz un fork y crea una rama desde `main`:
   - `feat/<descripcion-corta>` para funciones nuevas
   - `fix/<descripcion-corta>` para errores
   - `docs/<descripcion-corta>` para documentación
2. Haz tus cambios en commits pequeños y con sentido.
3. Antes de abrir el pull request, comprueba que todo pasa:
   ```bash
   flutter analyze
   flutter test
   ```
4. Abre el pull request contra `main` explicando **qué** cambia, **por qué** y **cómo probarlo**. Si cambia algo visual, agrega capturas.

## Estilo de commits

El proyecto usa [Conventional Commits](https://www.conventionalcommits.org/) con [gitmoji](https://gitmoji.dev/) opcional:

```
feat: :sparkles: add sleep timer command
fix: :bug: keep shuffle order after deleting a song
docs: :memo: update command list
refactor: :recycle: split terminal controller
```

## Reglas del código

- **Todo el código va en inglés:** nombres de variables, clases, comentarios y mensajes de log o de la terminal.
- **Los textos de la interfaz van en `lib/src/l10n/`** (`strings.dart`, `help_content.dart`), nunca escritos directamente en los widgets.
- Respeta la estructura de carpetas (`library/`, `player/`, `terminal/`, `browser/`, `widget/`...). Si no sabes dónde va algo, pregunta en el issue.
- Formatea con `dart format .` y no dejes avisos de `flutter analyze`.
- Si tocas la lógica (orden aleatorio, búsqueda, árbol de carpetas, comandos), agrega o actualiza los tests en `test/`.
- Mantén el estilo visual: fondo oscuro, verde brillante y estética de terminal.

### Android e iOS

- **No agregues `MANAGE_EXTERNAL_STORAGE`** ni permisos de fotos o videos. La app debe seguir cumpliendo las políticas de Google Play: la música se lee con `READ_MEDIA_AUDIO` y las escrituras pasan por MediaStore (`MediaStoreBridge.kt`).
- Los cambios en código nativo (`MediaStoreBridge.kt`, `AppDelegate.swift`) deben probarse en un dispositivo real e indicar en el PR la versión de Android o iOS usada.
- Si un cambio solo funciona en una plataforma, el PR debe explicar cómo se comporta la otra.

## Reportar errores

Abre un issue con:

- Qué esperabas que pasara y qué pasó.
- Pasos para reproducirlo.
- Dispositivo, versión de Android o iOS y versión de la app.
- Capturas o logs si los tienes.

## Licencia de las contribuciones

Mptrack3 se distribuye bajo la licencia [PolyForm Noncommercial 1.0.0](LICENSE.md). Al enviar una contribución (código, diseño, documentación u otro material) confirmas que:

1. Es tu trabajo original o tienes derecho a aportarlo.
2. Aceptas que se distribuya bajo la misma licencia del proyecto.
3. Le concedes al autor del proyecto, Eliezer Capuano, un permiso perpetuo, mundial y sin costo para usar, modificar, sublicenciar y relicenciar tu contribución como parte de Mptrack3, incluso bajo otras licencias.

Si no estás de acuerdo con estos puntos, por favor no envíes la contribución.

## Conducta

Trata a los demás con respeto. Las críticas van dirigidas al código, no a las personas.
