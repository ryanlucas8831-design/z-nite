#!/usr/bin/env bash
# Monta a casca Android do Zenit a partir dos arquivos da raiz e gera o APK.
set -euo pipefail
OWNER="${GITHUB_REPOSITORY_OWNER,,}"
NAME="${GITHUB_REPOSITORY#*/}"
if [ "${NAME,,}" = "${OWNER}.github.io" ]; then URL="https://${OWNER}.github.io/"; else URL="https://${OWNER}.github.io/${NAME}/"; fi
echo "Endereço do Zenit: $URL"
rm -rf apk && mkdir -p apk/www
cp apk-package.json apk/package.json
cp apk-capacitor.json apk/capacitor.config.json
cp apk-index.html apk/www/index.html
cp apk-offline.html apk/www/offline.html
cp icon-512.png apk/icon-512.png
sed -i "s#__URL_DO_SITE__#${URL}#g" apk/capacitor.config.json apk/www/index.html apk/www/offline.html
cd apk
npm install
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
# Ícone das notificações (estrela branca) e permissões de lembrete exato
mkdir -p "$RES/drawable"
convert -size 96x96 xc:none -fill white -draw "polygon 48,6 59,36 92,37 66,57 75,89 48,70 21,89 30,57 4,37 37,36" "$RES/drawable/ic_stat_zenit.png"
MAN=android/app/src/main/AndroidManifest.xml
for perm in POST_NOTIFICATIONS USE_EXACT_ALARM RECEIVE_BOOT_COMPLETED WAKE_LOCK; do
  grep -q "android.permission.$perm" "$MAN" || sed -i "s#<application#<uses-permission android:name=\"android.permission.$perm\" />\n    <application#" "$MAN"
done
mkdir -p ~/.android
cp ../zenit-assinatura.keystore ~/.android/debug.keystore
npx cap sync android
cd android
chmod +x gradlew
./gradlew assembleDebug --no-daemon
cp app/build/outputs/apk/debug/app-debug.apk ../../Zenit.apk
echo "Pronto: Zenit.apk"
