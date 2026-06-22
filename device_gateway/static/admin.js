const api = (path, opts = {}) => {
  const token = localStorage.getItem('admin_token');
  return fetch('/api/v1/admin' + path, {
    headers: { 'X-Admin-Token': token, 'Content-Type': 'application/json', ...opts.headers },
    ...opts,
  }).then(r => r.json());
};

const authEl = document.getElementById('auth');
const appEl = document.getElementById('app');
const authError = document.getElementById('auth-error');
const backToTopBtn = document.getElementById('back-to-top');

let allUsers = [];
let dashboardData = null;
let currentUserContext = null;

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

if (localStorage.getItem('admin_token')) {
  authEl.style.display = 'none';
  appEl.style.display = 'block';
  loadDashboard();
}

document.querySelectorAll('.nav-link').forEach(link => {
  link.addEventListener('click', (e) => {
    e.preventDefault();
    activateTab(link.dataset.tab);
  });
});

window.addEventListener('scroll', () => {
  backToTopBtn.classList.toggle('visible', window.scrollY > 420);
});

backToTopBtn.addEventListener('click', () => {
  window.scrollTo({ top: 0, behavior: 'smooth' });
});

function activateTab(tab) {
  document.querySelectorAll('.nav-link').forEach(l => l.classList.toggle('active', l.dataset.tab === tab));
  document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  document.getElementById('tab-' + tab).classList.add('active');
  if (tab === 'dashboard') loadDashboard();
  if (tab === 'users') loadUsers();
  if (tab === 'audit') loadAuditLogs();
}

async function loadDashboard() {
  const res = await api('/dashboard');
  if (!res.success) return;
  dashboardData = res.data;
  renderDashboard(dashboardData);
}

function renderDashboard(data) {
  const s = data.summary || {};
  const biz = data.business || {};
  const gateway = data.gateway || {};
  const bizLabel = { online: '在线', error: '异常', offline: '离线', unknown: '—' };
  const gatewayLabel = { running: '运行中', local: '本机运行' };

  document.querySelector('.stats').innerHTML = `
    ${statCard('users', '总用户', s.total_users ?? 0, '进入用户管理')}
    ${statCard('active-devices', '活跃设备', s.active_devices ?? 0, `${s.online_devices ?? 0} 台设备在线`)}
    ${statCard('revoked-devices', '已撤销设备', s.revoked_devices ?? 0, '')}
    ${statCard('policy', '设备策略', s.device_policy || '—', '')}
    ${statCard('gateway', '网关状态', gatewayLabel[gateway.status] || '运行中', '查看网关信息', 'ok')}
    ${statCard('business', '业务后端', bizLabel[biz.status] || '—', '查看业务后端', biz.status === 'online' ? 'ok' : 'warn')}
  `;

  document.querySelectorAll('.stat-card.clickable').forEach(card => {
    card.addEventListener('click', () => handleStatClick(card.dataset.detail));
  });

  renderActivity(data.activity || {});
  renderDistribution('region-panel', data.regions || []);
  renderDistribution('isp-panel', data.isps || []);
  renderDistribution('version-panel', data.versions || []);
}

function statCard(detail, label, value, sub, tone = '') {
  const clickable = ['users', 'gateway', 'business'].includes(detail);
  return `
    <button class="stat-card ${clickable ? 'clickable' : ''} ${tone}" data-detail="${detail}">
      <span class="label">${esc(label)}</span>
      <span class="value">${esc(String(value))}</span>
      ${sub ? `<span class="sub">${esc(sub)}</span>` : ''}
    </button>
  `;
}

function handleStatClick(detail) {
  if (detail === 'users') {
    activateTab('users');
    return;
  }
  if (detail === 'gateway') {
    showGatewayDetails();
  }
  if (detail === 'business') {
    showBusinessDetails();
  }
}

function showGatewayDetails() {
  const gateway = dashboardData?.gateway || {};
  const urls = gateway.gateway_urls || [];
  showDashboardDetails('网关信息', `
    <div class="detail-row"><span>监听地址</span><strong>${esc(gateway.listen_addr || '—')}</strong></div>
    <div class="detail-row"><span>API 前缀</span><strong>${esc(gateway.api_prefix || '—')}</strong></div>
    <div class="detail-row"><span>公开地址</span><strong>${esc(gateway.public_base_url || '未配置')}</strong></div>
    <div class="detail-list">${urls.length ? urls.map(u => `<div>${esc(u)}</div>`).join('') : '<div>暂无 OSS 网关 URL</div>'}</div>
  `);
}

