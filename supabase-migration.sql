-- ============================================================
-- AnimalMbs — Supabase Schema Migration
-- Run this in: Supabase Dashboard > SQL Editor > New Query
-- ============================================================
-- Adds missing columns needed by the iOS app

-- 1. Add clinic_name to vaccines
ALTER TABLE vaccines ADD COLUMN IF NOT EXISTS clinic_name TEXT DEFAULT '';

-- 2. Add veterinarian to antiparasitics
ALTER TABLE antiparasitics ADD COLUMN IF NOT EXISTS veterinarian TEXT DEFAULT '';

-- 3. Add clinic_name to medical_records
ALTER TABLE medical_records ADD COLUMN IF NOT EXISTS clinic_name TEXT DEFAULT '';

-- 4. Update default sex value to match iOS app
ALTER TABLE pets ALTER COLUMN sex SET DEFAULT 'Desconocido';

-- Done! The iOS and web apps now share the same database schema.
