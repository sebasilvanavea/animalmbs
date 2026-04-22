#!/bin/bash
# ============================================================
# AnimalMbs Web — Setup Script
# ============================================================
# Este script configura Supabase y despliega a Netlify.
#
# Antes de ejecutar:
# 1. Crea un proyecto en https://supabase.com/dashboard/projects
#    - Nombre: AnimalMbs
#    - Región: South America (São Paulo)
# 2. Ve a Settings > API y copia el Project URL y anon public key
# 3. Ve a SQL Editor > New Query, pega el contenido de supabase-schema.sql y ejecuta
# ============================================================

set -e

echo ""
echo "🐾 AnimalMbs Web — Configuración"
echo "================================="
echo ""

# Ask for Supabase credentials
read -p "📋 Pega tu Supabase Project URL: " SUPABASE_URL
read -p "🔑 Pega tu Supabase Anon Key: " SUPABASE_KEY

# Validate inputs
if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_KEY" ]]; then
    echo "❌ Error: Debes proporcionar ambos valores."
    exit 1
fi

if [[ ! "$SUPABASE_URL" =~ ^https://.*\.supabase\.co$ ]]; then
    echo "⚠️  Advertencia: La URL no parece ser una URL de Supabase válida."
    read -p "¿Continuar de todos modos? (s/n): " CONTINUE
    if [[ "$CONTINUE" != "s" ]]; then exit 1; fi
fi

# Update config.js
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/js/config.js"

cat > "$CONFIG_FILE" << EOF
// AnimalMbs — Supabase Configuration
// Configurado automáticamente por setup.sh

export const SUPABASE_URL = '${SUPABASE_URL}';
export const SUPABASE_ANON_KEY = '${SUPABASE_KEY}';
EOF

echo ""
echo "✅ config.js actualizado"
echo ""

# Deploy
read -p "¿Desplegar a Netlify ahora? (s/n): " DEPLOY
if [[ "$DEPLOY" == "s" ]]; then
    cd "$SCRIPT_DIR"
    netlify deploy --prod --dir=.
    echo ""
    echo "🚀 ¡Desplegado! Tu app está en https://animalm.netlify.app"
fi

echo ""
echo "✅ ¡Configuración completada!"
echo ""
echo "📝 Recuerda ejecutar el SQL en Supabase:"
echo "   1. Ve a SQL Editor en tu dashboard de Supabase"
echo "   2. Crea un New Query"
echo "   3. Copia y pega el contenido de: supabase-schema.sql"
echo "   4. Click en Run"
echo ""
