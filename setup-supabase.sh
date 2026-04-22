#!/bin/bash
# ============================================================
# AnimalMbs — Supabase Setup Script
# ============================================================
# Uso:
#   chmod +x setup-supabase.sh
#   ./setup-supabase.sh <SERVICE_ROLE_KEY>
#
# Obtén el SERVICE_ROLE_KEY en:
#   Supabase Dashboard > Settings > API > service_role (secret)
# ============================================================

set -e

SUPABASE_URL="https://ohhhwbjxciovjvvcsleu.supabase.co"
PROJECT_REF="ohhhwbjxciovjvvcsleu"
SERVICE_KEY="${1:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$SERVICE_KEY" ]; then
    echo -e "${RED}❌  Falta el SERVICE_ROLE_KEY.${NC}"
    echo ""
    echo "   Uso: ./setup-supabase.sh <SERVICE_ROLE_KEY>"
    echo ""
    echo "   Encuéntralo en:"
    echo "   Supabase Dashboard > Settings > API > service_role (secret)"
    echo ""
    exit 1
fi

echo ""
echo -e "${BLUE}🐾  AnimalMbs — Supabase Setup${NC}"
echo "================================"
echo "   URL: $SUPABASE_URL"
echo "   Proyecto: $PROJECT_REF"
echo ""

# ---- PASO 1: Probar conexión ----
echo -e "${BLUE}🔌  Probando conexión...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    "$SUPABASE_URL/rest/v1/pets?limit=1&select=id")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "206" ]; then
    echo -e "   ${GREEN}✅  Conectado${NC}"
else
    echo -e "   ${YELLOW}⚠️  Respuesta HTTP: $HTTP_CODE (puede ser normal si la tabla está vacía)${NC}"
fi

# ---- PASO 2: Crear bucket pet-photos ----
echo ""
echo -e "${BLUE}🪣  Creando bucket: pet-photos...${NC}"
BUCKET_RES=$(curl -s -w "\n%{http_code}" -X POST \
    "$SUPABASE_URL/storage/v1/bucket" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "id": "pet-photos",
        "name": "pet-photos",
        "public": true,
        "file_size_limit": 5242880,
        "allowed_mime_types": ["image/jpeg", "image/png", "image/webp"]
    }')

BUCKET_STATUS=$(echo "$BUCKET_RES" | tail -n1)
BUCKET_BODY=$(echo "$BUCKET_RES" | head -n-1)

if [ "$BUCKET_STATUS" = "200" ] || [ "$BUCKET_STATUS" = "201" ]; then
    echo -e "   ${GREEN}✅  Bucket pet-photos creado${NC}"
elif echo "$BUCKET_BODY" | grep -q "already exists"; then
    echo -e "   ${YELLOW}ℹ️  Bucket pet-photos ya existe (OK)${NC}"
else
    echo -e "   ${RED}❌  Error ($BUCKET_STATUS): $BUCKET_BODY${NC}"
fi

# ---- PASO 3: Crear bucket user-photos ----
echo ""
echo -e "${BLUE}🪣  Creando bucket: user-photos...${NC}"
BUCKET_RES2=$(curl -s -w "\n%{http_code}" -X POST \
    "$SUPABASE_URL/storage/v1/bucket" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "id": "user-photos",
        "name": "user-photos",
        "public": true,
        "file_size_limit": 5242880,
        "allowed_mime_types": ["image/jpeg", "image/png", "image/webp"]
    }')

BUCKET_STATUS2=$(echo "$BUCKET_RES2" | tail -n1)
BUCKET_BODY2=$(echo "$BUCKET_RES2" | head -n-1)

if [ "$BUCKET_STATUS2" = "200" ] || [ "$BUCKET_STATUS2" = "201" ]; then
    echo -e "   ${GREEN}✅  Bucket user-photos creado${NC}"
elif echo "$BUCKET_BODY2" | grep -q "already exists"; then
    echo -e "   ${YELLOW}ℹ️  Bucket user-photos ya existe (OK)${NC}"
else
    echo -e "   ${RED}❌  Error ($BUCKET_STATUS2): $BUCKET_BODY2${NC}"
fi

# ---- PASO 4: Migración SQL via pg-meta ----
echo ""
echo -e "${BLUE}📦  Ejecutando migración SQL (ALTER TABLE pets ADD COLUMN photo_url)...${NC}"

SQL_ALTER="ALTER TABLE pets ADD COLUMN IF NOT EXISTS photo_url TEXT DEFAULT NULL;"

