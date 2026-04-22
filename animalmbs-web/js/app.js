// ============================================================
// AnimalMbs Web — App v2.0
// Full-featured SPA matching iOS app
// ============================================================

import { auth, pets, vaccines, antiparasitics, medicalRecords, weightEntries, getFullPetData, petPhotos, userPhotos } from './api.js';

// ---- State ----
let state = {
    user: null,
    pets: [],
    currentPet: null,
    petDetails: {},   // { petId: { vaccines, antiparasitics, medicalRecords, weights } }
    loading: false,
    search: '',
    tab: 'pets',      // 'pets' | 'alerts' | 'map' | 'settings'
    vetResults: null,
    vetUserCoords: null,
};

// ---- Router ----
function getRoute() {
    const hash = location.hash.slice(1) || '/';
    return hash;
}

function navigate(path) {
    location.hash = path;
}

// ---- Helpers ----
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => el.querySelectorAll(s);

function speciesEmoji(species) {
    const map = { 'Perro': '🐕', 'Gato': '🐱', 'Ave': '🐦', 'Conejo': '🐰', 'Hámster': '🐹', 'Reptil': '🦎' };
    return map[species] || '🐾';
}

function speciesColor(species) {
    const map = { 'Perro': 'primary', 'Gato': 'tertiary', 'Ave': 'yellow', 'Conejo': 'pink', 'Hámster': 'secondary', 'Reptil': 'blue' };
    return map[species] || 'primary';
}

function fmtDate(d) {
    if (!d) return '—';
    return new Date(d).toLocaleDateString('es-CL', { day: '2-digit', month: 'short', year: 'numeric' });
}

function fmtDateShort(d) {
    if (!d) return '—';
    return new Date(d).toLocaleDateString('es-CL', { day: '2-digit', month: 'short' });
}

function daysUntil(d) {
    if (!d) return null;
    const now = new Date(); now.setHours(0,0,0,0);
    const target = new Date(d); target.setHours(0,0,0,0);
    return Math.ceil((target - now) / 86400000);
}

function daysLabel(days) {
    if (days === null) return '';
    if (days < 0) return `Vencido hace ${Math.abs(days)} día${Math.abs(days) !== 1 ? 's' : ''}`;
    if (days === 0) return 'Hoy';
    if (days === 1) return 'Mañana';
    return `En ${days} día${days !== 1 ? 's' : ''}`;
}

function urgency(days) {
    if (days === null) return 'ok';
    if (days < 0) return 'overdue';
    if (days <= 30) return 'soon';
    return 'ok';
}

function petAge(birthDate) {
    if (!birthDate) return '—';
    const birth = new Date(birthDate);
    const now = new Date();
    let years = now.getFullYear() - birth.getFullYear();
    let months = now.getMonth() - birth.getMonth();
    if (months < 0) { years--; months += 12; }
    if (years > 0) return `${years} año${years !== 1 ? 's' : ''}${months > 0 ? ` ${months} mes${months !== 1 ? 'es' : ''}` : ''}`;
    if (months > 0) return `${months} mes${months !== 1 ? 'es' : ''}`;
    return 'Recién nacido';
}

