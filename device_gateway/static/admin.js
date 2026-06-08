const api = (path, opts = {}) => {
  const token = localStorage.getItem('admin_token');
  return fetch('/api/v1/admin' + path, {
    headers: { 'X-Admin-Token': token, 'Content-Type': 'application/json', ...opts.headers },
    ...opts,
  }).then(r => r.json());
};

// ---- Auth ----
const authEl = document.getElementById('auth');
const appEl = document.getElementById('app');
const authError = document.getElementById('auth-error');

document.getElementById('auth-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const token = document.getElementById('token-input').value.trim();
  if (!token) return;
  const res = await api('/users', { headers: { 'X-Admin-Token': token } });
  if (res.code === 'ADMIN_FORBIDDEN') {
    authError.textContent = 'Token 无效';
    return;
  }
  localStorage.setItem('admin_token', token);
  authEl.style.display = 'none';
  appEl.style.display = 'block';
  loadDashboard();
});

document.getElementById('logout-btn').addEventListener('click', () => {
  localStorage.removeItem('admin_token');
  authEl.style.display = 'block';
  appEl.style.display = 'none';
  document.getElementById('token-input').value = '';
});

// Auto-login
if (localStorage.getItem('admin_token')) {
  authEl.style.display = 'none';
  appEl.style.display = 'block';
  loadDashboard();
}

// ---- Navigation ----
document.querySelectorAll('.nav-link').forEach(link => {
  link.addEventListener('click', (e) => {
    e.preventDefault();
    document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
    link.classList.add('active');
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    const tab = link.dataset.tab;
    document.getElementById('tab-' + tab).classList.add('active');
    if (tab === 'dashboard') loadDashboard();
    if (tab === 'users') loadUsers();
    if (tab === 'audit') loadAuditLogs();
  });
});

// ---- Dashboard ----
async function loadDashboard() {
  const res = await api('/users');
  if (!res.success) return;
  const users = res.data.users;
  const totalDevices = users.reduce((s, u) => s + (u.active_device_count || 0), 0);
  const revokedRes = await api('/audit-logs?limit=500');
  const revoked = revokedRes.success
    ? revokedRes.data.audit_logs.filter(l => l.action === 'device.revoked').length
    : 0;

  // Check business backend health by probing the login endpoint (expects 4xx not 5xx/network error)
  let bizStatus = 'unknown';
  try {
    const bizRes = await fetch('/api/v1/passport/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
      signal: AbortSignal.timeout(5000),
    });
    bizStatus = bizRes.ok || bizRes.status === 422 ? 'online' : 'error';
  } catch {
    bizStatus = 'offline';
  }

  const bizLabel = { online: '在线', error: '异常', offline: '离线', unknown: '—' };
  const bizColor = { online: '#2e7d32', error: '#e65100', offline: '#c62828', unknown: '#86868b' };

  document.querySelector('.stats').innerHTML = `
    <div class="stat-card"><div class="label">总用户</div><div class="value">${users.length}</div></div>
    <div class="stat-card"><div class="label">活跃设备</div><div class="value">${totalDevices}</div><div class="sub">${users.filter(u => u.active_device_count > 0).length} 位用户在线</div></div>
    <div class="stat-card"><div class="label">已撤销设备</div><div class="value">${revoked}</div></div>
    <div class="stat-card"><div class="label">设备策略</div><div class="value" style="font-size:18px">${users.length > 0 ? 'kick_oldest' : '—'}</div></div>
    <div class="stat-card"><div class="label">网关状态</div><div class="value" style="font-size:18px;color:#2e7d32">运行中</div></div>
    <div class="stat-card"><div class="label">业务后端</div><div class="value" style="font-size:18px;color:${bizColor[bizStatus]}">${bizLabel[bizStatus]}</div><div class="sub" id="biz-url"></div></div>
  `;
}

// ---- Users ----
let allUsers = [];
async function loadUsers() {
  const res = await api('/users');
  if (!res.success) return;
  allUsers = res.data.users;
  renderUsers(allUsers);
}

document.getElementById('user-search').addEventListener('input', (e) => {
  const q = e.target.value.toLowerCase();
  renderUsers(allUsers.filter(u =>
    (u.email || '').toLowerCase().includes(q) ||
    (u.id || '').toLowerCase().includes(q)
  ));
});

function renderUsers(users) {
  const tbody = document.querySelector('#users-table tbody');
  if (!users.length) {
    tbody.innerHTML = '<tr><td colspan="6" class="empty">暂无用户</td></tr>';
    return;
  }
  tbody.innerHTML = users.map(u => `
    <tr>
      <td>${esc(u.email)}</td>
      <td>${esc(u.plan_name || '—')}</td>
      <td>${u.active_device_count ?? 0} / ${u.effective_device_limit ?? '∞'}</td>
      <td>${u.device_limit_override ? '<span style="color:#0071e3">覆盖 ' + u.device_limit_override + '</span>' : (u.device_limit || '默认')}</td>
      <td>${timeAgo(u.last_synced_at)}</td>
      <td><button class="action" onclick="openUserDevices('${u.id}','${esc(u.email)}',${u.effective_device_limit ?? 0},${u.device_limit_override ?? 0})">设备</button></td>
    </tr>
  `).join('');
}