SQL_RES=$(curl -s -w "\n%{http_code}" -X POST \
    "$SUPABASE_URL/pg/query" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$SQL_ALTER\"}" 2>/dev/null)

SQL_STATUS=$(echo "$SQL_RES" | tail -n1)

if [ "$SQL_STATUS" = "200" ]; then
    echo -e "   ${GREEN}✅  Columna photo_url agregada${NC}"
else
    # Fallback: try via supabase REST RPC
    SQL_RES2=$(curl -s -w "\n%{http_code}" -X POST \
        "$SUPABASE_URL/rest/v1/rpc/exec" \
        -H "apikey: $SERVICE_KEY" \
        -H "Authorization: Bearer $SERVICE_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"sql\": \"$SQL_ALTER\"}" 2>/dev/null)

    SQL_STATUS2=$(echo "$SQL_RES2" | tail -n1)

    if [ "$SQL_STATUS2" = "200" ]; then
        echo -e "   ${GREEN}✅  Columna photo_url agregada (vía RPC)${NC}"
    else
        echo -e "   ${YELLOW}⚠️  No se pudo ejecutar automáticamente.${NC}"
        echo ""
        echo "   Ejecuta este SQL manualmente en Supabase Dashboard > SQL Editor:"
        echo ""
        echo -e "   ${BLUE}ALTER TABLE pets ADD COLUMN IF NOT EXISTS photo_url TEXT DEFAULT NULL;${NC}"
        echo ""
    fi
fi

# ---- PASO 5: Storage RLS Policies ----
echo ""
echo -e "${BLUE}🔐  Configurando políticas RLS para Storage...${NC}"

POLICIES_SQL="
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_pet_photos_select') THEN
        CREATE POLICY \"storage_pet_photos_select\" ON storage.objects FOR SELECT USING (bucket_id = 'pet-photos');
    END IF;
END \$\$;
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_pet_photos_insert') THEN
        CREATE POLICY \"storage_pet_photos_insert\" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
    END IF;
END \$\$;
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_pet_photos_update') THEN
        CREATE POLICY \"storage_pet_photos_update\" ON storage.objects FOR UPDATE USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
    END IF;
END \$\$;
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_pet_photos_delete') THEN
        CREATE POLICY \"storage_pet_photos_delete\" ON storage.objects FOR DELETE USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
    END IF;
END \$\$;
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_user_photos_select') THEN
        CREATE POLICY \"storage_user_photos_select\" ON storage.objects FOR SELECT USING (bucket_id = 'user-photos');
    END IF;
END \$\$;
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_user_photos_insert') THEN
        CREATE POLICY \"storage_user_photos_insert\" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'user-photos' AND auth.uid()::text = split_part(name, '.', 1));
    END IF;
END \$\$;
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_user_photos_update') THEN
        CREATE POLICY \"storage_user_photos_update\" ON storage.objects FOR UPDATE USING (bucket_id = 'user-photos' AND auth.uid()::text = split_part(name, '.', 1));
    END IF;
END \$\$;
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_user_photos_delete') THEN
        CREATE POLICY \"storage_user_photos_delete\" ON storage.objects FOR DELETE USING (bucket_id = 'user-photos' AND auth.uid()::text = split_part(name, '.', 1));
    END IF;
END \$\$;
"

POLICY_RES=$(curl -s -w "\n%{http_code}" -X POST \
    "$SUPABASE_URL/pg/query" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$POLICIES_SQL\"}" 2>/dev/null)

POLICY_STATUS=$(echo "$POLICY_RES" | tail -n1)

if [ "$POLICY_STATUS" = "200" ]; then
    echo -e "   ${GREEN}✅  Políticas RLS configuradas${NC}"
else
    echo -e "   ${YELLOW}⚠️  Ejecuta el SQL de storage policies del supabase-schema.sql manualmente${NC}"
fi

# ---- RESUMEN ----
echo ""
echo "================================"
echo -e "${GREEN}✅  Setup completado!${NC}"
echo ""
echo "📋  Resumen:"
echo "   • Bucket pet-photos  → Public, 5MB, JPEG/PNG/WebP"
echo "   • Bucket user-photos → Public, 5MB, JPEG/PNG/WebP"
echo "   • Columna photo_url  → pets table"
echo "   • Políticas RLS      → Storage"
echo ""
echo "🚀  Próximos pasos:"
echo "   1. Compilar la app iOS en Xcode"
echo "   2. Abrir la web en el navegador"
echo "   3. Subir una foto a una mascota para probar"
echo ""