function sanitize(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function petFallbackMarkup(pet, size = 'default') {
    if (size === 'hero') {
        return `<div class="pet-avatar lg" style="background:rgba(var(--${speciesColor(pet.species)}-rgb,0),0.12);margin:0 auto">${speciesEmoji(pet.species)}</div>`;
    }
    return `<div class="pet-avatar" style="background:var(--${speciesColor(pet.species)});opacity:0.12;position:relative"><span style="position:absolute;opacity:1">${speciesEmoji(pet.species)}</span></div>`;
}

function renderPetImage({ src, alt, imgClass }) {
    return `<img class="${imgClass}" src="${sanitize(src)}" alt="${sanitize(alt)}" loading="lazy">`;
}

function renderRemoteImage({ src, alt, imgClass, wrapperClass = 'remote-image-shell', fallbackMarkup = '' }) {
    return `
        <div class="${wrapperClass} is-loading">
            ${fallbackMarkup ? `<div class="remote-image-fallback">${fallbackMarkup}</div>` : ''}
            <div class="remote-image-spinner"><div class="paw-loader compact"><span>🐾</span><span>🐾</span><span>🐾</span></div></div>
            <img class="${imgClass}" src="${sanitize(src)}" alt="${sanitize(alt)}" loading="lazy" onload="app.imageLoaded(this)" onerror="app.imageErrored(this)">
        </div>
    `;
}

// ---- Toast ----
function toast(message, type = 'success') {
    const container = document.getElementById('toast-container');
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.textContent = message;
    container.appendChild(el);
    setTimeout(() => { el.classList.add('fade-out'); setTimeout(() => el.remove(), 300); }, 2500);
}

// ---- Confirm Dialog ----
function confirm(title, text, onConfirm, icon = '⚠️') {
    const overlay = document.getElementById('modal-overlay');
    overlay.innerHTML = `
        <div class="modal-box">
            <div class="modal-icon">${icon}</div>
            <div class="modal-title">${sanitize(title)}</div>
            <div class="modal-text">${sanitize(text)}</div>
            <div class="modal-actions">
                <button class="btn btn-outline" id="modal-cancel">Cancelar</button>
                <button class="btn btn-danger" id="modal-confirm">Eliminar</button>
            </div>
        </div>`;
    overlay.classList.remove('hidden');
    $('#modal-cancel').onclick = () => overlay.classList.add('hidden');
    $('#modal-confirm').onclick = () => { overlay.classList.add('hidden'); onConfirm(); };
    overlay.onclick = (e) => { if (e.target === overlay) overlay.classList.add('hidden'); };
}

// ---- Loading ----
function loader(text = 'Cargando...') {
    return `<div class="loader fade-in">
        <div class="paw-loader"><span>🐾</span><span>🐾</span><span>🐾</span><span>🐾</span></div>
        <div class="loader-text">${sanitize(text)}</div>
    </div>`;
}

// ---- Empty State ----
function emptyState(icon, title, subtitle, actionLabel, actionFn) {
    const id = 'empty-action-' + Date.now();
    setTimeout(() => {
        const btn = document.getElementById(id);
        if (btn && actionFn) btn.onclick = actionFn;
    }, 0);
    return `<div class="empty-state fade-in">
        <div class="empty-icon">${icon}</div>
        <div class="empty-title">${sanitize(title)}</div>
        <div class="empty-sub">${sanitize(subtitle)}</div>
        ${actionLabel ? `<button class="btn btn-primary mt-16" id="${id}">${sanitize(actionLabel)}</button>` : ''}
    </div>`;
}

// ---- Paw Watermark ----
function pawWatermark() {
    const paws = [];
    for (let i = 0; i < 10; i++) {
        const x = Math.random() * 100;
        const y = Math.random() * 100;
        const size = 16 + Math.random() * 20;
        const rot = -45 + Math.random() * 90;
        paws.push(`<span style="left:${x}%;top:${y}%;--paw-size:${size}px;--paw-rot:${rot}deg">🐾</span>`);
    }
    return `<div class="paw-watermark">${paws.join('')}</div>`;
}

// ---- Render App Shell ----
function renderShell(content) {
    const alertCount = getAlertCount();
    return `
        ${pawWatermark()}
        <nav class="navbar">
            <div class="navbar-brand"><span>🐾</span> AnimalMbs</div>
            <div class="navbar-actions">
                ${state.user ? `<button class="btn-icon btn-ghost" onclick="app.handleLogout()" title="Cerrar sesión">🚪</button>` : ''}
            </div>
        </nav>
        <main class="main-content fade-in" id="main">${content}</main>
        ${state.user ? `
        <div class="tab-bar">
            <div class="tab-bar-inner">
                <button class="tab-item ${state.tab === 'pets' ? 'active' : ''}" onclick="app.switchTab('pets')">
                    <span class="tab-icon">🐾</span>Mascotas
                </button>
                <button class="tab-item ${state.tab === 'alerts' ? 'active' : ''}" onclick="app.switchTab('alerts')">
                    <span class="tab-icon">🔔</span>Alertas
                    ${alertCount > 0 ? `<span class="tab-badge">${alertCount}</span>` : ''}
                </button>
                <button class="tab-item ${state.tab === 'map' ? 'active' : ''}" onclick="app.switchTab('map')">
                    <span class="tab-icon">🗺️</span>Mapa
                </button>
                <button class="tab-item ${state.tab === 'settings' ? 'active' : ''}" onclick="app.switchTab('settings')">
                    <span class="tab-icon">⚙️</span>Ajustes
                </button>
            </div>
        </div>` : ''}`;
}

// ---- VIEWS ----

// Auth
function loginView() {
    return `<div class="auth-container fade-in">
        <div class="auth-logo">🐾</div>
        <div class="auth-title">AnimalMbs</div>
        <div class="auth-subtitle">El historial médico de tu mascota</div>
        <form class="auth-form" id="auth-form">
            <div class="form-group">
                <label class="form-label">Email</label>
                <input class="form-input" type="email" id="auth-email" placeholder="tu@email.com" required autocomplete="email">
            </div>
            <div class="form-group">
                <label class="form-label">Contraseña</label>
                <input class="form-input" type="password" id="auth-password" placeholder="••••••••" required minlength="6" autocomplete="current-password">
            </div>
            <div class="form-group" id="confirm-group" style="display:none">
                <label class="form-label">Confirmar Contraseña</label>
                <input class="form-input" type="password" id="auth-confirm" placeholder="••••••••" autocomplete="new-password">
            </div>
            <button class="btn btn-primary btn-block" type="submit" id="auth-submit">Iniciar Sesión</button>
        </form>
        <div class="auth-toggle">
            <span id="auth-toggle-text">¿No tienes cuenta?</span>
            <a id="auth-toggle-link" onclick="app.toggleAuth()"> Registrarse</a>
        </div>
    </div>`;
}

// Pet List
function petListView() {
    const filtered = state.pets.filter(p =>
        p.name.toLowerCase().includes(state.search.toLowerCase()) ||
        (p.breed || '').toLowerCase().includes(state.search.toLowerCase())
    );

    return renderShell(`
        <div class="search-bar">
            <span class="search-icon">🔍</span>
            <input type="text" placeholder="Buscar mascota..." value="${sanitize(state.search)}" oninput="app.setSearch(this.value)">
        </div>
        <div class="pet-grid">
            <div class="pet-card pet-card-add" onclick="app.navigate('/pets/new')">
                <div class="add-icon">＋</div>
                <div class="add-text">Agregar Mascota</div>
            </div>
            ${filtered.map(pet => `
                <div class="pet-card" data-species="${sanitize(pet.species)}" onclick="app.navigate('/pets/${pet.id}')">
                    ${pet.photo_url
                        ? renderPetImage({ src: pet.photo_url, alt: pet.name, imgClass: 'pet-avatar-img' })
                        : petFallbackMarkup(pet)
                    }
                    <div class="pet-card-name">${sanitize(pet.name)}</div>
                    <div class="pet-card-info">${sanitize(pet.species)}${pet.breed ? ' · ' + sanitize(pet.breed) : ''}</div>
                    ${pet.weight ? `<div class="pet-card-weight">${pet.weight} kg</div>` : ''}
                </div>
            `).join('')}
        </div>
        ${filtered.length === 0 && state.search ?
            emptyState('🔍', 'Sin resultados', `No hay mascotas que coincidan con "${sanitize(state.search)}"`)
        : ''}
    `);
}

// Pet Detail
function petDetailView(petId) {
    const pet = state.pets.find(p => p.id === petId);
    if (!pet) return renderShell(loader('Cargando mascota...'));

    const details = state.petDetails[petId] || {};
    const vacs = details.vaccines || [];
    const aps = details.antiparasitics || [];
    const recs = details.medicalRecords || [];
    const wts = details.weights || [];
    const color = speciesColor(pet.species);

    // Next vaccine/antiparasitic
    const nextVac = vacs.filter(v => v.next_dose_date && daysUntil(v.next_dose_date) !== null)
        .sort((a, b) => new Date(a.next_dose_date) - new Date(b.next_dose_date))[0];
    const nextAp = aps.filter(a => a.next_application_date && daysUntil(a.next_application_date) !== null)
        .sort((a, b) => new Date(a.next_application_date) - new Date(b.next_application_date))[0];

    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.switchTab('pets')">← Mascotas</button>
        </div>

        <div class="pet-hero card" style="color:var(--${color})">
            ${pet.photo_url
                ? renderPetImage({ src: pet.photo_url, alt: pet.name, imgClass: 'pet-hero-img' })
                : petFallbackMarkup(pet, 'hero')
            }
            <div class="pet-hero-name">${sanitize(pet.name)}</div>
            <div class="pet-hero-species">${sanitize(pet.species)}${pet.breed ? ' · ' + sanitize(pet.breed) : ''}</div>
        </div>

        <div class="card mb-16">
            <div class="card-body">
                <div class="info-grid">
                    <div class="info-item">
                        <span class="info-item-label">Sexo</span>
                        <span class="info-item-value">${sanitize(pet.sex || 'Desconocido')}</span>
                    </div>
                    <div class="info-item">
                        <span class="info-item-label">Edad</span>
                        <span class="info-item-value">${petAge(pet.birth_date)}</span>
                    </div>
                    <div class="info-item">
                        <span class="info-item-label">Peso</span>
                        <span class="info-item-value">${pet.weight ? pet.weight + ' kg' : '—'}</span>
                    </div>
                    <div class="info-item">
                        <span class="info-item-label">Color</span>
                        <span class="info-item-value">${sanitize(pet.color || '—')}</span>
                    </div>
                    ${pet.microchip_number ? `
                    <div class="info-item" style="grid-column: span 2">
                        <span class="info-item-label">Microchip</span>
                        <span class="info-item-value">${sanitize(pet.microchip_number)}</span>
                    </div>` : ''}
                </div>
            </div>
        </div>

        <div class="quick-actions">
            <button class="qa-btn qa-green" onclick="app.navigate('/pets/${petId}/vaccines')">
                <span class="qa-icon">💉</span>Vacunas
                ${vacs.length ? `<span class="qa-badge">${vacs.length}</span>` : ''}
            </button>
            <button class="qa-btn qa-orange" onclick="app.navigate('/pets/${petId}/antiparasitics')">
                <span class="qa-icon">🛡️</span>Antipar.
                ${aps.length ? `<span class="qa-badge">${aps.length}</span>` : ''}
            </button>
            <button class="qa-btn qa-purple" onclick="app.navigate('/pets/${petId}/medical')">
                <span class="qa-icon">🩺</span>Historial
                ${recs.length ? `<span class="qa-badge">${recs.length}</span>` : ''}
            </button>
            <button class="qa-btn qa-blue" onclick="app.navigate('/pets/${petId}/weight')">
                <span class="qa-icon">⚖️</span>Peso
                ${wts.length ? `<span class="qa-badge">${wts.length}</span>` : ''}
            </button>
            <button class="qa-btn qa-pink" onclick="app.navigate('/pets/${petId}/qr')">
                <span class="qa-icon">📱</span>QR
            </button>
            <button class="qa-btn qa-yellow" onclick="app.navigate('/pets/${petId}/ficha')">
                <span class="qa-icon">📋</span>Ficha
            </button>
        </div>

        <div style="text-align:center;margin-bottom:12px">
            <button class="btn btn-outline btn-sm" onclick="app.navigate('/pets/${petId}/edit')">✏️ Editar Mascota</button>
        </div>

        ${nextVac ? `
        <div class="alert-card ${urgency(daysUntil(nextVac.next_dose_date))} mb-8">
            <div class="alert-card-body">
                <div class="alert-status ${urgency(daysUntil(nextVac.next_dose_date))}">💉</div>
                <div class="alert-content">
                    <div class="alert-title">${sanitize(nextVac.name)}</div>
                    <div class="alert-pet">Próxima dosis: ${fmtDate(nextVac.next_dose_date)}</div>
                </div>
                <div class="alert-date chip chip-${urgency(daysUntil(nextVac.next_dose_date)) === 'overdue' ? 'danger' : urgency(daysUntil(nextVac.next_dose_date)) === 'soon' ? 'warning' : 'success'}">${daysLabel(daysUntil(nextVac.next_dose_date))}</div>
            </div>
        </div>` : ''}

        ${nextAp ? `
        <div class="alert-card ${urgency(daysUntil(nextAp.next_application_date))} mb-8">
            <div class="alert-card-body">
                <div class="alert-status ${urgency(daysUntil(nextAp.next_application_date))}">🛡️</div>
                <div class="alert-content">
                    <div class="alert-title">${sanitize(nextAp.product_name)}</div>
                    <div class="alert-pet">Próxima aplicación: ${fmtDate(nextAp.next_application_date)}</div>
                </div>
                <div class="alert-date chip chip-${urgency(daysUntil(nextAp.next_application_date)) === 'overdue' ? 'danger' : urgency(daysUntil(nextAp.next_application_date)) === 'soon' ? 'warning' : 'success'}">${daysLabel(daysUntil(nextAp.next_application_date))}</div>
            </div>
        </div>` : ''}

        ${pet.notes ? `
        <div class="card mb-16">
            <div class="card-body">
                <div class="section-title mb-8"><span class="section-icon">📝</span> Notas</div>
                <p style="font-size:0.9rem;color:var(--text-secondary)">${sanitize(pet.notes)}</p>
            </div>
        </div>` : ''}

        <div class="text-center mt-16">
            <button class="btn btn-outline btn-sm" style="color:var(--danger);border-color:var(--danger)" onclick="app.deletePet('${petId}','${sanitize(pet.name)}')">🗑️ Eliminar Mascota</button>
        </div>
    `);
}

// Pet Form (add / edit)
function petFormView(petId = null) {
    const pet = petId ? state.pets.find(p => p.id === petId) : null;
    const title = pet ? 'Editar Mascota' : 'Nueva Mascota';

    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="history.back()">← ${pet ? sanitize(pet.name) : 'Mascotas'}</button>
        </div>
        <div class="page-header"><h1 class="page-title">${title}</h1></div>
        <form class="card" id="pet-form">
            <div class="card-body">
                <div class="form-group text-center">
                    <label class="form-label">Foto de la Mascota</label>
                    <div class="photo-upload-area" id="photo-upload-area" onclick="document.getElementById('pet-photo-input').click()">
                        ${pet?.photo_url
                            ? `<img id="photo-preview" src="${sanitize(pet.photo_url)}" alt="Foto" style="width:100%;height:100%;object-fit:cover">`
                            : `<img id="photo-preview" src="" style="display:none;width:100%;height:100%;object-fit:cover">
                               <div id="photo-placeholder">📷<br><small>Toca para agregar foto</small></div>`
                        }
                    </div>
                    <input type="file" id="pet-photo-input" accept="image/*" style="display:none">
                </div>
                <div class="form-group">
                    <label class="form-label">Nombre *</label>
                    <input class="form-input" name="name" value="${sanitize(pet?.name || '')}" required placeholder="Nombre de tu mascota">
                </div>
                <div class="form-group">
                    <label class="form-label">Especie *</label>
                    <select class="form-input" name="species" required>
                        <option value="">Seleccionar...</option>
                        ${['Perro','Gato','Ave','Conejo','Hámster','Reptil'].map(s =>
                            `<option value="${s}" ${pet?.species === s ? 'selected' : ''}>${speciesEmoji(s)} ${s}</option>`
                        ).join('')}
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Sexo</label>
                    <select class="form-input" name="sex">
                        ${['Desconocido','Macho','Hembra'].map(s =>
                            `<option value="${s}" ${(pet?.sex || 'Desconocido') === s ? 'selected' : ''}>${s}</option>`
                        ).join('')}
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Raza</label>
                    <input class="form-input" name="breed" value="${sanitize(pet?.breed || '')}" placeholder="Ej: Labrador">
                </div>
                <div class="form-group">
                    <label class="form-label">Fecha de Nacimiento</label>
                    <input class="form-input" name="birth_date" type="date" value="${pet?.birth_date || ''}">
                </div>
                <div class="form-group">
                    <label class="form-label">Peso (kg)</label>
                    <input class="form-input" name="weight" type="number" step="0.1" min="0" value="${pet?.weight || ''}" placeholder="Ej: 5.2">
                </div>
                <div class="form-group">
                    <label class="form-label">Color</label>
                    <input class="form-input" name="color" value="${sanitize(pet?.color || '')}" placeholder="Ej: Negro y blanco">
                </div>
                <div class="form-group">
                    <label class="form-label">Microchip</label>
                    <input class="form-input" name="microchip_number" value="${sanitize(pet?.microchip_number || '')}" placeholder="Número de microchip">
                </div>
                <div class="form-group">
                    <label class="form-label">Notas</label>
                    <textarea class="form-input" name="notes" placeholder="Información adicional...">${sanitize(pet?.notes || '')}</textarea>
                </div>
                <button class="btn btn-primary btn-block" type="submit">${pet ? 'Guardar Cambios' : 'Crear Mascota'}</button>
            </div>
        </form>
    `);
}

