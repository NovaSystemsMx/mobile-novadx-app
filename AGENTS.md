# AGENTS.md — NovaDX

Instrucciones para agentes que trabajen en este repositorio. **Se respeta este
documento cada vez que se pida publicar una nueva versión.**

## Reglas generales

- **No hacer commit, push, tag ni Release sin petición explícita** (p. ej.
  «publícalo», «haz el release»). Si solo se pide un cambio de código, se deja
  en el árbol de trabajo.
- El branch por defecto del remoto es **`master`**, no `main`.
- **No eliminar ramas fusionadas** salvo que se pida explícitamente. Las ramas
  locales cuyo upstream aparece como `gone` no se tocan.
- Idioma de notas, commits y documentación: **español**. Commits en formato
  Conventional Commits con subject ≤ 50 caracteres.
- `origin` es el repo `NovaSystemsMx/mobile-novadx-app`. **No crear otro repo**
  para distribuir el APK.
- El APK **nunca se mete en el historial de Git**: `build/` está ignorado. Se
  adjunta como *asset* del Release, junto al tag y las notas. Ese es el patrón
  estándar (igual que cualquier Release de Android).

## Requisitos del entorno (por quien compile)

- Flutter/Dart y Android SDK instalados; `android/local.properties` debe
  contener `sdk.dir` correcto.
- GitHub CLI (`gh`) instalado y en PATH, con `gh auth status` mostrando una
  cuenta con permisos de push en este repo. Si no hay login, **pedir al usuario
  que corra `gh auth login`**; no relanzar el flujo de dispositivo una y otra
  vez sin coordinarlo (los códigos expiran).
- Firma de release: cada persona configura su propio `android/key.properties`
  (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) apuntando a su
  keystore local. `android/app/build.gradle.kts` ya consume esa configuración.
  Ese archivo y los keystores están ignorados por Git: **no versionar secretos
  ni rutas locales**.

## Flujo para publicar una nueva versión (checklist)

1. **Elegir versión.** Leer `pubspec.yaml`. Subir `MAJOR.MINOR.PATCH+BUILD`
   (normalmente patch + build: `0.2.4+6` → `0.2.5+7`). No reutilizar tags.
2. **Verificar el cambio.** `flutter analyze` (sin issues) y `flutter test`
   (todos los tests en verde) antes de tocar la versión.
3. **Actualizar documentación contra el código real:**
   - `pubspec.yaml` → `version: X.Y.Z+B`.
   - `README.md` → versión en *Descripción general* y cualquier texto de UI
     afectado (por ejemplo nombres de cards o botones).
   - `CHANGELOG.md` → cerrar `## Unreleased` como `## vX.Y.Z - AAAA-MM-DD`
     (formato Keep a Changelog). Si no hay `Unreleased`, crear la sección nueva
     arriba de las anteriores. **Esto va antes del tag.**
   - `AGENTS.md` → actualizar la sección *Estado de referencia* con la nueva
     versión, commit y tags publicados.
4. **Seguir la skill `ship-flow` en este orden estricto:**
   1. `branch-namer`: crear `<tipo>/<slug>` (por ejemplo
      `fix/video-card-labels`, `release/v0.2.5`) con `git switch -c`. Sin commit.
   2. `project-documentation`: auditar README/CHANGELOG contra el código y
      dejar los docs en `git add`.
   3. `commitizen-commits`: revisar el stage y hacer `git commit` con mensaje
      Conventional Commits.
5. **Compilar el APK firmado.**
   ```powershell
   flutter build apk --release
   ```
   Si hay dispositivo conectado:
   ```powershell
   adb install -r build\app\outputs\flutter-apk\app-release.apk
   ```
   Si `adb` dice `no devices/emulators found`, reportarlo y seguir: no bloquea
   la publicación.
6. **Integrar y pushear (merge fast-forward, sin commit de merge):**
   ```powershell
   git switch master
   git merge --ff-only <rama>
   git push origin master
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
   Si `--ff-only` falla, **no forzar**: reportar el conflicto y preguntar.
   No borrar la rama después; se deja como registro.
7. **Crear el Release con el APK adjunto.** Usar una carpeta temporal ignorada
   por Git (p. ej. `build/release/`) para el APK renombrado y las notas:
   ```powershell
   $apk = 'build/release/novadx-vX.Y.Z.apk'
   New-Item -ItemType Directory -Force build/release | Out-Null
   Copy-Item build\app\outputs\flutter-apk\app-release.apk $apk -Force
   gh release create vX.Y.Z $apk `
     --title "NovaDX vX.Y.Z" `
     --notes-file build/release/release-notes-vX.Y.Z.md `
     --verify-tag
   gh release view vX.Y.Z --json tagName,name,isDraft,isPrerelease,assets,url
   ```
   Las notas deben incluir: cambios de la versión, commit/tag, que el APK está
   firmado y enlace a `CHANGELOG.md` en ese tag.
8. **Reportar** al usuario: URL del Release, tag, commit, nombre/tamaño del APK
   y estado final de `git status`.

## Estado de referencia

- Última versión publicada: **v0.2.4** (`0.2.4+6`), commit `e44abaf`,
  2026-11-23. Tags publicados: `v0.2.3`, `v0.2.4`.
- `master` y los tags apuntan al mismo commit; árbol limpio tras la publicación.
- El 2026-11-23 se eliminaron localmente, a petición del usuario, todas las
  ramas ya fusionadas (`feature/multiple-videos-per-post`,
  `fix/video-card-labels`, `hotfix/twimg-tag-403-download` y `main`). Solo
  existe la rama local `master`.