function showBusinessDetails() {
  const business = dashboardData?.business || {};
  const items = business.backends || [];
  const rows = items.length ? items.map(item => `
    <div class="backend-item">
      <div>
        <strong>${esc(item.url || '—')}</strong>
        <span>${item.status_code ? 'HTTP ' + item.status_code : esc(item.error || '')}</span>
      </div>
      <span class="status-badge status-${item.status === 'online' ? 'active' : 'expired'}">${item.status === 'online' ? '在线' : item.status === 'error' ? '异常' : '离线'}</span>
    </div>
  `).join('') : '<div class="empty compact">暂无业务后端 URL</div>';
  showDashboardDetails('业务后端信息', rows);
}

function showDashboardDetails(title, body) {
  const panel = document.getElementById('dashboard-details');
  panel.innerHTML = `
    <div class="panel-header">
      <span>${esc(title)}</span>
      <button class="close-details" title="关闭">&times;</button>
    </div>
    <div class="details-body">${body}</div>
  `;
  panel.style.display = 'block';
  panel.querySelector('.close-details').addEventListener('click', () => {
    panel.style.display = 'none';
  });
  panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function renderActivity(activity) {
  const rows = [
    { name: '当前在线', count: activity.online_devices ?? 0 },
    { name: '24 小时活跃', count: activity.recent_devices ?? 0 },
    { name: '暂未活跃', count: activity.inactive_devices ?? 0 },
  ];
  document.getElementById('activity-panel').innerHTML = rows.map(item => `
    <div class="metric-row">
      <span>${esc(item.name)}</span>
      <strong>${item.count}</strong>
    </div>
  `).join('');
}

function renderDistribution(id, items) {
  const el = document.getElementById(id);
  if (!items.length) {
    el.innerHTML = '<div class="empty compact">暂无数据</div>';
    return;
  }
  el.innerHTML = items.slice(0, 10).map(item => `
    <div class="metric-row with-bar">
      <div class="metric-main">
        <span>${esc(item.name)}</span>
        <strong>${item.count} · ${formatPercent(item.percent)}</strong>
      </div>
      <div class="bar"><span style="width:${Math.max(2, Math.min(100, item.percent || 0))}%"></span></div>
    </div>
  `).join('');
}

async function loadUsers() {
  const res = await api('/users');
  if (!res.success) return;
  allUsers = res.data.users;
  renderUsers(filterUsers());
}

document.getElementById('user-search').addEventListener('input', () => {
  renderUsers(filterUsers());
});

document.querySelector('#users-table tbody').addEventListener('click', async (e) => {
  const deviceBtn = e.target.closest('[data-action="devices"]');
  const revokeBtn = e.target.closest('[data-action="revoke"]');
  const saveBtn = e.target.closest('[data-action="save-limit"]');
  const clearBtn = e.target.closest('[data-action="clear-limit"]');
  const closeBtn = e.target.closest('[data-action="close-devices"]');

  if (deviceBtn) {
    await openUserDevices(deviceBtn.dataset.userId);
  }
  if (revokeBtn) {
    await revokeDevice(revokeBtn.dataset.deviceId);
  }
  if (saveBtn) {
    await saveLimit();
  }
  if (clearBtn) {
    await clearLimit();
  }
  if (closeBtn) {
    closeDeviceRow();
  }
});

function filterUsers() {
  const q = document.getElementById('user-search').value.trim().toLowerCase();
  if (!q) return allUsers;
  return allUsers.filter(u =>
    (u.email || '').toLowerCase().includes(q) ||
    (u.id || '').toLowerCase().includes(q)
  );
}

function renderUsers(users) {
  const tbody = document.querySelector('#users-table tbody');
  currentUserContext = null;
  if (!users.length) {
    tbody.innerHTML = '<tr><td colspan="6" class="empty">暂无用户</td></tr>';
    return;
  }
  tbody.innerHTML = users.map(u => `
    <tr class="user-row" data-user-id="${escAttr(u.id)}">
      <td>${esc(u.email)}</td>
      <td>${esc(u.plan_name || '—')}</td>
      <td>${u.active_device_count ?? 0} / ${u.effective_device_limit ?? '∞'}</td>
      <td>${u.device_limit_override ? '<span class="accent">覆盖 ' + u.device_limit_override + '</span>' : (u.device_limit || '默认')}</td>
      <td>${timeAgo(u.last_synced_at)}</td>
      <td><button class="action" data-action="devices" data-user-id="${escAttr(u.id)}">设备</button></td>
    </tr>
  `).join('');
}

async function openUserDevices(userId) {
  const user = allUsers.find(u => u.id === userId);
  if (!user) return;
  currentUserContext = {
    userId,
    email: user.email || user.id,
    effLimit: user.effective_device_limit ?? 0,
    override: user.device_limit_override ?? 0,
  };

  const res = await api('/users/' + encodeURIComponent(userId) + '/devices');
  if (!res.success) return;
  closeDeviceRow();

  const row = document.querySelector(`tr.user-row[data-user-id="${cssEscape(userId)}"]`);
  if (!row) return;
  row.classList.add('selected');
  row.insertAdjacentHTML('afterend', devicePanelHTML(res.data.devices || [], currentUserContext));
  row.nextElementSibling.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function devicePanelHTML(devices, ctx) {
  const deviceRows = devices.length ? devices.map(d => `
    <tr>
      <td>${esc(d.device_name)}</td>
      <td>${esc(d.platform)}</td>
      <td>${esc(d.app_version || '—')}</td>
      <td><span class="status-badge status-${d.status}">${deviceStatus(d.status)}</span></td>
      <td>${timeAgo(d.last_seen_at)}</td>
      <td>${esc(d.last_ip || '—')}</td>
      <td>${esc(d.last_ip_region || '—')}</td>
      <td>${esc(d.last_ip_isp || '—')}</td>
      <td>${d.status === 'active' ? `<button class="action danger" data-action="revoke" data-device-id="${escAttr(d.id)}">撤销</button>` : '<span class="muted">—</span>'}</td>
    </tr>
  `).join('') : '<tr><td colspan="9" class="empty">暂无设备</td></tr>';

  return `
    <tr class="device-detail-row">
      <td colspan="6">
        <div class="panel inline-panel">
          <div class="panel-header">
            <span>${esc(ctx.email)} 的设备</span>
            <button class="close-panel" data-action="close-devices" title="关闭">&times;</button>
          </div>
          <div class="user-info">
            <span>用户 ID: ${esc(ctx.userId)}</span>
            <span>有效上限: ${ctx.effLimit || '∞'}</span>
          </div>
          <div class="table-wrap">
            <table class="devices-table">
              <thead>
                <tr>
                  <th>设备名称</th>
                  <th>平台</th>
                  <th>版本</th>
                  <th>状态</th>
                  <th>最后在线</th>
                  <th>IP</th>
                  <th>归属地</th>
                  <th>运营商</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody>${deviceRows}</tbody>
            </table>
          </div>
          <div class="limit-control">
            <label>设备上限覆盖：</label>
            <input type="number" class="limit-input" min="1" placeholder="留空恢复默认" value="${ctx.override || ''}">
            <button data-action="save-limit">保存</button>
            <button data-action="clear-limit" class="danger-soft">恢复默认</button>
          </div>
        </div>
      </td>
    </tr>
  `;
}

function closeDeviceRow() {
  document.querySelectorAll('.device-detail-row').forEach(row => row.remove());
  document.querySelectorAll('.user-row.selected').forEach(row => row.classList.remove('selected'));
}

async function revokeDevice(deviceId) {
  if (!currentUserContext || !confirm('确定撤销该设备？用户将立即下线。')) return;
  const res = await api('/users/' + encodeURIComponent(currentUserContext.userId) + '/devices/' + encodeURIComponent(deviceId), { method: 'DELETE' });
  if (res.success) {
    const userId = currentUserContext.userId;
    await loadUsers();
    await openUserDevices(userId);
  } else {
    alert('撤销失败: ' + (res.message || ''));
  }
}

async function saveLimit() {
  if (!currentUserContext) return;
  const input = document.querySelector('.device-detail-row .limit-input');
  const val = input.value.trim();
  const parsed = parseInt(val, 10);
  if (val && (Number.isNaN(parsed) || parsed < 1)) {
    alert('请输入有效的正整数');
    return;
  }
  const res = await api('/users/' + encodeURIComponent(currentUserContext.userId) + '/device-limit', {
    method: 'PATCH',
    body: JSON.stringify(val ? { device_limit_override: parsed } : { device_limit_override: null }),
  });
  if (res.success) {
    const userId = currentUserContext.userId;
    await loadUsers();
    await openUserDevices(userId);
  } else {
    alert('更新失败');
  }
}

async function clearLimit() {
  if (!currentUserContext) return;
  const res = await api('/users/' + encodeURIComponent(currentUserContext.userId) + '/device-limit', {
    method: 'PATCH',
    body: JSON.stringify({ device_limit_override: null }),
  });
  if (res.success) {
    const userId = currentUserContext.userId;
    await loadUsers();
    await openUserDevices(userId);
  }
}

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

function deviceStatus(status) {
  if (status === 'active') return '在线';
  if (status === 'revoked') return '已撤销';
  return '过期';
}

function esc(s) {
  if (!s) return '—';
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

function escAttr(s) {
  return esc(s).replace(/"/g, '&quot;');
}

function cssEscape(s) {
  if (window.CSS && CSS.escape) return CSS.escape(s);
  return String(s).replace(/["\\]/g, '\\$&');
}

function formatPercent(value) {
  return `${Number(value || 0).toFixed(1)}%`;
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
