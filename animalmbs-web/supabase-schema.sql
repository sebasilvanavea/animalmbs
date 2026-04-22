-- ============================================================
-- AnimalMbs Web — Supabase Database Schema
-- ============================================================
-- Ejecuta este SQL en: Supabase Dashboard > SQL Editor > New Query
-- ============================================================

-- 1. TABLAS

CREATE TABLE IF NOT EXISTS pets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  species TEXT NOT NULL DEFAULT 'Perro',
  breed TEXT DEFAULT '',
  birth_date DATE,
  sex TEXT NOT NULL DEFAULT 'Desconocido',
  color TEXT DEFAULT '',
  weight DOUBLE PRECISION DEFAULT 0,
  microchip_number TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  photo_url TEXT DEFAULT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vaccines (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pet_id UUID REFERENCES pets(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  next_dose_date DATE,
  lot_number TEXT DEFAULT '',
  veterinarian TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS antiparasitics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pet_id UUID REFERENCES pets(id) ON DELETE CASCADE NOT NULL,
  product_name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'Interno',
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  next_application_date DATE,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS medical_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pet_id UUID REFERENCES pets(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  reason TEXT NOT NULL,
  diagnosis TEXT DEFAULT '',
  treatment TEXT DEFAULT '',
  veterinarian TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS weight_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  pet_id UUID REFERENCES pets(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  weight DOUBLE PRECISION NOT NULL,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. ROW LEVEL SECURITY

ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
ALTER TABLE vaccines ENABLE ROW LEVEL SECURITY;
ALTER TABLE antiparasitics ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE weight_entries ENABLE ROW LEVEL SECURITY;

-- 3. POLÍTICAS (cada usuario solo ve sus datos)

CREATE POLICY "pets_all" ON pets
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "vaccines_all" ON vaccines
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid()))
  WITH CHECK (pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid()));

CREATE POLICY "antiparasitics_all" ON antiparasitics
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid()))
  WITH CHECK (pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid()));

CREATE POLICY "medical_records_all" ON medical_records
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid()))
  WITH CHECK (pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid()));

CREATE POLICY "weight_entries_all" ON weight_entries
  FOR ALL USING (pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid()))
  WITH CHECK (pet_id IN (SELECT id FROM pets WHERE user_id = auth.uid()));

-- 5. STORAGE — bucket "pet-photos" y "user-photos"
-- Crear manualmente en Supabase Dashboard > Storage > New Bucket:
--   Nombre: pet-photos  | Public: YES | Limit: 5MB | MIME: image/jpeg, image/png, image/webp
--   Nombre: user-photos | Public: YES | Limit: 5MB | MIME: image/jpeg, image/png, image/webp
--
-- Migración (ejecutar si la tabla ya existe):
--   ALTER TABLE pets ADD COLUMN IF NOT EXISTS photo_url TEXT DEFAULT NULL;
--
-- Políticas RLS para storage (ruta: {user_id}/{pet_id}.jpg)
CREATE POLICY "storage_pet_photos_select"
ON storage.objects FOR SELECT USING (bucket_id = 'pet-photos');

CREATE POLICY "storage_pet_photos_insert"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'pet-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "storage_pet_photos_update"
ON storage.objects FOR UPDATE
USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "storage_pet_photos_delete"
ON storage.objects FOR DELETE
USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Políticas RLS para user-photos (ruta: {user_id}.jpg)
CREATE POLICY "storage_user_photos_select"
ON storage.objects FOR SELECT USING (bucket_id = 'user-photos');

CREATE POLICY "storage_user_photos_insert"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'user-photos'
    AND auth.uid()::text = split_part(name, '.', 1)
);

CREATE POLICY "storage_user_photos_update"
ON storage.objects FOR UPDATE
USING (bucket_id = 'user-photos' AND auth.uid()::text = split_part(name, '.', 1));

CREATE POLICY "storage_user_photos_delete"
ON storage.objects FOR DELETE
USING (bucket_id = 'user-photos' AND auth.uid()::text = split_part(name, '.', 1));

-- 4. ÍNDICES

CREATE INDEX IF NOT EXISTS idx_pets_user ON pets(user_id);
CREATE INDEX IF NOT EXISTS idx_vaccines_pet ON vaccines(pet_id);
CREATE INDEX IF NOT EXISTS idx_antiparasitics_pet ON antiparasitics(pet_id);
CREATE INDEX IF NOT EXISTS idx_medical_records_pet ON medical_records(pet_id);
CREATE INDEX IF NOT EXISTS idx_weight_entries_pet ON weight_entries(pet_id);
