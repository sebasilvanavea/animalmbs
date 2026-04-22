// ============================================================
// AnimalMbs Web — API Layer (Supabase)
// ============================================================

import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

export const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

function withCacheBust(url) {
    const separator = url.includes('?') ? '&' : '?';
    return `${url}${separator}v=${Date.now()}`;
}

// ---- Auth ----

export const auth = {
    signUp: (email, password) => sb.auth.signUp({ email, password }),
    signIn: (email, password) => sb.auth.signInWithPassword({ email, password }),
    signOut: () => sb.auth.signOut(),
    getSession: () => sb.auth.getSession(),
    getUser: () => sb.auth.getUser(),
    onAuthChange: (cb) => sb.auth.onAuthStateChange(cb),
};

// ---- Generic CRUD helpers ----

async function query(table, petId = null, orderCol = 'date') {
    let q = sb.from(table).select('*');
    if (petId) q = q.eq('pet_id', petId);
    q = q.order(orderCol, { ascending: false });
    const { data, error } = await q;
    if (error) throw error;
    return data;
}

async function getOne(table, id) {
    const { data, error } = await sb.from(table).select('*').eq('id', id).single();
    if (error) throw error;
    return data;
}

async function insert(table, row) {
    const { data, error } = await sb.from(table).insert(row).select().single();
    if (error) throw error;
    return data;
}

async function update(table, id, updates) {
    const { data, error } = await sb.from(table).update(updates).eq('id', id).select().single();
    if (error) throw error;
    return data;
}

async function remove(table, id) {
    const { error } = await sb.from(table).delete().eq('id', id);
    if (error) throw error;
}

// ---- Pets ----

export const pets = {
    list: () => query('pets', null, 'created_at'),
    get: (id) => getOne('pets', id),
    create: async (pet) => {
        const { data: { user } } = await sb.auth.getUser();
        return insert('pets', { ...pet, user_id: user.id });
    },
    update: (id, data) => update('pets', id, data),
    delete: (id) => remove('pets', id),
};

// ---- Vaccines ----

export const vaccines = {
    list: (petId) => query('vaccines', petId),
    get: (id) => getOne('vaccines', id),
    create: (v) => insert('vaccines', v),
    update: (id, data) => update('vaccines', id, data),
    delete: (id) => remove('vaccines', id),
};

// ---- Antiparasitics ----

export const antiparasitics = {
    list: (petId) => query('antiparasitics', petId),
    get: (id) => getOne('antiparasitics', id),
    create: (a) => insert('antiparasitics', a),
    update: (id, data) => update('antiparasitics', id, data),
    delete: (id) => remove('antiparasitics', id),
};

// ---- Medical Records ----

export const medicalRecords = {
    list: (petId) => query('medical_records', petId),
    get: (id) => getOne('medical_records', id),
    create: (r) => insert('medical_records', r),
    update: (id, data) => update('medical_records', id, data),
    delete: (id) => remove('medical_records', id),
};

// ---- Weight Entries ----

export const weightEntries = {
    list: (petId) => query('weight_entries', petId),
    create: (w) => insert('weight_entries', w),
    delete: (id) => remove('weight_entries', id),
};

// ---- Pet Photos (Supabase Storage) ----

export const petPhotos = {
    upload: async (userId, petId, file) => {
        const path = `${userId}/${petId}.jpg`;
        const { error } = await sb.storage
            .from('pet-photos')
            .upload(path, file, { upsert: true, contentType: file.type });
        if (error) throw error;
        const { data: { publicUrl } } = sb.storage.from('pet-photos').getPublicUrl(path);
        return withCacheBust(publicUrl);
    },
    delete: async (userId, petId) => {
        const path = `${userId}/${petId}.jpg`;
        await sb.storage.from('pet-photos').remove([path]);
    }
};

// ---- User Photos (Supabase Storage) ----

export const userPhotos = {
    upload: async (userId, file) => {
        const path = `${userId}.jpg`;
        const { error } = await sb.storage
            .from('user-photos')
            .upload(path, file, { upsert: true, contentType: file.type });
        if (error) throw error;
        const { data: { publicUrl } } = sb.storage.from('user-photos').getPublicUrl(path);
        return withCacheBust(publicUrl);
    }
};

// ---- Full pet data (for QR/PDF) ----

export async function getFullPetData(petId) {
    const [pet, vacs, aps, records, weights] = await Promise.all([
        pets.get(petId),
        vaccines.list(petId),
        antiparasitics.list(petId),
        medicalRecords.list(petId),
        weightEntries.list(petId),
    ]);
    return { pet, vaccines: vacs, antiparasitics: aps, medicalRecords: records, weights };
}