// Vaccine List
function vaccineListView(petId) {
    const pet = state.pets.find(p => p.id === petId);
    const vacs = (state.petDetails[petId]?.vaccines || []).sort((a, b) => new Date(b.date) - new Date(a.date));

    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}')">← ${sanitize(pet?.name || 'Mascota')}</button>
        </div>
        <div class="page-header">
            <h1 class="page-title">💉 Vacunas</h1>
            <button class="btn btn-primary btn-sm" onclick="app.navigate('/pets/${petId}/vaccines/new')">＋ Agregar</button>
        </div>
        ${vacs.length === 0 ? emptyState('💉', 'Sin vacunas', `Registra la primera vacuna de ${sanitize(pet?.name || '')}`, 'Agregar Vacuna', () => navigate(`/pets/${petId}/vaccines/new`)) : ''}
        ${vacs.map(v => {
            const days = daysUntil(v.next_dose_date);
            const urg = urgency(days);
            return `<div class="list-card slide-up">
                <div class="list-card-body">
                    <div class="list-card-icon" style="background:rgba(92,184,162,0.12);color:var(--primary)">💉</div>
                    <div class="list-card-content">
                        <div class="list-card-title">${sanitize(v.name)}</div>
                        <div class="list-card-sub">${fmtDate(v.date)}${v.veterinarian ? ' · ' + sanitize(v.veterinarian) : ''}</div>
                        <div class="list-card-meta">
                            ${v.lot_number ? `<span class="chip chip-blue">Lote: ${sanitize(v.lot_number)}</span>` : ''}
                            ${v.clinic_name ? `<span class="chip chip-tertiary">🏥 ${sanitize(v.clinic_name)}</span>` : ''}
                            ${v.next_dose_date ? `<span class="chip chip-${urg === 'overdue' ? 'danger' : urg === 'soon' ? 'warning' : 'success'}">📅 ${daysLabel(days)}</span>` : ''}
                        </div>
                    </div>
                    <div class="list-card-actions">
                        <button class="delete-btn" onclick="event.stopPropagation();app.deleteVaccine('${petId}','${v.id}','${sanitize(v.name)}')">🗑️</button>
                    </div>
                </div>
            </div>`;
        }).join('')}
    `);
}

// Vaccine Form
function vaccineFormView(petId) {
    const pet = state.pets.find(p => p.id === petId);
    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}/vaccines')">← Vacunas</button>
        </div>
        <div class="page-header"><h1 class="page-title">Nueva Vacuna</h1></div>
        <form class="card" id="vaccine-form">
            <div class="card-body">
                <div class="form-group">
                    <label class="form-label">Nombre *</label>
                    <input class="form-input" name="name" required placeholder="Ej: Rabia, Parvovirus">
                </div>
                <div class="form-group">
                    <label class="form-label">Fecha *</label>
                    <input class="form-input" name="date" type="date" required value="${new Date().toISOString().split('T')[0]}">
                </div>
                <div class="form-group">
                    <label class="form-label">Próxima Dosis</label>
                    <input class="form-input" name="next_dose_date" type="date">
                </div>
                <div class="form-group">
                    <label class="form-label">Nº de Lote</label>
                    <input class="form-input" name="lot_number" placeholder="Número de lote">
                </div>
                <div class="form-group">
                    <label class="form-label">Veterinario</label>
                    <input class="form-input" name="veterinarian" placeholder="Dr. / Dra.">
                </div>
                <div class="form-group">
                    <label class="form-label">Clínica</label>
                    <input class="form-input" name="clinic_name" placeholder="Nombre de la clínica">
                </div>
                <div class="form-group">
                    <label class="form-label">Notas</label>
                    <textarea class="form-input" name="notes" placeholder="Observaciones..."></textarea>
                </div>
                <button class="btn btn-primary btn-block" type="submit">Guardar Vacuna</button>
            </div>
        </form>
    `);
}

// Antiparasitic List
function antiparasiticListView(petId) {
    const pet = state.pets.find(p => p.id === petId);
    const aps = (state.petDetails[petId]?.antiparasitics || []).sort((a, b) => new Date(b.date) - new Date(a.date));

    const typeLabel = (t) => ({ 'Interno': '🔵 Interno', 'Externo': '🟠 Externo', 'Ambos': '🟣 Ambos' }[t] || t);
    const typeChip = (t) => ({ 'Interno': 'blue', 'Externo': 'secondary', 'Ambos': 'tertiary' }[t] || 'primary');

    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}')">← ${sanitize(pet?.name || 'Mascota')}</button>
        </div>
        <div class="page-header">
            <h1 class="page-title">🛡️ Antiparasitarios</h1>
            <button class="btn btn-secondary btn-sm" onclick="app.navigate('/pets/${petId}/antiparasitics/new')">＋ Agregar</button>
        </div>
        ${aps.length === 0 ? emptyState('🛡️', 'Sin antiparasitarios', `Registra el primer tratamiento de ${sanitize(pet?.name || '')}`, 'Agregar', () => navigate(`/pets/${petId}/antiparasitics/new`)) : ''}
        ${aps.map(a => {
            const days = daysUntil(a.next_application_date);
            const urg = urgency(days);
            return `<div class="list-card slide-up">
                <div class="list-card-body">
                    <div class="list-card-icon" style="background:rgba(255,160,90,0.12);color:var(--secondary)">🛡️</div>
                    <div class="list-card-content">
                        <div class="list-card-title">${sanitize(a.product_name)}</div>
                        <div class="list-card-sub">${fmtDate(a.date)}${a.veterinarian ? ' · ' + sanitize(a.veterinarian) : ''}</div>
                        <div class="list-card-meta">
                            <span class="chip chip-${typeChip(a.type)}">${typeLabel(a.type)}</span>
                            ${a.next_application_date ? `<span class="chip chip-${urg === 'overdue' ? 'danger' : urg === 'soon' ? 'warning' : 'success'}">📅 ${daysLabel(days)}</span>` : ''}
                        </div>
                    </div>
                    <div class="list-card-actions">
                        <button class="delete-btn" onclick="event.stopPropagation();app.deleteAntiparasitic('${petId}','${a.id}','${sanitize(a.product_name)}')">🗑️</button>
                    </div>
                </div>
            </div>`;
        }).join('')}
    `);
}

// Antiparasitic Form
function antiparasiticFormView(petId) {
    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}/antiparasitics')">← Antiparasitarios</button>
        </div>
        <div class="page-header"><h1 class="page-title">Nuevo Antiparasitario</h1></div>
        <form class="card" id="antiparasitic-form">
            <div class="card-body">
                <div class="form-group">
                    <label class="form-label">Producto *</label>
                    <input class="form-input" name="product_name" required placeholder="Ej: Frontline, Nexgard">
                </div>
                <div class="form-group">
                    <label class="form-label">Tipo *</label>
                    <select class="form-input" name="type" required>
                        <option value="Interno">🔵 Interno</option>
                        <option value="Externo">🟠 Externo</option>
                        <option value="Ambos">🟣 Ambos</option>
                    </select>
                </div>
                <div class="form-group">
                    <label class="form-label">Fecha *</label>
                    <input class="form-input" name="date" type="date" required value="${new Date().toISOString().split('T')[0]}">
                </div>
                <div class="form-group">
                    <label class="form-label">Próxima Aplicación</label>
                    <input class="form-input" name="next_application_date" type="date">
                </div>
                <div class="form-group">
                    <label class="form-label">Veterinario</label>
                    <input class="form-input" name="veterinarian" placeholder="Dr. / Dra.">
                </div>
                <div class="form-group">
                    <label class="form-label">Notas</label>
                    <textarea class="form-input" name="notes" placeholder="Observaciones..."></textarea>
                </div>
                <button class="btn btn-secondary btn-block" type="submit">Guardar Antiparasitario</button>
            </div>
        </form>
    `);
}

