#!/usr/bin/env bash
# ==============================================================================
# Myspoti-SakuKelly — Suite de Verificación Determinista e Integridad Técnica
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
APK_FILE="$REPO_DIR/release/Myspoti-SakuKelly-release.apk"
EXPECTED_SHA256="74456ea9e457f51d7e6cf1929c36de211873d21f6adb9911f0701a7bde03ecee"

echo "🧪 [1/4] Verificando existencia de Myspoti-SakuKelly-release.apk..."
if [ -f "$APK_FILE" ]; then
  FILE_SIZE=$(ls -lh "$APK_FILE" | awk '{print $5}')
  echo "  ✔ [PASS] APK presente en release/ (Tamaño: $FILE_SIZE)."
else
  echo "  ❌ [FAIL] No se encontró el APK en release/."
  exit 1
fi

echo "🧪 [2/4] Verificando suma de verificación criptográfica (SHA-256)..."
ACTUAL_SHA256=$(sha256sum "$APK_FILE" | awk '{print $1}')
if [ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ]; then
  echo "  ✔ [PASS] Checksum SHA-256 inmutable verificado: $ACTUAL_SHA256"
else
  echo "  ❌ [FAIL] Discrepancia en checksum SHA-256."
  echo "     Esperado: $EXPECTED_SHA256"
  echo "     Obtenido: $ACTUAL_SHA256"
  exit 1
fi

echo "🧪 [3/4] Verificando integridad del contenedor ZIP y assets originales..."
python3 - << 'PY_EOF'
import zipfile, os, sys
apk = os.path.join(os.environ.get("REPO_DIR", "."), "release/Myspoti-SakuKelly-release.apk")
with zipfile.ZipFile(apk, 'r') as z:
    names = z.namelist()
    assert "AndroidManifest.xml" in names, "Falta AndroidManifest.xml"
    assert any(n.startswith("classes") and n.endswith(".dex") for n in names), "Falta DEX"
    assert "resources.arsc" in names, "Falta resources.arsc"
print("  ✔ [PASS] Estructura interna de APK Android (DEX, Manifiesto, ARSC) válida.")

# Verificar imágenes originales
brand_files = ["myspoti-logo-1024.png", "myspoti-logo-512.png", "myspoti-logo.svg"]
screenshot_files = ["banner.jpg", "home.jpg", "player.jpg", "album.jpg", "artist.jpg"]
repo = os.environ.get("REPO_DIR", ".")
for b in brand_files:
    assert os.path.exists(os.path.join(repo, "docs/brand", b)), f"Falta {b}"
for s in screenshot_files:
    assert os.path.exists(os.path.join(repo, "docs/screenshots", s)), f"Falta {s}"
print("  ✔ [PASS] Todas las imágenes y capturas originales del proyecto están presentes.")
PY_EOF

echo "🧪 [4/4] Verificando ausencia total de rutas privadas absolutas..."
if git -C "$REPO_DIR" grep -I -i "/home/darwinsin" ":(exclude).git" ":(exclude)scripts/ci.sh" 2>/dev/null; then
  echo "  ❌ [FAIL] Se detectaron rutas privadas absolutas."
  exit 1
else
  echo "  ✔ [PASS] 0 rutas privadas absolutas detectadas."
fi

echo ""
echo "✅ Todas las pruebas de integridad de Myspoti-SakuKelly pasaron al 100% (Código de salida 0)."
