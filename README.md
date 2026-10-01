# NovaDX

> **Descargador de videos de X (Twitter) con estilo terminal** — Pega el link, se resuelve solo y descarga el MP4 a `Movies/NovaDX` visible en galería. Stack: Flutter + Android DownloadManager + `api.fxtwitter.com`.

---

## Tabla de contenidos

1. [Descripción general](#descripción-general)
2. [Arquitectura del proyecto](#arquitectura-del-proyecto)
3. [Tecnologías utilizadas](#tecnologías-utilizadas)
4. [Instalación y configuración](#instalación-y-configuración)
5. [Firma de release (key.properties)](#firma-de-release-keyproperties)
6. [Comandos del proyecto](#comandos-del-proyecto)
7. [Uso de la app](#uso-de-la-app)
8. [Cómo funciona (resolución y descarga)](#cómo-funciona-resolución-y-descarga)
9. [Canal nativo Android](#canal-nativo-android)
10. [Permisos Android](#permisos-android)
11. [Distribución del APK](#distribución-del-apk)
12. [Seguridad](#seguridad)
13. [Troubleshooting](#troubleshooting)

---

## Descripción general

NovaDX (`downloader_x`, v`0.1.0+1`) resuelve el MP4 directo de un post de X sin API keys y lo descarga en segundo plano aunque salgas de la app.

Capacidades verificadas en código:

- *Auto-resolve con debounce 700 ms*: al detectar `x.com/.../status/<id>` o `twitter.com/.../status/<id>` inicia la búsqueda sin pulsar nada (`lib/screens/home_screen.dart`).
- *Autofill desde portapapeles* y *texto compartido* desde X u otra app (`Intent.ACTION_SEND`, `getSharedText`).
- *Mejor variante por bitrate*: filtra `content_type` con `mp4` y elige el mayor `bitrate`, con fallback a `video.url`.
- *Descarga en segundo plano* con `DownloadManager` del sistema, notificación `VISIBILITY_VISIBLE_NOTIFY_COMPLETED`, destino `Movies/NovaDX/<x_<id>.mp4>`.
- *Acciones post-descarga*: abrir con visor, compartir vía `Intent`, cancelar, consultar progreso.
- *UI estilo terminal*: fondo negro, monoespaciada, logo `NOVADX` con fuente `ArchivoBlack`.
- *Soporte web/desktop*: descarga vía navegador o disco según plataforma (`saver_web.dart` / `saver_native.dart`).

> [!NOTE]
> El APK release (`build/app/outputs/flutter-apk/app-release.apk`) **no se versiona**. Está ignorado en `.gitignore` vía `/build/`.

---

## Arquitectura del proyecto

```text
mobile-novadx-app/
├── lib/
│   ├── main.dart                 # MaterialApp 'NovaDX', theme oscuro, home: HomeScreen
│   ├── theme.dart                # Paleta terminal (AppColors), fuente mono, ThemeData dark
│   ├── screens/
│   │   └── home_screen.dart      # Input link, debounce, estados idle/resolving/preview/downloading/done/error
│   ├── services/
│   │   ├── x_video_resolver.dart # looksLikeXUrl(), resolve() vía https://api.fxtwitter.com/<path>
│   │   ├── video_downloader.dart # Descarga http con progreso (uso web/fallback), saveBytes por plataforma
│   │   ├── gallery_downloader.dart # MethodChannel novadx/gallery: enqueue/query/cancel/open/share
│   │   ├── saver_native.dart     # Temporal + MediaStore Movies/NovaDX (Android Q+) o dir externo
│   │   ├── saver_web.dart        # Descarga vía navegador
│   │   └── saver_stub.dart       # Selector condicional dart.library.io / js_interop
│   └── widgets/
│       └── block_logo.dart       # Texto NOVADX con ArchivoBlack, 52pt
├── android/
│   ├── app/build.gradle.kts      # applicationId com.novasystemsmx.novadx, firma release opcional
│   ├── app/src/main/AndroidManifest.xml # INTERNET, SEND text/plain, launchMode singleTop
│   └── app/src/main/kotlin/.../MainActivity.kt # DownloadManager + MediaStore + share intent
├── assets/
│   ├── fonts/ArchivoBlack-Regular.ttf
│   └── logo/novadx_1024.png, novadx_logo.svg, apk_qr.png
├── tool/
│   ├── apk_server.py             # Sirve app-release.apk en :8000 con MIME correcto
│   ├── gen_icons.py
│   └── make_qr.py
├── test/widget_test.dart
├── pubspec.yaml
└── analysis_options.yaml         # flutter_lints, excluye build/, android/, web/
```

---

## Tecnologías utilizadas

| Categoría | Tecnología | Versión |
| :--- | :--- | :--- |
| **Lenguaje** | Dart | SDK `^3.13.4` |
| **Framework** | Flutter | `flutter.sdk` (Material 3, `useMaterial3: true`) |
| **HTTP** | `http` | `^1.2.2` |
| **Filesystem** | `path_provider` | `^2.1.4` |
| **Web** | `web` | `^1.1.0` |
| **Lints** | `flutter_lints` | `^6.0.0` |
| **Test** | `flutter_test` | SDK |
| **Android** | Gradle + Kotlin, `compileSdk`/`targetSdk` de Flutter, Java/Kotlin 17 | ver `android/app/build.gradle.kts` |
| **Extractor** | `api.fxtwitter.com` (JSON público, sin keys) | externo |
| **Fuente** | ArchivoBlack | `assets/fonts/ArchivoBlack-Regular.ttf` |

---

## Instalación y configuración

Prerrequisitos:

- Flutter SDK (canal estable, con Dart `>=3.13`)
- Android SDK + JDK 17 para `flutter build apk`
- Python 3 solo para `tool/apk_server.py` (distribución local)

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Build release local:

```bash
flutter build apk --release
```

Salida (no versionada):

```text
build/app/outputs/flutter-apk/app-release.apk
```

> [!TIP]
> Si R8 rompe la instalación, el proyecto ya trae `isMinifyEnabled = false` e `isShrinkResources = false` en el `buildType release`. No los actives sin probar instalación limpia.

---

## Firma de release (key.properties)

El `build.gradle.kts` carga `android/key.properties` si existe; si no, firma con `debug` para no romper builds locales.

`android/key.properties` (no crear por defecto, ejemplo):

```properties
storeFile=/ruta/absoluta/a/novadx.jks
storePassword=*****
keyAlias=novadx
keyPassword=*****
```

> [!WARNING]
> Nunca subas `key.properties`, `*.jks`, `*.keystore`, `*.p12` ni `*.pepk`. Ya están ignorados en `.gitignore`.

---

## Comandos del proyecto

| Comando | Descripción |
| :--- | :--- |
| `flutter pub get` | Instala dependencias (`http`, `path_provider`, `web`) |
| `flutter run` | Ejecuta en debug en dispositivo/emulador |
| `flutter analyze` | Lints (`flutter_lints`) |
| `flutter test` | Tests (`test/widget_test.dart`) |
| `flutter build apk --release` | Genera `app-release.apk` |
| `flutter build appbundle --release` | Genera AAB para Play Store |
| `python tool/apk_server.py` | Sirve el APK en `http://<ip>:8000` con `Content-Type: application/vnd.android.package-archive` |

---

## Uso de la app

1. Copia un link tipo `https://x.com/usuario/status/123...`.
2. Abre NovaDX: si el portapapeles trae el link, se autorellena.
3. O comparte desde X con **Compartir → NovaDX**.
4. Espera ~700 ms: aparece preview (`x_<id>.mp4` + peso estimado vía `HEAD` `content-length`).
5. Pulsa **Descargar**: Android muestra notificación del sistema con progreso.
6. Al terminar: **Abrir** o **Compartir** desde la app o la notificación.

Nombre de archivo: `x_<statusId>.mp4`. Si existe, `DownloadManager` lo reemplaza (borra previo + `scanFile`).

---

## Cómo funciona (resolución y descarga)

```text
input link
  -> XVideoResolver.looksLikeXUrl()  // ^https?://(www.)?(twitter|x).com/.../status/\d+
  -> GET https://api.fxtwitter.com/<usuario>/status/<id>  (timeout 20s, UA: downloader_x/1.0)
  -> tweet.media.videos[0].variants  // filtra mp4, max bitrate
  -> ResolvedVideo(downloadUrl, thumbnailUrl, width, height, bitrate)
  -> HEAD downloadUrl -> etiqueta "Aprox X.X MB"
  -> DownloadManager.enqueue -> Movies/NovaDX/x_<id>.mp4
```

Ejemplo real:

```bash
curl https://api.fxtwitter.com/nasa/status/1234567890
```

```json
{
  "tweet": {
    "media": {
      "videos": [
        {
          "url": "https://video.twimg.com/...mp4",
          "thumbnail_url": "https://pbs.twimg.com/...jpg",
          "width": 1280,
          "height": 720,
          "variants": [
            {"content_type": "video/mp4", "bitrate": 2176000, "url": "https://.../720.mp4"},
            {"content_type": "video/mp4", "bitrate": 832000, "url": "https://.../480.mp4"}
          ]
        }
      ]
    }
  }
}
```

La app elige `720.mp4` (mayor bitrate).

Errores conocidos (mensajes en español en UI):

- `El enlace no parece un post de X...`
- `No pude identificar el id del post...`
- `El post no existe o fue eliminado.` (404)
- `Este post no contiene ningun video.`
- `No pude conectar con el servicio de extraccion.` (timeout/red)

---

## Canal nativo Android

`MethodChannel('novadx/gallery')` en `MainActivity.kt`:

| Método | Args | Descripción |
| :--- | :--- | :--- |
| `enqueueDownload` | `url`, `fileName` | `DownloadManager.enqueue` a `Movies/NovaDX`, retorna `id: Long` |
| `queryProgress` | `id` | `{received, total, status, fileName}` desde `DownloadManager.Query` |
| `cancelDownload` | `id` | `dm.remove(id)` |
| `openDownload` | `id` | `ACTION_VIEW` `video/*` con `FLAG_GRANT_READ_URI_PERMISSION` |
| `shareDownload` | `id` | `ACTION_SEND` `video/mp4` con chooser |
| `getSharedText` | — | Retorna y consume `Intent.EXTRA_TEXT` de `ACTION_SEND` |
| `saveVideo` | `path`, `fileName` | Mueve temporal a MediaStore (`RELATIVE_PATH Movies/NovaDX`, `IS_PENDING`) en Q+, o `Movies/NovaDX` legacy + `scanFile` |

---

## Permisos Android

| Permiso | Alcance | Descripción |
| :--- | :--- | :--- |
| `INTERNET` | siempre | Descargar JSON + MP4 |
| `WRITE_EXTERNAL_STORAGE` | `maxSdkVersion=28` | Solo Android 9 y anteriores; en 10+ usa MediaStore |

`launchMode="singleTop"` + `taskAffinity=""` para recibir `ACTION_SEND text/plain` sin duplicar activity.

---

## Distribución del APK

El APK no va a Git. Para pasarla a un dispositivo en red local:

```bash
flutter build apk --release
python tool/apk_server.py
# en el móvil: http://<ip-pc>:8000 -> descarga app-release.apk
```

> [!TIP]
> No uses `python -m http.server` para esto: no envía `application/vnd.android.package-archive` y algunos instaladores lo rechazan. Usa `tool/apk_server.py`.

---

## Seguridad

- Sin API keys en cliente; extractor público vía HTTPS.
- `User-Agent: downloader_x/1.0` fijo en `GET` y `HEAD`.
- Firma: `storeFile`, `storePassword`, `keyAlias`, `keyPassword` solo en `android/key.properties` local.
- Ignorados: `/build/`, `android/key.properties`, `**/*.jks`, `**/*.keystore`, `**/*.p12`, `**/*.pepk`, `app.*.symbols`, `app.*.map.json`.

---

## Troubleshooting

- **No resuelve**: verifica formato `.../status/<solo-dígitos>`. Los links `x.com/i/status` o con query rara no matchean el regex.
- **404 del extractor**: post eliminado/privado o `api.fxtwitter.com` caído; reintenta.
- **APK no instala tras activar R8**: deja `isMinifyEnabled=false`, `isShrinkResources=false` (estado actual).
- **`key.properties` ausente**: el build firma con `debug`; es intencional para pruebas locales.
- **No aparece en galería (Android <10)**: requiere `MediaScannerConnection.scanFile` (ya implementado en `saveVideoToGallery` legacy).
- **Clipboard vacío al abrir**: en desktop/web `Clipboard.getData` puede lanzar; la app lo ignora por diseño.
