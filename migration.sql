-- AnimalMbs Migration: Photo URL + Storage RLS Policies
-- Run in: Supabase Dashboard > SQL Editor > New Query

-- 1. Add photo_url column to pets table
ALTER TABLE pets ADD COLUMN IF NOT EXISTS photo_url TEXT DEFAULT NULL;

-- 2. RLS Policies for pet-photos bucket
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_pet_photos_select') THEN
        CREATE POLICY "storage_pet_photos_select" ON storage.objects FOR SELECT USING (bucket_id = 'pet-photos');
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_pet_photos_insert') THEN
        CREATE POLICY "storage_pet_photos_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_pet_photos_update') THEN
        CREATE POLICY "storage_pet_photos_update" ON storage.objects FOR UPDATE USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_pet_photos_delete') THEN
        CREATE POLICY "storage_pet_photos_delete" ON storage.objects FOR DELETE USING (bucket_id = 'pet-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
    END IF;
END $$;

-- 3. RLS Policies for user-photos bucket
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_user_photos_select') THEN
        CREATE POLICY "storage_user_photos_select" ON storage.objects FOR SELECT USING (bucket_id = 'user-photos');
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_user_photos_insert') THEN
        CREATE POLICY "storage_user_photos_insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'user-photos' AND auth.uid()::text = split_part(name, '.', 1));
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_user_photos_update') THEN
        CREATE POLICY "storage_user_photos_update" ON storage.objects FOR UPDATE USING (bucket_id = 'user-photos' AND auth.uid()::text = split_part(name, '.', 1));
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'storage_user_photos_delete') THEN
        CREATE POLICY "storage_user_photos_delete" ON storage.objects FOR DELETE USING (bucket_id = 'user-photos' AND auth.uid()::text = split_part(name, '.', 1));
    END IF;
END $$;
