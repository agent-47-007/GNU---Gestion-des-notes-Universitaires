const TOKEN_KEY = 'gnu_token';

export const getToken = () => sessionStorage.getItem(TOKEN_KEY) || localStorage.getItem(TOKEN_KEY);
export const clearToken = () => {
    sessionStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(TOKEN_KEY);
};
export const saveToken = (token, remember = false) => {
    clearToken();
    (remember ? localStorage : sessionStorage).setItem(TOKEN_KEY, token);
};
export const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));
export const dataList = (payload) => Array.isArray(payload) ? payload : (payload?.data ?? []);
export const rolePath = (user) => ({ ETUDIANT: '/etudiant', ENSEIGNANT: '/enseignant', AGENT: '/agent' }[user?.role] || '/profil');

export async function api(path, options = {}) {
    const headers = { Accept: 'application/json', ...(getToken() ? { Authorization: `Bearer ${getToken()}` } : {}), ...options.headers };
    const body = options.body;
    if (body !== undefined && !(body instanceof FormData)) {
        headers['Content-Type'] = 'application/json';
    }
    const response = await fetch(path.startsWith('/api/') ? path : `/api/v1/${path.replace(/^\//, '')}`, {
        ...options,
        headers,
        ...(body !== undefined ? { body: body instanceof FormData || typeof body === 'string' ? body : JSON.stringify(body) } : {}),
    });
    if (response.status === 204) return null;
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
        if (response.status === 401 && !path.includes('auth/login')) {
            clearToken();
            window.location.replace('/connexion');
        }
        const errors = Object.values(payload.errors || {}).flat().join(' ');
        const error = new Error(errors || payload.message || (response.status === 429 ? 'Trop de tentatives. Réessayez dans quelques instants.' : 'Impossible de réaliser cette opération.'));
        error.status = response.status;
        error.errors = payload.errors || {};
        throw error;
    }
    return payload;
}

export function showFeedback(element, message, isError = false) {
    if (!element) return;
    element.textContent = message;
    element.hidden = !message;
    element.classList.toggle('is-error', isError);
    element.setAttribute('role', isError ? 'alert' : 'status');
}