// Medical Record List
function medicalListView(petId) {
    const pet = state.pets.find(p => p.id === petId);
    const recs = (state.petDetails[petId]?.medicalRecords || []).sort((a, b) => new Date(b.date) - new Date(a.date));

    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}')">← ${sanitize(pet?.name || 'Mascota')}</button>
        </div>
        <div class="page-header">
            <h1 class="page-title">🩺 Historial Médico</h1>
            <button class="btn btn-sm" style="background:var(--tertiary);color:#fff" onclick="app.navigate('/pets/${petId}/medical/new')">＋ Agregar</button>
        </div>
        ${recs.length === 0 ? emptyState('🩺', 'Sin consultas', `Registra la primera consulta de ${sanitize(pet?.name || '')}`, 'Agregar Consulta', () => navigate(`/pets/${petId}/medical/new`)) : ''}
        ${recs.map(r => `
            <div class="list-card slide-up" onclick="app.toggleMedicalDetail(this)">
                <div class="list-card-body">
                    <div class="list-card-icon" style="background:rgba(140,119,216,0.12);color:var(--tertiary)">🩺</div>
                    <div class="list-card-content">
                        <div class="list-card-title">${sanitize(r.reason)}</div>
                        <div class="list-card-sub">${fmtDate(r.date)}${r.veterinarian ? ' · ' + sanitize(r.veterinarian) : ''}</div>
                        <div class="list-card-meta">
                            ${r.clinic_name ? `<span class="chip chip-tertiary">🏥 ${sanitize(r.clinic_name)}</span>` : ''}
                            ${r.diagnosis ? `<span class="chip chip-blue">📋 Diagnóstico</span>` : ''}
                        </div>
                        <div class="medical-detail" style="display:none;margin-top:12px;padding-top:12px;border-top:1px solid var(--border)">
                            ${r.diagnosis ? `<p style="margin-bottom:8px"><strong>Diagnóstico:</strong> ${sanitize(r.diagnosis)}</p>` : ''}
                            ${r.treatment ? `<p style="margin-bottom:8px"><strong>Tratamiento:</strong> ${sanitize(r.treatment)}</p>` : ''}
                            ${r.notes ? `<p style="color:var(--text-secondary)"><strong>Notas:</strong> ${sanitize(r.notes)}</p>` : ''}
                        </div>
                    </div>
                    <div class="list-card-actions">
                        <button class="delete-btn" onclick="event.stopPropagation();app.deleteMedical('${petId}','${r.id}','${sanitize(r.reason)}')">🗑️</button>
                    </div>
                </div>
            </div>
        `).join('')}
    `);
}

// Medical Record Form
function medicalFormView(petId) {
    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}/medical')">← Historial</button>
        </div>
        <div class="page-header"><h1 class="page-title">Nueva Consulta</h1></div>
        <form class="card" id="medical-form">
            <div class="card-body">
                <div class="form-group">
                    <label class="form-label">Motivo *</label>
                    <input class="form-input" name="reason" required placeholder="Ej: Control anual, Emergencia">
                </div>
                <div class="form-group">
                    <label class="form-label">Fecha *</label>
                    <input class="form-input" name="date" type="date" required value="${new Date().toISOString().split('T')[0]}">
                </div>
                <div class="form-group">
                    <label class="form-label">Diagnóstico</label>
                    <textarea class="form-input" name="diagnosis" placeholder="Diagnóstico del veterinario..."></textarea>
                </div>
                <div class="form-group">
                    <label class="form-label">Tratamiento</label>
                    <textarea class="form-input" name="treatment" placeholder="Tratamiento indicado..."></textarea>
                </div>
                <div class="form-group">
                    <label class="form-label">Veterinario</label>
                    <input class="form-input" name="veterinarian" placeholder="Dr. / Dra.">
                </div>
                <div class="form-group">
                    <label class="form-label">Clínica</label>
                    <input class="form-input" name="clinic_name" placeholder="Nombre de la clínica">
                </div>
                <div class="form-group">
                    <label class="form-label">Notas</label>
                    <textarea class="form-input" name="notes" placeholder="Observaciones adicionales..."></textarea>
                </div>
                <button class="btn btn-block" style="background:var(--tertiary);color:#fff" type="submit">Guardar Consulta</button>
            </div>
        </form>
    `);
}

// Weight View
function weightView(petId) {
    const pet = state.pets.find(p => p.id === petId);
    const wts = (state.petDetails[petId]?.weights || []).sort((a, b) => new Date(a.date) - new Date(b.date));
    const latestWeight = wts.length ? wts[wts.length - 1].weight : pet?.weight;

    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}')">← ${sanitize(pet?.name || 'Mascota')}</button>
        </div>
        <div class="page-header"><h1 class="page-title">⚖️ Control de Peso</h1></div>

        <div class="weight-header">
            <div class="weight-current">${latestWeight || '—'}<span class="weight-unit"> kg</span></div>
            <div style="font-size:0.85rem;color:var(--text-secondary);margin-top:4px">Peso actual</div>
        </div>

        ${wts.length >= 2 ? `<div class="chart-container"><canvas id="weight-chart"></canvas></div>` : ''}

        <form class="card mb-16" id="weight-form">
            <div class="card-body">
                <div class="section-title mb-8"><span class="section-icon">➕</span> Registrar Peso</div>
                <div style="display:flex;gap:10px">
                    <div class="form-group" style="flex:1">
                        <input class="form-input" name="weight" type="number" step="0.1" min="0" required placeholder="Peso (kg)">
                    </div>
                    <div class="form-group" style="flex:1">
                        <input class="form-input" name="date" type="date" required value="${new Date().toISOString().split('T')[0]}">
                    </div>
                </div>
                <div class="form-group">
                    <input class="form-input" name="notes" placeholder="Notas (opcional)">
                </div>
                <button class="btn btn-block" style="background:var(--blue);color:#fff" type="submit">Registrar</button>
            </div>
        </form>

        ${wts.length > 0 ? `
        <div class="section-header"><div class="section-title"><span class="section-icon">📊</span> Historial</div></div>
        ${[...wts].reverse().map(w => `
            <div class="list-card slide-up">
                <div class="list-card-body">
                    <div class="list-card-icon" style="background:rgba(89,153,242,0.12);color:var(--blue)">⚖️</div>
                    <div class="list-card-content">
                        <div class="list-card-title">${w.weight} kg</div>
                        <div class="list-card-sub">${fmtDate(w.date)}${w.notes ? ' · ' + sanitize(w.notes) : ''}</div>
                    </div>
                    <div class="list-card-actions">
                        <button class="delete-btn" onclick="event.stopPropagation();app.deleteWeight('${petId}','${w.id}')">🗑️</button>
                    </div>
                </div>
            </div>
        `).join('')}` : ''}
    `);
}

// QR View
function qrView(petId) {
    const pet = state.pets.find(p => p.id === petId);
    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}')">← ${sanitize(pet?.name || 'Mascota')}</button>
        </div>
        <div class="qr-container">
            <div class="pet-avatar lg" style="background:rgba(var(--${speciesColor(pet?.species)}-rgb,0),0.12);margin:0 auto 16px">
                ${speciesEmoji(pet?.species)}
            </div>
            <h2 style="font-weight:800;margin-bottom:4px">${sanitize(pet?.name || '')}</h2>
            <p style="color:var(--text-secondary);margin-bottom:24px">${sanitize(pet?.species || '')}${pet?.breed ? ' · ' + sanitize(pet.breed) : ''}</p>
            <div class="qr-canvas" id="qr-canvas"></div>
            <p class="qr-info">Escanea este código QR para ver la ficha clínica de ${sanitize(pet?.name || '')} desde cualquier dispositivo</p>
            <div class="qr-actions">
                <button class="btn btn-primary btn-sm" onclick="app.downloadQR()">📥 Descargar</button>
                <button class="btn btn-outline btn-sm" onclick="app.openQRLink()">🔗 Abrir enlace</button>
                <button class="btn btn-outline btn-sm" onclick="window.print()">🖨️ Imprimir</button>
            </div>
        </div>
    `);
}

// Ficha View (logged-in users, live data)
function fichaView(petId) {
    const pet = state.pets.find(p => p.id === petId);
    if (!pet) return renderShell(loader('Cargando ficha...'));
    const details = state.petDetails[petId] || {};

    // Build data object compatible with publicFichaView
    const fichaData = {
        pet: {
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            sex: pet.sex,
            birth_date: pet.birth_date,
            weight: pet.weight,
            color: pet.color,
            microchip_number: pet.microchip_number,
        },
        vaccines: details.vaccines || [],
        antiparasitics: details.antiparasitics || [],
        medicalRecords: details.medicalRecords || [],
        weights: details.weights || [],
    };

    // Reuse publicFichaView but wrap with nav shell
    const fichaHTML = publicFichaView(fichaData);
    // Replace the ficha container to add back navigation
    return renderShell(`
        <div class="back-row">
            <button class="back-btn" onclick="app.navigate('/pets/${petId}')">← ${sanitize(pet.name)}</button>
        </div>
        ${fichaHTML.replace('<div class="ficha-container fade-in">', '<div class="ficha-container fade-in" style="padding:0">')}
    `);
}

// Alerts View
function alertsView() {
    const allAlerts = getAllAlerts();
    const overdue = allAlerts.filter(a => a.urgency === 'overdue');
    const soon = allAlerts.filter(a => a.urgency === 'soon');
    const ok = allAlerts.filter(a => a.urgency === 'ok');

    if (allAlerts.length === 0) {
        return renderShell(emptyState('🔔', 'Sin alertas',
            'No hay vacunas ni antiparasitarios pendientes. ¡Todo al día! 🎉'));
    }

    function renderAlertGroup(alerts) {
        return alerts.map(a => `
            <div class="alert-card ${a.urgency}" onclick="app.navigate('/pets/${a.petId}')">
                <div class="alert-card-body">
                    <div class="alert-status ${a.urgency}">${a.icon}</div>
                    <div class="alert-content">
                        <div class="alert-title">${sanitize(a.name)}</div>
                        <div class="alert-pet">${speciesEmoji(a.petSpecies)} ${sanitize(a.petName)}</div>
                    </div>
                    <div class="alert-date chip chip-${a.urgency === 'overdue' ? 'danger' : a.urgency === 'soon' ? 'warning' : 'success'}">${daysLabel(a.days)}</div>
                </div>
            </div>
        `).join('');
    }

    return renderShell(`
        <div class="page-header"><h1 class="page-title">🔔 Alertas</h1></div>
        ${overdue.length ? `<div class="alert-section-title">⚠️ Vencidos (${overdue.length})</div>${renderAlertGroup(overdue)}` : ''}
        ${soon.length ? `<div class="alert-section-title">⏰ Próximos 30 días (${soon.length})</div>${renderAlertGroup(soon)}` : ''}
        ${ok.length ? `<div class="alert-section-title">✅ Programados (${ok.length})</div>${renderAlertGroup(ok)}` : ''}
    `);
}