// ---- User Devices Panel ----
let currentUserId = '';
async function openUserDevices(userId, email, effLimit, override) {
  currentUserId = userId;
  const res = await api('/users/' + encodeURIComponent(userId) + '/devices');
  if (!res.success) return;

  const panel = document.getElementById('user-devices');
  document.getElementById('device-panel-title').textContent = email + ' 的设备';
  document.querySelector('#user-devices .user-info').innerHTML =
    `<span>用户 ID: ${userId}</span><span>有效上限: ${effLimit || '∞'}</span>`;

  document.getElementById('limit-input').value = override || '';

  const tbody = document.querySelector('#devices-table tbody');
  const devices = res.data.devices || [];
  if (!devices.length) {
    tbody.innerHTML = '<tr><td colspan="7" class="empty">暂无设备</td></tr>';
  } else {
    tbody.innerHTML = devices.map(d => `
      <tr>
        <td>${esc(d.device_name)}</td>
        <td>${esc(d.platform)}</td>
        <td>${esc(d.app_version || '—')}</td>
        <td><span class="status-badge status-${d.status}">${d.status === 'active' ? '在线' : d.status === 'revoked' ? '已撤销' : '过期'}</span></td>
        <td>${timeAgo(d.last_seen_at)}</td>
        <td>${esc(d.last_ip || '—')}</td>
        <td>${d.status === 'active' ? '<button class="action danger" onclick="revokeDevice(\'' + d.id + '\')">撤销</button>' : '<span style="color:#86868b">—</span>'}</td>
      </tr>
    `).join('');
  }
  panel.style.display = 'block';
  panel.scrollIntoView({ behavior: 'smooth' });
}

document.querySelector('.close-panel').addEventListener('click', () => {
  document.getElementById('user-devices').style.display = 'none';
});

async function revokeDevice(deviceId) {
  if (!confirm('确定撤销该设备？用户将立即下线。')) return;
  const res = await api('/users/' + encodeURIComponent(currentUserId) + '/devices/' + deviceId, { method: 'DELETE' });
  if (res.success) {
    openUserDevices(currentUserId, document.getElementById('device-panel-title').textContent.replace(' 的设备', ''));
  } else {
    alert('撤销失败: ' + (res.message || ''));
  }
}

document.getElementById('save-limit').addEventListener('click', async () => {
  const val = document.getElementById('limit-input').value.trim();
  const body = val ? { device_limit_override: parseInt(val) } : { device_limit_override: null };
  if (val && (isNaN(body.device_limit_override) || body.device_limit_override < 1)) {
    alert('请输入有效的正整数');
    return;
  }
  const res = await api('/users/' + encodeURIComponent(currentUserId) + '/device-limit', {
    method: 'PATCH',
    body: JSON.stringify(val ? { device_limit_override: parseInt(val) } : { device_limit_override: null }),
  });
  if (res.success) {
    alert('已更新');
    loadUsers();
    document.getElementById('device-panel-title').textContent.replace(' 的设备', '');
    openUserDevices(currentUserId, document.getElementById('device-panel-title').textContent.replace(' 的设备', ''), res.data.user.effective_device_limit, res.data.user.device_limit_override);
  } else {
    alert('更新失败');
  }
});

document.getElementById('clear-limit').addEventListener('click', async () => {
  const res = await api('/users/' + encodeURIComponent(currentUserId) + '/device-limit', {
    method: 'PATCH',
    body: JSON.stringify({ device_limit_override: null }),
  });
  if (res.success) {
    document.getElementById('limit-input').value = '';
    alert('已恢复默认');
    loadUsers();
  }
});

// ---- Audit Logs ----
async function loadAuditLogs() {
  const res = await api('/audit-logs?limit=100');
  if (!res.success) return;
  const logs = res.data.audit_logs || [];
  const tbody = document.querySelector('#audit-table tbody');
  if (!logs.length) {
    tbody.innerHTML = '<tr><td colspan="5" class="empty">暂无日志</td></tr>';
    return;
  }
  tbody.innerHTML = logs.map(l => `
    <tr>
      <td>${timeAgo(l.created_at)}</td>
      <td>${esc(l.action)}</td>
      <td>${esc(l.user_id || '—')}</td>
      <td>${esc(l.device_id || '—')}</td>
      <td>${esc(l.ip || '—')}</td>
    </tr>
  `).join('');
}

// ---- Helpers ----
function esc(s) {
  if (!s) return '—';
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

function timeAgo(ts) {
  if (!ts) return '—';
  const diff = (Date.now() - new Date(ts).getTime()) / 1000;
  if (diff < 60) return '刚刚';
  if (diff < 3600) return Math.floor(diff / 60) + ' 分钟前';
  if (diff < 86400) return Math.floor(diff / 3600) + ' 小时前';
  if (diff < 2592000) return Math.floor(diff / 86400) + ' 天前';
  return ts.slice(0, 10);
}
