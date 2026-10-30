#!/usr/bin/env bash
# Monta a casca Android do Zenit (Capacitor 8, Android 16 / API 36) e gera:
#   Zenit.apk  -> para instalar direto no celular
#   Zenit.aab  -> para enviar à Play Store
# Os dois saem assinados com a chave guardada nos Secrets do GitHub
# (ZENIT_KEYSTORE_B64 e ZENIT_KEY_PASSWORD). A chave nunca fica no repositório.
set -euo pipefail
if [ -z "${ZENIT_KEYSTORE_B64:-}" ] || [ -z "${ZENIT_KEY_PASSWORD:-}" ]; then
  echo "::error::Faltam os Secrets ZENIT_KEYSTORE_B64 e ZENIT_KEY_PASSWORD (Settings > Secrets and variables > Actions)."; exit 1
fi
OWNER="${GITHUB_REPOSITORY_OWNER,,}"
NAME="${GITHUB_REPOSITORY#*/}"
if [ "${NAME,,}" = "${OWNER}.github.io" ]; then URL="https://${OWNER}.github.io/"; else URL="https://${OWNER}.github.io/${NAME}/"; fi
VER=$(grep -o "const ZV = '[0-9.]*'" index.html | head -1 | grep -o "[0-9.]*" || echo "1.0")
CODE=$(( ${GITHUB_RUN_NUMBER:-1} + 100 ))
echo "Endereço do Zenit: $URL · versão $VER ($CODE)"
rm -rf apk && mkdir -p apk/www
cp apk-package.json apk/package.json
cp apk-capacitor.json apk/capacitor.config.json
cp apk-index.html apk/www/index.html
cp apk-offline.html apk/www/offline.html
cp icon-512.png apk/icon-512.png
sed -i "s#__URL_DO_SITE__#${URL}#g" apk/capacitor.config.json apk/www/index.html apk/www/offline.html
cd apk
npm install --no-audit --no-fund
npx cap add android
sudo apt-get install -y -qq imagemagick > /dev/null
RES=android/app/src/main/res
rm -rf "$RES/mipmap-anydpi-v26"
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  n="${d%%:*}"; s="${d##*:}"
  convert icon-512.png -resize "${s}x${s}" "$RES/mipmap-$n/ic_launcher.png"
  cp "$RES/mipmap-$n/ic_launcher.png" "$RES/mipmap-$n/ic_launcher_round.png"
  rm -f "$RES/mipmap-$n/ic_launcher_foreground.png"
done
# Ícone das notificações (estrela branca), lembretes e microfone (assistente por voz)
mkdir -p "$RES/drawable"
convert -size 96x96 xc:none -fill white -draw "polygon 48,6 59,36 92,37 66,57 75,89 48,70 21,89 30,57 4,37 37,36" "$RES/drawable/ic_stat_zenit.png"
MAN=android/app/src/main/AndroidManifest.xml
for perm in POST_NOTIFICATIONS SCHEDULE_EXACT_ALARM RECEIVE_BOOT_COMPLETED WAKE_LOCK RECORD_AUDIO MODIFY_AUDIO_SETTINGS; do
  grep -q "android.permission.$perm\"" "$MAN" || sed -i "s#<application#<uses-permission android:name=\"android.permission.$perm\" />\n    <application#" "$MAN"
done
# Versão e assinatura
GR=android/app/build.gradle
sed -i "s/versionCode 1$/versionCode ${CODE}/; s/versionName \"1.0\"/versionName \"${VER}\"/" "$GR"
echo "$ZENIT_KEYSTORE_B64" | base64 -d > "$RUNNER_TEMP/zenit-upload.p12"
export ZK_FILE="$RUNNER_TEMP/zenit-upload.p12" ZK_PASS="$ZENIT_KEY_PASSWORD"
cat >> "$GR" <<'GRADLE'

android {
    signingConfigs {
        zenit {
            storeFile file(System.getenv("ZK_FILE"))
            storePassword System.getenv("ZK_PASS")
            keyAlias "zenit"
            keyPassword System.getenv("ZK_PASS")
            storeType "pkcs12"
        }
    }
    buildTypes {
        release { signingConfig signingConfigs.zenit }
    }
}
GRADLE
npx cap sync android
cd android
chmod +x gradlew
./gradlew assembleRelease bundleRelease --no-daemon
cp app/build/outputs/apk/release/app-release.apk ../../Zenit.apk
cp app/build/outputs/bundle/release/app-release.aab ../../Zenit.aab
rm -f "$RUNNER_TEMP/zenit-upload.p12"
echo "Pronto: Zenit.apk e Zenit.aab (versão $VER, código $CODE)"