// Settings View
function settingsView() {
    const petCount = state.pets.length;
    return renderShell(`
        <div class="page-header"><h1 class="page-title">⚙️ Ajustes</h1></div>

        <div class="text-center mb-16">
            <div class="user-avatar-wrap" onclick="document.getElementById('user-photo-input').click()" title="Cambiar foto de perfil">
                ${state.user?.user_metadata?.avatar_url
                    ? renderRemoteImage({ src: state.user.user_metadata.avatar_url, alt: 'Perfil', imgClass: 'user-avatar-img', wrapperClass: 'remote-image-shell user-avatar-shell' })
                    : `<div id="user-avatar-placeholder">🐾</div>`
                }
                <div class="avatar-edit-badge">📷</div>
            </div>
            <input type="file" id="user-photo-input" accept="image/*" style="display:none">
            <div style="font-size:1.3rem;font-weight:800;color:var(--primary);margin-top:8px">AnimalMbs</div>
            <div style="font-size:0.85rem;color:var(--text-secondary)">${petCount} mascota${petCount !== 1 ? 's' : ''} registrada${petCount !== 1 ? 's' : ''}</div>
        </div>

        <div class="settings-section">
            <div class="settings-item">
                <div class="settings-icon" style="background:rgba(89,153,242,0.12);color:var(--blue)">👤</div>
                <div class="settings-label">Cuenta</div>
                <div class="settings-value">${sanitize(state.user?.email || '')}</div>
            </div>
            <div class="settings-item">
                <div class="settings-icon" style="background:rgba(92,184,162,0.12);color:var(--primary)">📱</div>
                <div class="settings-label">Sincronización</div>
                <div class="settings-value">Conectado con la app iOS</div>
            </div>
            <div class="settings-item">
                <div class="settings-icon" style="background:rgba(255,160,90,0.12);color:var(--secondary)">🔔</div>
                <div class="settings-label">Alertas</div>
                <div class="settings-value">3 días antes y el día</div>
            </div>
        </div>

        <div class="settings-section">
            <div class="settings-item">
                <div class="settings-icon" style="background:rgba(140,119,216,0.12);color:var(--tertiary)">ℹ️</div>
                <div class="settings-label">Versión</div>
                <div class="settings-value">v2.0.0</div>
            </div>
            <div class="settings-item">
                <div class="settings-icon" style="background:rgba(92,184,162,0.12);color:var(--primary)">🌐</div>
                <div class="settings-label">Web</div>
                <div class="settings-value">animalm.netlify.app</div>
            </div>
        </div>

        <div class="text-center mt-16">
            <button class="btn btn-outline btn-sm" style="color:var(--danger);border-color:var(--danger)" onclick="app.handleLogout()">🚪 Cerrar Sesión</button>
        </div>

        <div class="text-center mt-16" style="font-size:0.8rem;color:var(--text-tertiary)">
            Hecho con ❤️ para tus mascotas
        </div>
    `);
}

// Public Ficha (from QR)
function publicFichaView(data) {
    // Handle both iOS compressed format (v2) and web full format
    const pet = data.pet || data;
    const isIOS = !!data.app; // iOS sets "app": "AnimalMbs"

    // Normalize vaccines: iOS uses {n, d, nx, l, vet, cl, nt}, web uses full keys
    const vacs = (data.vac || data.vaccines || []).map(v => ({
        name: v.n || v.name || '',
        date: v.d || v.date || '',
        nextDose: v.nx || v.next_dose_date || '',
        lotNumber: v.l || v.lot_number || '',
        veterinarian: v.vet || v.veterinarian || '',
        clinic: v.cl || v.clinic_name || '',
        notes: v.nt || v.notes || '',
    }));

    // Normalize antiparasitics: iOS uses {n, t, d, nx, vet, nt}, web uses full keys
    const aps = (data.ap || data.antiparasitics || []).map(a => ({
        name: a.n || a.product_name || '',
        type: a.t || a.type || '',
        date: a.d || a.date || '',
        nextDate: a.nx || a.next_application_date || '',
        veterinarian: a.vet || a.veterinarian || '',
        notes: a.nt || a.notes || '',
    }));

    // Normalize medical records: iOS uses {r, d, dx, tx, vet, cl, nt}, web uses full keys
    const recs = (data.med || data.medicalRecords || []).map(r => ({
        reason: r.r || r.reason || '',
        date: r.d || r.date || '',
        diagnosis: r.dx || r.diagnosis || '',
        treatment: r.tx || r.treatment || '',
        veterinarian: r.vet || r.veterinarian || '',
        clinic: r.cl || r.clinic_name || '',
        notes: r.nt || r.notes || '',
    }));

    // Normalize weights: iOS uses {w, d, nt}, web uses full keys
    const wts = (data.wt || data.weights || []).map(w => ({
        weight: w.w || w.weight || 0,
        date: w.d || w.date || '',
        notes: w.nt || w.notes || '',
    }));

    // Pet age — handle both iOS (pre-calculated) and web (birth_date)
    const age = pet.age || (pet.birth_date ? petAge(pet.birth_date) : '');
    // Pet microchip — handle iOS (microchip) and web (microchip_number)
    const microchip = pet.microchip || pet.microchip_number || '';

    return `
        <div class="ficha-container fade-in">
            <div class="ficha-header">
                <div style="font-size:3rem">${speciesEmoji(pet.species)}</div>
                <h1>${sanitize(pet.name)}</h1>
                <p>${sanitize(pet.species)}${pet.breed ? ' · ' + sanitize(pet.breed) : ''}</p>
                <p style="opacity:0.8;font-size:0.8rem;margin-top:4px">Hoja Clínica Veterinaria</p>
            </div>

            <div class="ficha-section">
                <div class="ficha-section-header">🐾 Datos del Paciente</div>
                <div class="ficha-section-body">
                    <div class="ficha-row"><span class="ficha-row-label">Nombre</span><span class="ficha-row-value">${sanitize(pet.name)}</span></div>
                    <div class="ficha-row"><span class="ficha-row-label">Especie</span><span class="ficha-row-value">${sanitize(pet.species)}</span></div>
                    ${pet.breed ? `<div class="ficha-row"><span class="ficha-row-label">Raza</span><span class="ficha-row-value">${sanitize(pet.breed)}</span></div>` : ''}
                    ${pet.sex ? `<div class="ficha-row"><span class="ficha-row-label">Sexo</span><span class="ficha-row-value">${sanitize(pet.sex)}</span></div>` : ''}
                    ${age ? `<div class="ficha-row"><span class="ficha-row-label">Edad</span><span class="ficha-row-value">${sanitize(age)}</span></div>` : ''}
                    ${pet.weight ? `<div class="ficha-row"><span class="ficha-row-label">Peso</span><span class="ficha-row-value">${pet.weight} kg</span></div>` : ''}
                    ${pet.color ? `<div class="ficha-row"><span class="ficha-row-label">Color</span><span class="ficha-row-value">${sanitize(pet.color)}</span></div>` : ''}
                    ${microchip ? `<div class="ficha-row"><span class="ficha-row-label">Microchip</span><span class="ficha-row-value">${sanitize(microchip)}</span></div>` : ''}
                </div>
            </div>

            ${vacs.length ? `
            <div class="ficha-section">
                <div class="ficha-section-header">💉 Vacunas (${vacs.length})</div>
                <div class="ficha-section-body">
                    ${vacs.map(v => `
                        <div class="ficha-record">
                            <div class="ficha-row">
                                <span class="ficha-row-label" style="font-weight:600;color:var(--text)">${sanitize(v.name)}</span>
                                <span class="ficha-row-value">${fmtDate(v.date)}</span>
                            </div>
                            ${v.nextDose ? `<div class="ficha-detail"><span class="ficha-detail-icon">📅</span> Próxima dosis: ${fmtDate(v.nextDose)}</div>` : ''}
                            ${v.lotNumber ? `<div class="ficha-detail"><span class="ficha-detail-icon">🏷️</span> Lote: ${sanitize(v.lotNumber)}</div>` : ''}
                            ${v.veterinarian ? `<div class="ficha-detail"><span class="ficha-detail-icon">👨‍⚕️</span> ${sanitize(v.veterinarian)}</div>` : ''}
                            ${v.clinic ? `<div class="ficha-detail"><span class="ficha-detail-icon">🏥</span> ${sanitize(v.clinic)}</div>` : ''}
                            ${v.notes ? `<div class="ficha-detail ficha-note"><span class="ficha-detail-icon">📝</span> ${sanitize(v.notes)}</div>` : ''}
                        </div>
                    `).join('')}
                </div>
            </div>` : ''}

            ${aps.length ? `
            <div class="ficha-section">
                <div class="ficha-section-header">🛡️ Antiparasitarios (${aps.length})</div>
                <div class="ficha-section-body">
                    ${aps.map(a => `
                        <div class="ficha-record">
                            <div class="ficha-row">
                                <span class="ficha-row-label" style="font-weight:600;color:var(--text)">${sanitize(a.name)}</span>
                                <span class="ficha-row-value">${fmtDate(a.date)}</span>
                            </div>
                            ${a.type ? `<div class="ficha-detail"><span class="ficha-detail-icon">📋</span> Tipo: ${sanitize(a.type)}</div>` : ''}
                            ${a.nextDate ? `<div class="ficha-detail"><span class="ficha-detail-icon">📅</span> Próxima aplicación: ${fmtDate(a.nextDate)}</div>` : ''}
                            ${a.veterinarian ? `<div class="ficha-detail"><span class="ficha-detail-icon">👨‍⚕️</span> ${sanitize(a.veterinarian)}</div>` : ''}
                            ${a.notes ? `<div class="ficha-detail ficha-note"><span class="ficha-detail-icon">📝</span> ${sanitize(a.notes)}</div>` : ''}
                        </div>
                    `).join('')}
                </div>
            </div>` : ''}

            ${recs.length ? `
            <div class="ficha-section">
                <div class="ficha-section-header">🩺 Historial Médico (${recs.length})</div>
                <div class="ficha-section-body">
                    ${recs.map(r => `
                        <div class="ficha-record">
                            <div class="ficha-row">
                                <span class="ficha-row-label" style="font-weight:600;color:var(--text)">${sanitize(r.reason)}</span>
                                <span class="ficha-row-value">${fmtDate(r.date)}</span>
                            </div>
                            ${r.diagnosis ? `<div class="ficha-detail"><span class="ficha-detail-icon">🔍</span> Diagnóstico: ${sanitize(r.diagnosis)}</div>` : ''}
                            ${r.treatment ? `<div class="ficha-detail"><span class="ficha-detail-icon">💊</span> Tratamiento: ${sanitize(r.treatment)}</div>` : ''}
                            ${r.veterinarian ? `<div class="ficha-detail"><span class="ficha-detail-icon">👨‍⚕️</span> ${sanitize(r.veterinarian)}</div>` : ''}
                            ${r.clinic ? `<div class="ficha-detail"><span class="ficha-detail-icon">🏥</span> ${sanitize(r.clinic)}</div>` : ''}
                            ${r.notes ? `<div class="ficha-detail ficha-note"><span class="ficha-detail-icon">📝</span> ${sanitize(r.notes)}</div>` : ''}
                        </div>
                    `).join('')}
                </div>
            </div>` : ''}

            ${wts.length ? `
            <div class="ficha-section">
                <div class="ficha-section-header">⚖️ Historial de Peso (${wts.length})</div>
                <div class="ficha-section-body">
                    ${wts.map(w => `
                        <div class="ficha-row">
                            <span class="ficha-row-label">${fmtDate(w.date)}</span>
                            <span class="ficha-row-value" style="font-weight:700">${w.weight} kg</span>
                        </div>
                    `).join('')}
                </div>
            </div>` : ''}

            <div class="ficha-footer">
                ${data.gen ? `Ficha generada el ${sanitize(data.gen)}<br>` : `Generado el ${new Date().toLocaleDateString('es-CL', { dateStyle: 'long' })}<br>`}
                AnimalMbs — animalm.netlify.app
            </div>

            <div class="text-center mb-16" style="display:flex;gap:10px;justify-content:center">
                <button class="btn btn-primary btn-sm" onclick="window.print()">🖨️ Imprimir / PDF</button>
            </div>
        </div>`;
}

