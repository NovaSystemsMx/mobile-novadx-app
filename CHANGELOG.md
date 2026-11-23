# Changelog

Todos los cambios notables de NovaDX se documentan aquí. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa
versiones `MAJOR.MINOR.PATCH+BUILD` (`pubspec.yaml`).

> [!NOTE]
> Los cambios en progreso se agrupan bajo `Unreleased`. Al publicar el release,
> ese encabezado se renombra con la versión correspondiente (por ejemplo
> `v0.2.4`) y se crea el tag del mismo nombre en GitHub.

---

## v0.2.4 - 2026-11-23

### Changed

- Las cards de posts con varios videos ya no muestran la etiqueta `Video 1`,
  `Video 2`, ...: son idénticas a la card de un solo video. El contador global
  (`x / N videos guardados`) y los botones **Descargar todos / Cancelar todos**
  no cambian.
- Versión del proyecto actualizada a `0.2.4+6` en `pubspec.yaml` y `README.md`.

---

## v0.2.3 - 2026-11-23

### Added

- `XVideoResolver.resolveAll()` resuelve **todos** los MP4 de un post (X permite
  hasta 4), eligiendo la mejor variante por bitrate de cada uno y omitiendo
  entradas sin URL válida. `resolve()` se mantiene como atajo al primero.
- La UI muestra una **card por video** con la misma distribución que el caso
  individual: miniatura 16:9, nombre de archivo, chips de resolución/peso,
  progreso y botones propios de descarga, cancelación y reintento.
- Acciones globales **Descargar todos / Descargar restantes** y **Cancelar
  todos**. Cada descarga corre en paralelo con su propio id de
  `DownloadManager`, progreso y notificación.
- Nombres de archivo `x_<statusId>_<n>.mp4` para posts con varios videos;
  `x_<statusId>.mp4` se conserva cuando hay uno solo.
- Test de resolución múltiple con `MockClient` que verifica la selección de
  variantes, la limpieza de parámetros `?tag=` y el descarte de entradas vacías.

### Changed

- Versión del proyecto actualizada a `0.2.3+5` en `pubspec.yaml` y `README.md`.
- Documentación de arquitectura, uso y flujo de resolución actualizada para
  reflejar las cards por video y las descargas paralelas.
