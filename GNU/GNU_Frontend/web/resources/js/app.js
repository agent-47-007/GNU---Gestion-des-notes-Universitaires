const sidebar = document.querySelector('.sidebar');
const scrim = document.querySelector('.scrim');
const menuToggle = document.querySelector('[data-menu-open]');

const setMenuState = (isOpen) => {
	sidebar?.classList.toggle('is-open', isOpen);
	scrim?.classList.toggle('is-visible', isOpen);
	menuToggle?.setAttribute('aria-expanded', String(isOpen));
};

document.querySelector('[data-menu-open]')?.addEventListener('click', () => setMenuState(true));
document.querySelectorAll('[data-menu-close]').forEach((element) => {
	element.addEventListener('click', () => setMenuState(false));
});

document.querySelectorAll('.nav-link').forEach((link) => {
	link.addEventListener('click', () => {
		document.querySelectorAll('.nav-link').forEach((item) => item.classList.remove('is-active'));
		link.classList.add('is-active');
		setMenuState(false);
	});
});

const passwordInput = document.querySelector('#password');
const passwordToggle = document.querySelector('[data-password-toggle]');
const loginForm = document.querySelector('#login-form');
const loginFeedback = document.querySelector('#login-feedback');

const getToken = () => window.localStorage.getItem('gnu_token');
const roleLabels = { ETUDIANT: 'Étudiant', ENSEIGNANT: 'Enseignant', AGENT: 'Agent' };
const userName = (user) => [user.prenom, user.nom].filter(Boolean).join(' ') || user.login || 'Utilisateur GNU';
const initials = (user) => userName(user).split(/\s+/).map((part) => part[0]).join('').slice(0, 2).toUpperCase();

const renderUser = (user) => {

	const name = userName(user);
	const role = roleLabels[user.role] || user.role || 'Utilisateur';
	const profile = user.profil?.matricule || user.profil?.eid || user.code_utilisateur || 'Profil général';
	const values = {
		'[data-user-name]': name,
		'[data-user-first-name]': user.prenom || name.split(' ')[0],
		'[data-user-greeting]': `Bonjour, ${user.prenom || name.split(' ')[0]}.`,
		'[data-user-role]': role,
		'[data-user-code]': user.code_utilisateur || user.login || '—',
		'[data-user-profile]': profile,
		'[data-user-status]': user.actif ? 'Actif' : 'Désactivé',
		'[data-user-login]': user.login ? `@${user.login}` : 'Compte GNU',
	};

	Object.entries(values).forEach(([selector, value]) => {
		document.querySelectorAll(selector).forEach((element) => { element.textContent = value; });
	});
	document.querySelectorAll('[data-user-initials]').forEach((element) => { element.textContent = initials(user); });
};

const loadCurrentUser = async () => {
	const token = getToken();
	if (!token) {
		return;
	}

	const response = await fetch('/api/v1/auth/me', { headers: { Accept: 'application/json', Authorization: `Bearer ${token}` } });
	if (!response.ok) {
		window.localStorage.removeItem('gnu_token');
		return;
	}

	const payload = await response.json();
	const user = payload.data || payload;
	renderUser(user);
	const requiredRole = document.body.dataset.requiredRole;
	const rolePaths = { ETUDIANT: '/etudiant', ENSEIGNANT: '/enseignant', AGENT: '/agent' };
	if (requiredRole && user.role !== requiredRole) {
		window.location.replace(rolePaths[user.role] || '/profil');
	}
};

loadCurrentUser().catch(() => {
	document.querySelectorAll('[data-profile-feedback]').forEach((element) => {
		element.textContent = 'Impossible de charger les données du profil.';
		element.hidden = false;
	});
});

document.querySelectorAll('[data-logout]').forEach((button) => {
	button.addEventListener('click', async () => {
		const token = getToken();
		if (token) {
			await fetch('/api/v1/auth/logout', { method: 'POST', headers: { Accept: 'application/json', Authorization: `Bearer ${token}` } });
		}
		window.localStorage.removeItem('gnu_token');
		window.location.assign('/connexion');
	});
});

document.querySelectorAll('.role-button').forEach((button) => {
	button.addEventListener('click', () => {
		document.querySelectorAll('.role-button').forEach((item) => item.classList.remove('is-selected'));
		button.classList.add('is-selected');
	});
});

const registryInputs = document.querySelectorAll('[data-registry-filter]');
const registryRows = document.querySelectorAll('[data-registry-row]');
const registryEmpty = document.querySelector('[data-registry-empty]');

const filterRegistry = () => {
	const values = [...registryInputs].map((input) => input.value.trim().toLowerCase());
	let visibleRows = 0;

	registryRows.forEach((row) => {
		const matches = values.every((value) => !value || row.textContent.toLowerCase().includes(value));
		row.hidden = !matches;
		visibleRows += matches ? 1 : 0;
	});

	if (registryEmpty) {
		registryEmpty.hidden = visibleRows > 0;
	}
};

registryInputs.forEach((input) => input.addEventListener('input', filterRegistry));

const showcaseFilters = document.querySelectorAll('[data-showcase-filter]');
const showcaseCards = document.querySelectorAll('[data-showcase-card]');

showcaseFilters.forEach((filter) => {
	filter.addEventListener('click', () => {
		showcaseFilters.forEach((item) => item.classList.remove('is-active'));
		filter.classList.add('is-active');
		const selectedChannel = filter.dataset.showcaseFilter;
		showcaseCards.forEach((card) => {
			card.hidden = selectedChannel !== 'all' && card.dataset.showcaseCard !== selectedChannel;
		});
	});
});

passwordToggle?.addEventListener('click', () => {
	const isPassword = passwordInput.type === 'password';
	passwordInput.type = isPassword ? 'text' : 'password';
	passwordToggle.textContent = isPassword ? 'Masquer' : 'Afficher';
});

loginForm?.addEventListener('submit', async (event) => {
	event.preventDefault();
	loginFeedback.hidden = true;
	loginFeedback.textContent = '';

	const submitButton = loginForm.querySelector('button[type="submit"]');
	submitButton.disabled = true;
	submitButton.textContent = 'Connexion en cours...';

	try {
		const response = await fetch('/api/v1/auth/login', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
			body: JSON.stringify({
				login: loginForm.login.value,
				password: loginForm.password.value,
				device_name: 'GNU Web',
			}),
		});

		if (!response.ok) {
			throw new Error(response.status === 401 ? 'Identifiant ou mot de passe incorrect.' : 'La connexion est momentanément indisponible.');
		}

		const data = await response.json();
		window.localStorage.setItem('gnu_token', data.token);
		const rolePaths = { ETUDIANT: '/etudiant', ENSEIGNANT: '/enseignant', AGENT: '/agent' };
		window.location.assign(rolePaths[data.utilisateur?.role] || '/');
	} catch (error) {
		loginFeedback.textContent = error.message;
		loginFeedback.hidden = false;
		submitButton.disabled = false;
		submitButton.textContent = 'Se connecter';
	}
});