// Map View
function mapView() {
    return renderShell(`
        <div class="page-header"><h1 class="page-title">🗺️ Veterinarias Cercanas</h1></div>
        <div id="vet-map" style="height:300px;border-radius:var(--radius);overflow:hidden;margin-bottom:16px;border:1px solid var(--border)"></div>
        <div id="vet-list">
            <div class="loader fade-in">
                <div class="paw-loader"><span>🐾</span><span>🐾</span><span>🐾</span></div>
                <div class="loader-text">Buscando veterinarias...</div>
            </div>
        </div>
    `);
}

function initMap() {
    const mapEl = document.getElementById('vet-map');
    const listEl = document.getElementById('vet-list');
    if (!mapEl || !listEl) return;

    // Use cached results if available (re-render map + list from cache)
    if (state.vetResults && state.vetUserCoords) {
        const { lat, lng } = state.vetUserCoords;
        const map = window.L.map(mapEl).setView([lat, lng], 14);
        window._leafletMap = map;
        window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);
        window.L.circleMarker([lat, lng], {
            radius: 8, color: '#5cb8a2', fillColor: '#5cb8a2', fillOpacity: 0.9, weight: 2
        }).addTo(map).bindPopup('📍 Tu ubicación');
        state.vetResults.forEach(el => {
            const elLat = el.lat || el.center?.lat;
            const elLng = el.lon || el.center?.lon;
            if (!elLat || !elLng) return;
            window.L.marker([elLat, elLng]).addTo(map).bindPopup(`<strong>${el.tags?.name || 'Veterinaria'}</strong>`);
        });
        renderVetList(state.vetResults, { lat, lng }, listEl);
        return;
    }

    if (!navigator.geolocation) {
        listEl.innerHTML = `<div class="empty-state fade-in">
            <div class="empty-icon">📍</div>
            <div class="empty-title">Geolocalización no disponible</div>
            <div class="empty-sub">Tu navegador no soporta geolocalización.</div>
        </div>`;
        return;
    }

    navigator.geolocation.getCurrentPosition(async (pos) => {
        const { latitude: lat, longitude: lng } = pos.coords;
        state.vetUserCoords = { lat, lng };

        // Initialize Leaflet map
        if (window._leafletMap) {
            window._leafletMap.remove();
            window._leafletMap = null;
        }
        const map = window.L.map(mapEl).setView([lat, lng], 14);
        window._leafletMap = map;

        window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);

        // User marker
        window.L.circleMarker([lat, lng], {
            radius: 8, color: '#5cb8a2', fillColor: '#5cb8a2', fillOpacity: 0.9, weight: 2
        }).addTo(map).bindPopup('📍 Tu ubicación');

        // Query Overpass API for nearby vets
        const overpassQuery = `[out:json];(node["amenity"="veterinary"](around:5000,${lat},${lng});way["amenity"="veterinary"](around:5000,${lat},${lng}););out center;`;
        const overpassUrl = `https://overpass-api.de/api/interpreter?data=${encodeURIComponent(overpassQuery)}`;

        try {
            const resp = await fetch(overpassUrl);
            const data = await resp.json();
            const elements = data.elements || [];
            state.vetResults = elements;

            elements.forEach(el => {
                const elLat = el.lat || el.center?.lat;
                const elLng = el.lon || el.center?.lon;
                if (!elLat || !elLng) return;
                const name = el.tags?.name || 'Veterinaria';
                window.L.marker([elLat, elLng])
                    .addTo(map)
                    .bindPopup(`<strong>${name}</strong>`);
            });

            renderVetList(elements, { lat, lng }, listEl);

            if (elements.length > 0) {
                const bounds = window.L.latLngBounds([[lat, lng]]);
                elements.forEach(el => {
                    const elLat = el.lat || el.center?.lat;
                    const elLng = el.lon || el.center?.lon;
                    if (elLat && elLng) bounds.extend([elLat, elLng]);
                });
                map.fitBounds(bounds, { padding: [40, 40] });
            }
        } catch (err) {
            listEl.innerHTML = `<div class="empty-state fade-in">
                <div class="empty-icon">🔌</div>
                <div class="empty-title">Error al buscar</div>
                <div class="empty-sub">No se pudo conectar al servicio de mapas. Intenta más tarde.</div>
            </div>`;
        }
    }, () => {
        if (mapEl) mapEl.style.display = 'none';
        listEl.innerHTML = `<div class="empty-state fade-in">
            <div class="empty-icon">📍</div>
            <div class="empty-title">Ubicación no disponible</div>
            <div class="empty-sub">Activa la ubicación en tu navegador para ver veterinarias cercanas.</div>
        </div>`;
    });
}

function renderVetList(elements, userCoords, listEl) {
    if (!elements || elements.length === 0) {
        listEl.innerHTML = `<div class="empty-state fade-in">
            <div class="empty-icon">🏥</div>
            <div class="empty-title">Sin veterinarias cercanas</div>
            <div class="empty-sub">No se encontraron veterinarias en un radio de 5 km.</div>
        </div>`;
        return;
    }

    const calcDist = (lat1, lng1, lat2, lng2) => {
        const R = 6371000;
        const dLat = (lat2 - lat1) * Math.PI / 180;
        const dLng = (lng2 - lng1) * Math.PI / 180;
        const a = Math.sin(dLat/2)**2 + Math.cos(lat1 * Math.PI/180) * Math.cos(lat2 * Math.PI/180) * Math.sin(dLng/2)**2;
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    };

    const fmtDist = (m) => m < 1000 ? `${Math.round(m)} m` : `${(m/1000).toFixed(1)} km`;

    const sorted = [...elements].filter(el => el.lat || el.center?.lat).sort((a, b) => {
        if (!userCoords) return 0;
        const da = calcDist(userCoords.lat, userCoords.lng, a.lat || a.center.lat, a.lon || a.center.lon);
        const db = calcDist(userCoords.lat, userCoords.lng, b.lat || b.center.lat, b.lon || b.center.lon);
        return da - db;
    });

    listEl.innerHTML = `
        <div class="section-title mb-8" style="margin-top:8px"><span class="section-icon">🏥</span> ${sorted.length} Veterinaria${sorted.length !== 1 ? 's' : ''} encontrada${sorted.length !== 1 ? 's' : ''}</div>
        ${sorted.map(el => {
            const elLat = el.lat || el.center?.lat;
            const elLng = el.lon || el.center?.lon;
            const name = el.tags?.name || 'Veterinaria';
            const addr = [el.tags?.['addr:street'], el.tags?.['addr:housenumber']].filter(Boolean).join(' ') || el.tags?.['addr:full'] || '';
            const phone = el.tags?.phone || el.tags?.['contact:phone'] || '';
            const dist = userCoords ? fmtDist(calcDist(userCoords.lat, userCoords.lng, elLat, elLng)) : '';
            return `<div class="vet-card slide-up">
                <div class="vet-icon">🏥</div>
                <div class="vet-info">
                    <div class="vet-name">${sanitize(name)}</div>
                    ${addr ? `<div class="vet-addr">📍 ${sanitize(addr)}</div>` : ''}
                    ${phone ? `<div class="vet-addr">📞 <a href="tel:${sanitize(phone)}" style="color:var(--primary)">${sanitize(phone)}</a></div>` : ''}
                    ${dist ? `<div class="vet-distance">🚗 ${dist}</div>` : ''}
                </div>
                <button class="vet-directions" onclick="showMapPicker(${elLat},${elLng},'${sanitize(name).replace(/'/g,"\\'")}',event)" title="Cómo llegar">➡️</button>
            </div>`;
        }).join('')}`;
}

// ---- Map App Picker ----
function showMapPicker(lat, lng, name, event) {
    event.stopPropagation();
    const existing = document.getElementById('map-picker-overlay');
    if (existing) { existing.remove(); return; }

    const overlay = document.createElement('div');
    overlay.id = 'map-picker-overlay';
    overlay.className = 'map-picker-overlay';
    overlay.innerHTML = `
        <div class="map-picker-sheet">
            <div class="map-picker-title">Cómo llegar a<br><strong>${name}</strong></div>
            <a class="map-picker-option" href="https://maps.apple.com/?daddr=${lat},${lng}&dirflg=d" target="_blank" rel="noopener">
                <img class="map-picker-icon" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 60'%3E%3Crect width='60' height='60' rx='13' fill='%23fff'/%3E%3Ctext y='44' x='7' font-size='42'%3E🗺️%3C/text%3E%3C/svg%3E" alt=""><span>Apple Maps</span>
            </a>
            <a class="map-picker-option" href="https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}" target="_blank" rel="noopener">
                <img class="map-picker-icon" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 60'%3E%3Crect width='60' height='60' rx='13' fill='%234285F4'/%3E%3Ctext y='44' x='7' font-size='42'%3E🗺%3C/text%3E%3C/svg%3E" alt=""><span>Google Maps</span>
            </a>
            <a class="map-picker-option" href="https://waze.com/ul?ll=${lat},${lng}&navigate=yes" target="_blank" rel="noopener">
                <img class="map-picker-icon" src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 60'%3E%3Crect width='60' height='60' rx='13' fill='%2305C8F0'/%3E%3Ctext y='44' x='7' font-size='42'%3E😊%3C/text%3E%3C/svg%3E" alt=""><span>Waze</span>
            </a>
            <button class="map-picker-cancel" onclick="document.getElementById('map-picker-overlay').remove()">Cancelar</button>
        </div>
    `;

    document.body.appendChild(overlay);
    overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
}
window.showMapPicker = showMapPicker;

// ---- Alert Helpers ----
function getAllAlerts() {
    const alerts = [];
    for (const pet of state.pets) {
        const details = state.petDetails[pet.id];
        if (!details) continue;
        for (const v of (details.vaccines || [])) {
            if (v.next_dose_date) {
                const days = daysUntil(v.next_dose_date);
                alerts.push({ type: 'vaccine', icon: '💉', name: v.name, petId: pet.id, petName: pet.name, petSpecies: pet.species, days, urgency: urgency(days), date: v.next_dose_date });
            }
        }
        for (const a of (details.antiparasitics || [])) {
            if (a.next_application_date) {
                const days = daysUntil(a.next_application_date);
                alerts.push({ type: 'antiparasitic', icon: '🛡️', name: a.product_name, petId: pet.id, petName: pet.name, petSpecies: pet.species, days, urgency: urgency(days), date: a.next_application_date });
            }
        }
    }
    alerts.sort((a, b) => a.days - b.days);
    return alerts;
}

function getAlertCount() {
    return getAllAlerts().filter(a => a.urgency === 'overdue' || a.urgency === 'soon').length;
}

// ---- Data Loading ----
async function loadPets() {
    try {
        state.pets = await pets.list();
        // Load details for all pets (for alerts)
        await Promise.all(state.pets.map(p => loadPetDetails(p.id)));
    } catch (e) {
        toast('Error cargando mascotas: ' + e.message, 'error');
    }
}

async function loadPetDetails(petId) {
    try {
        const [vacs, aps, recs, wts] = await Promise.all([
            vaccines.list(petId),
            antiparasitics.list(petId),
            medicalRecords.list(petId),
            weightEntries.list(petId),
        ]);
        state.petDetails[petId] = { vaccines: vacs, antiparasitics: aps, medicalRecords: recs, weights: wts };
    } catch (e) {
        console.error('Error loading details for pet', petId, e);
    }
}

// ---- Chart Rendering ----
function renderWeightChart(petId) {
    const canvas = document.getElementById('weight-chart');
    if (!canvas) return;
    const wts = (state.petDetails[petId]?.weights || []).sort((a, b) => new Date(a.date) - new Date(b.date));
    if (wts.length < 2) return;

    const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const gridColor = isDark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';
    const textColor = isDark ? '#aeaeb2' : '#636366';

    new Chart(canvas, {
        type: 'line',
        data: {
            labels: wts.map(w => fmtDateShort(w.date)),
            datasets: [{
                label: 'Peso (kg)',
                data: wts.map(w => w.weight),
                borderColor: '#5999f2',
                backgroundColor: 'rgba(89,153,242,0.12)',
                fill: true,
                tension: 0.35,
                pointRadius: 5,
                pointBackgroundColor: '#5999f2',
                pointBorderColor: '#fff',
                pointBorderWidth: 2,
                pointHoverRadius: 7,
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: isDark ? '#3a3a3c' : '#fff',
                    titleColor: isDark ? '#f2f2f7' : '#1c1c1e',
                    bodyColor: isDark ? '#aeaeb2' : '#636366',
                    borderColor: isDark ? '#636366' : '#e5e5e5',
                    borderWidth: 1,
                    cornerRadius: 10,
                    padding: 10,
                    callbacks: { label: (ctx) => `${ctx.parsed.y} kg` }
                }
            },
            scales: {
                x: { grid: { color: gridColor }, ticks: { color: textColor, font: { family: 'Nunito', size: 11 } } },
                y: { grid: { color: gridColor }, ticks: { color: textColor, font: { family: 'Nunito', size: 11 }, callback: v => v + ' kg' } }
            }
        }
    });
}

// ---- QR Generation ----
async function generateQR(petId) {
    const container = document.getElementById('qr-canvas');
    if (!container) return;

    try {
        const fullData = await getFullPetData(petId);
        const encoded = btoa(unescape(encodeURIComponent(JSON.stringify(fullData))))
            .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
        state._qrLink = `https://animalm.netlify.app?d=${encoded}`;

        const canvas = document.createElement('canvas');
        await QRCode.toCanvas(canvas, state._qrLink, {
            width: 220,
            margin: 2,
            color: { dark: '#1c1c1e', light: '#ffffff' }
        });
        container.innerHTML = '';
        container.appendChild(canvas);
    } catch (e) {
        container.innerHTML = '<p style="color:var(--danger)">Error generando QR</p>';
    }
}

// ---- Form Handlers ----
function getFormData(formEl) {
    const fd = new FormData(formEl);
    const obj = {};
    for (const [key, val] of fd.entries()) {
        const trimmed = val.toString().trim();
        if (trimmed) obj[key] = trimmed;
    }
    return obj;
}

// ---- Router & Render ----
async function render() {
    const app = document.getElementById('app');

    // Public ficha
    const urlParams = new URLSearchParams(window.location.search);
    const fichaData = urlParams.get('d');
    if (fichaData) {
        try {
            const padded = fichaData.replace(/-/g, '+').replace(/_/g, '/');
            const json = decodeURIComponent(escape(atob(padded)));
            const data = JSON.parse(json);
            app.innerHTML = publicFichaView(data);
        } catch (e) {
            app.innerHTML = '<div class="auth-container"><p style="color:var(--danger)">Error al leer los datos de la ficha</p></div>';
        }
        return;
    }

    // Not logged in
    if (!state.user) {
        app.innerHTML = loginView();
        bindAuthForm();
        return;
    }

    // Loading
    if (state.loading) {
        app.innerHTML = renderShell(loader());
        return;
    }

    const route = getRoute();
    const parts = route.split('/').filter(Boolean);

    // Tab-based routes
    if (parts.length === 0 || (parts[0] !== 'pets')) {
        if (state.tab === 'alerts') {
            app.innerHTML = alertsView();
        } else if (state.tab === 'map') {
            app.innerHTML = mapView();
            setTimeout(() => initMap(), 50);
        } else if (state.tab === 'settings') {
            app.innerHTML = settingsView();
            setTimeout(() => bindSettingsPhotoUpload(), 50);
        } else {
            app.innerHTML = petListView();
        }
        return;
    }

    // /pets/new
    if (parts[1] === 'new') {
        app.innerHTML = petFormView();
        bindPetForm();
        return;
    }

    const petId = parts[1];

    // /pets/:id/edit
    if (parts[2] === 'edit') {
        app.innerHTML = petFormView(petId);
        bindPetForm(petId);
        return;
    }

    // /pets/:id/vaccines
    if (parts[2] === 'vaccines') {
        if (parts[3] === 'new') {
            app.innerHTML = vaccineFormView(petId);
            bindVaccineForm(petId);
        } else {
            app.innerHTML = vaccineListView(petId);
        }
        return;
    }

    // /pets/:id/antiparasitics
    if (parts[2] === 'antiparasitics') {
        if (parts[3] === 'new') {
            app.innerHTML = antiparasiticFormView(petId);
            bindAntiparasiticForm(petId);
        } else {
            app.innerHTML = antiparasiticListView(petId);
        }
        return;
    }

    // /pets/:id/medical
    if (parts[2] === 'medical') {
        if (parts[3] === 'new') {
            app.innerHTML = medicalFormView(petId);
            bindMedicalForm(petId);
        } else {
            app.innerHTML = medicalListView(petId);
        }
        return;
    }

    // /pets/:id/weight
    if (parts[2] === 'weight') {
        app.innerHTML = weightView(petId);
        bindWeightForm(petId);
        renderWeightChart(petId);
        return;
    }

    // /pets/:id/qr
    if (parts[2] === 'qr') {
        app.innerHTML = qrView(petId);
        generateQR(petId);
        return;
    }

    // /pets/:id/ficha
    if (parts[2] === 'ficha') {
        app.innerHTML = fichaView(petId);
        return;
    }

    // /pets/:id (detail)
    app.innerHTML = petDetailView(petId);
}

// ---- Form Bindings ----
let _authMode = 'login';

function bindAuthForm() {
    const form = document.getElementById('auth-form');
    if (!form) return;
    form.onsubmit = async (e) => {
        e.preventDefault();
        const email = document.getElementById('auth-email').value.trim();
        const password = document.getElementById('auth-password').value;
        const btn = document.getElementById('auth-submit');
        btn.disabled = true;
        btn.textContent = 'Cargando...';

        try {
            if (_authMode === 'register') {
                const confirmPw = document.getElementById('auth-confirm').value;
                if (password !== confirmPw) { toast('Las contraseñas no coinciden', 'error'); btn.disabled = false; btn.textContent = 'Registrarse'; return; }
                const { error } = await auth.signUp(email, password);
                if (error) throw error;
                toast('Cuenta creada. Revisa tu email para confirmar.', 'info');
            } else {
                const { data, error } = await auth.signIn(email, password);
                if (error) throw error;
                state.user = data.session.user;
                state.loading = true;
                render();
                await loadPets();
                state.loading = false;
                render();
                toast('¡Bienvenido!');
            }
        } catch (err) {
            toast(err.message || 'Error de autenticación', 'error');
        }
        btn.disabled = false;
        btn.textContent = _authMode === 'register' ? 'Registrarse' : 'Iniciar Sesión';
    };
}

function bindPetForm(petId = null) {
    const form = document.getElementById('pet-form');
    if (!form) return;

    // Photo preview
    let selectedPhotoFile = null;
    const photoInput = document.getElementById('pet-photo-input');
    if (photoInput) {
        photoInput.onchange = (e) => {
            const file = e.target.files[0];
            if (!file) return;
            selectedPhotoFile = file;
            const preview = document.getElementById('photo-preview');
            const placeholder = document.getElementById('photo-placeholder');
            if (preview) {
                preview.src = URL.createObjectURL(file);
                preview.style.display = 'block';
            }
            if (placeholder) placeholder.style.display = 'none';
        };
    }

    form.onsubmit = async (e) => {
        e.preventDefault();
        const data = getFormData(form);
        if (data.weight) data.weight = parseFloat(data.weight);
        try {
            let savedId = petId;
            if (petId) {
                await pets.update(petId, data);
            } else {
                const created = await pets.create(data);
                savedId = created.id;
            }
            // Upload photo if selected
            if (selectedPhotoFile && savedId) {
                try {
                    const { data: { user } } = await (await import('./api.js')).auth.getUser();
                    const photoUrl = await petPhotos.upload(user.id, savedId, selectedPhotoFile);
                    await pets.update(savedId, { photo_url: photoUrl });
                } catch (photoErr) {
                    toast('Foto no guardada: ' + photoErr.message, 'error');
                }
            }
            toast(petId ? 'Mascota actualizada' : 'Mascota creada');
            await loadPets();
            if (savedId) navigate(`/pets/${savedId}`);
            else { state.tab = 'pets'; navigate('/'); }
            render();
        } catch (err) { toast(err.message, 'error'); }
    };
}

function bindVaccineForm(petId) {
    const form = document.getElementById('vaccine-form');
    if (!form) return;
    form.onsubmit = async (e) => {
        e.preventDefault();
        const data = getFormData(form);
        data.pet_id = petId;
        try {
            await vaccines.create(data);
            toast('Vacuna registrada');
            await loadPetDetails(petId);
            navigate(`/pets/${petId}/vaccines`);
            render();
        } catch (err) { toast(err.message, 'error'); }
    };
}

function bindAntiparasiticForm(petId) {
    const form = document.getElementById('antiparasitic-form');
    if (!form) return;
    form.onsubmit = async (e) => {
        e.preventDefault();
        const data = getFormData(form);
        data.pet_id = petId;
        try {
            await antiparasitics.create(data);
            toast('Antiparasitario registrado');
            await loadPetDetails(petId);
            navigate(`/pets/${petId}/antiparasitics`);
            render();
        } catch (err) { toast(err.message, 'error'); }
    };
}

function bindMedicalForm(petId) {
    const form = document.getElementById('medical-form');
    if (!form) return;
    form.onsubmit = async (e) => {
        e.preventDefault();
        const data = getFormData(form);
        data.pet_id = petId;
        try {
            await medicalRecords.create(data);
            toast('Consulta registrada');
            await loadPetDetails(petId);
            navigate(`/pets/${petId}/medical`);
            render();
        } catch (err) { toast(err.message, 'error'); }
    };
}

function bindWeightForm(petId) {
    const form = document.getElementById('weight-form');
    if (!form) return;
    form.onsubmit = async (e) => {
        e.preventDefault();
        const data = getFormData(form);
        data.pet_id = petId;
        data.weight = parseFloat(data.weight);
        try {
            await weightEntries.create(data);
            toast('Peso registrado');
            // Also update pet weight
            await pets.update(petId, { weight: data.weight });
            await loadPets();
            await loadPetDetails(petId);
            navigate(`/pets/${petId}/weight`);
            render();
        } catch (err) { toast(err.message, 'error'); }
    };
}

function bindSettingsPhotoUpload() {
    const input = document.getElementById('user-photo-input');
    if (!input) return;
    input.onchange = async (e) => {
        const file = e.target.files[0];
        if (!file || !state.user?.id) return;
        try {
            const url = await userPhotos.upload(state.user.id, file);
            await import('./api.js').then(api => api.auth.updateUser
                ? api.sb.auth.updateUser({ data: { avatar_url: url } })
                : Promise.resolve()
            );
            // Update local state
            if (!state.user.user_metadata) state.user.user_metadata = {};
            state.user.user_metadata.avatar_url = url;
            // Update avatar in DOM without full re-render
            const wrap = document.querySelector('.user-avatar-wrap');
            if (wrap) {
                wrap.innerHTML = `${renderRemoteImage({ src: url, alt: 'Perfil', imgClass: 'user-avatar-img', wrapperClass: 'remote-image-shell user-avatar-shell' })}<div class="avatar-edit-badge">📷</div>`;
            }
            toast('Foto de perfil actualizada');
        } catch (err) {
            toast('Error subiendo foto: ' + err.message, 'error');
        }
    };
}

// ---- Global API (exposed to onclick handlers) ----
window.app = {
    navigate(path) { navigate(path); },

    switchTab(tab) {
        state.tab = tab;
        if (tab !== 'pets' || getRoute() === '/') {
            navigate('/');
        }
        render();
        if (tab === 'map') setTimeout(() => initMap(), 50);
        if (tab === 'settings') setTimeout(() => bindSettingsPhotoUpload(), 50);
    },

    setSearch(val) {
        state.search = val;
        render();
    },

    toggleAuth() {
        _authMode = _authMode === 'login' ? 'register' : 'login';
        const confirmGroup = document.getElementById('confirm-group');
        const submitBtn = document.getElementById('auth-submit');
        const toggleText = document.getElementById('auth-toggle-text');
        const toggleLink = document.getElementById('auth-toggle-link');
        if (_authMode === 'register') {
            confirmGroup.style.display = 'block';
            submitBtn.textContent = 'Registrarse';
            toggleText.textContent = '¿Ya tienes cuenta?';
            toggleLink.textContent = ' Iniciar Sesión';
        } else {
            confirmGroup.style.display = 'none';
            submitBtn.textContent = 'Iniciar Sesión';
            toggleText.textContent = '¿No tienes cuenta?';
            toggleLink.textContent = ' Registrarse';
        }
    },

    async handleLogout() {
        confirm('Cerrar Sesión', '¿Estás seguro que deseas salir?', async () => {
            await auth.signOut();
            state.user = null;
            state.pets = [];
            state.petDetails = {};
            state.tab = 'pets';
            navigate('/');
            render();
            toast('Sesión cerrada');
        }, '🚪');
    },

    async deletePet(petId, name) {
        confirm('Eliminar Mascota', `¿Eliminar a ${name}? Esta acción no se puede deshacer.`, async () => {
            try {
                // Best-effort: delete photo from Storage
                const pet = state.pets.find(p => p.id === petId);
                if (pet?.photo_url && state.user?.id) {
                    try { await petPhotos.delete(state.user.id, petId); } catch (_) {}
                }
                await pets.delete(petId);
                toast('Mascota eliminada');
                await loadPets();
                state.tab = 'pets';
                navigate('/');
                render();
            } catch (err) { toast(err.message, 'error'); }
        }, '🗑️');
    },

    async deleteVaccine(petId, vacId, name) {
        confirm('Eliminar Vacuna', `¿Eliminar "${name}"?`, async () => {
            try {
                await vaccines.delete(vacId);
                toast('Vacuna eliminada');
                await loadPetDetails(petId);
                render();
            } catch (err) { toast(err.message, 'error'); }
        }, '💉');
    },

    async deleteAntiparasitic(petId, apId, name) {
        confirm('Eliminar Antiparasitario', `¿Eliminar "${name}"?`, async () => {
            try {
                await antiparasitics.delete(apId);
                toast('Antiparasitario eliminado');
                await loadPetDetails(petId);
                render();
            } catch (err) { toast(err.message, 'error'); }
        }, '🛡️');
    },

    async deleteMedical(petId, recId, name) {
        confirm('Eliminar Consulta', `¿Eliminar "${name}"?`, async () => {
            try {
                await medicalRecords.delete(recId);
                toast('Consulta eliminada');
                await loadPetDetails(petId);
                render();
            } catch (err) { toast(err.message, 'error'); }
        }, '🩺');
    },

    async deleteWeight(petId, wId) {
        confirm('Eliminar Registro', '¿Eliminar este registro de peso?', async () => {
            try {
                await weightEntries.delete(wId);
                toast('Registro eliminado');
                await loadPetDetails(petId);
                render();
            } catch (err) { toast(err.message, 'error'); }
        }, '⚖️');
    },

    toggleMedicalDetail(el) {
        const detail = el.querySelector('.medical-detail');
        if (detail) detail.style.display = detail.style.display === 'none' ? 'block' : 'none';
    },

    downloadQR() {
        const canvas = document.querySelector('#qr-canvas canvas');
        if (!canvas) return;
        const link = document.createElement('a');
        link.download = 'AnimalMbs-QR.png';
        link.href = canvas.toDataURL('image/png');
        link.click();
    },

    openQRLink() {
        if (state._qrLink) window.open(state._qrLink, '_blank');
    },

    async refreshData() {
        state.loading = true;
        render();
        await loadPets();
        state.loading = false;
        render();
    },

    imageLoaded(img) {
        const shell = img.closest('.remote-image-shell');
        if (shell) {
            shell.classList.remove('is-loading');
            shell.classList.add('is-loaded');
        }
    },

    imageErrored(img) {
        const shell = img.closest('.remote-image-shell');
        if (shell) {
            shell.classList.remove('is-loading');
            shell.classList.add('is-error');
        }
    }
};

// ---- Hash Change Listener ----
window.addEventListener('hashchange', () => render());
window.addEventListener('focus', async () => {
    if (!state.user || state.loading) return;
    await loadPets();
    render();
});
document.addEventListener('visibilitychange', async () => {
    if (document.hidden || !state.user || state.loading) return;
    await loadPets();
    render();
});

// ---- Init ----
(async function init() {
    // Check for public ficha first
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has('d')) {
        render();
        return;
    }

    // Check existing session
    const { data: { session } } = await auth.getSession();
    if (session?.user) {
        state.user = session.user;
        state.loading = true;
        render();
        await loadPets();
        state.loading = false;
        render();
    } else {
        render();
    }

    // Listen for auth changes
    auth.onAuthChange((event, session) => {
        if (event === 'SIGNED_IN' && session?.user) {
            state.user = session.user;
        } else if (event === 'SIGNED_OUT') {
            state.user = null;
            state.pets = [];
            state.petDetails = {};
        }
    });
})();
