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

const PAGE_SIZE = 30;
let allUsers = [];
let userState = {
  page: 1,
  pageSize: PAGE_SIZE,
  q: '',
  deviceStatus: 'all',
  limitMode: 'all',
  sort: 'updated_at',
  order: 'desc',
  pagination: null,
};
let auditState = {
  page: 1,
  pageSize: PAGE_SIZE,
  pagination: null,
};
let serviceHealthData = null;
let statisticsData = null;
let healthRefreshTimer = null;
let healthLoading = false;
let currentUserContext = null;
let userSearchTimer = null;

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
  activateTab('dashboard');
});

document.getElementById('logout-btn').addEventListener('click', () => {
  localStorage.removeItem('admin_token');
  stopHealthAutoRefresh();
  authEl.style.display = 'block';
  appEl.style.display = 'none';
  document.getElementById('token-input').value = '';
});

if (localStorage.getItem('admin_token')) {
  authEl.style.display = 'none';
  appEl.style.display = 'block';
  activateTab('dashboard');
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
  if (tab === 'dashboard') {
    loadServiceHealth();
    startHealthAutoRefresh();
  } else {
    stopHealthAutoRefresh();
  }
  if (tab === 'statistics') loadStatistics();
  if (tab === 'users') loadUsers();
  if (tab === 'audit') loadAuditLogs();
}

document.getElementById('health-refresh').addEventListener('click', () => loadServiceHealth(true));

async function loadServiceHealth(manual = false) {
  if (healthLoading) return;
  healthLoading = true;
  const button = document.getElementById('health-refresh');
  button.disabled = true;
  button.textContent = manual ? '↻ 检测中…' : '↻ 刷新状态';
  try {
    const res = await api('/service-health');
    if (!res.success) return;
    serviceHealthData = res.data;
    renderServiceHealth(serviceHealthData);
  } catch (error) {
    const warning = document.getElementById('health-warning');
    warning.textContent = `状态检测请求失败：${error?.message || '无法连接设备管理后端'}`;
    warning.style.display = 'block';
  } finally {
    healthLoading = false;
    button.disabled = false;
    button.textContent = '↻ 刷新状态';
  }
}

function startHealthAutoRefresh() {
  stopHealthAutoRefresh();
  healthRefreshTimer = window.setInterval(() => loadServiceHealth(), 30000);
}

function stopHealthAutoRefresh() {
  if (healthRefreshTimer) window.clearInterval(healthRefreshTimer);
  healthRefreshTimer = null;
}

function renderServiceHealth(data) {
  const summary = data.summary || {};
  const oss = summary.oss || {};
  const gateways = summary.gateways || {};
  const business = summary.business || {};
  document.getElementById('health-summary').innerHTML = `
    ${healthSummaryCard('OSS 配置源', oss, '下载、解密及内容校验')}
    ${healthSummaryCard('网关 API', gateways, '网关健康检查')}
    ${healthSummaryCard('业务 API', business, '只读业务接口探测')}
  `;

  renderHealthItems('oss-health-panel', data.oss?.items || [], 'oss');
  renderHealthItems('gateway-health-panel', data.gateways?.items || [], 'gateway');
  renderHealthItems('business-health-panel', data.business?.items || [], 'business');

  const warning = document.getElementById('health-warning');
  if (data.gateways?.public_base_mismatch) {
    warning.innerHTML = `配置的公开地址 <strong>${esc(data.gateways.public_base_url)}</strong> 与当前访问地址 <strong>${esc(data.gateways.request_base_url)}</strong> 不一致，请确认反向代理或 DG_PUBLIC_BASE_URL 配置。`;
    warning.style.display = 'block';
  } else {
    warning.style.display = 'none';
  }
  document.getElementById('health-checked-at').textContent = `最后检测：${formatDateTime(data.checked_at)}`;
}

function healthSummaryCard(label, summary, sub) {
  const healthy = summary.healthy ?? 0;
  const total = summary.total ?? 0;
  const tone = total > 0 && healthy === total ? 'ok' : 'warn';
  return `
    <div class="stat-card ${tone}">
      <span class="label">${esc(label)}</span>
      <span class="value">${healthy} / ${total}</span>
      <span class="sub">${esc(sub)}</span>
    </div>
  `;
}

function renderHealthItems(id, items, kind) {
  const el = document.getElementById(id);
  if (!items.length) {
    el.innerHTML = '<div class="empty compact">暂无配置</div>';
    return;
  }
  el.innerHTML = items.map(item => healthItemHTML(item, kind)).join('');
}

function healthItemHTML(item, kind) {
  const status = healthStatus(item.status);
  const badges = [];
  if (item.active) badges.push('<span class="health-badge primary">当前使用</span>');
  if (item.matches_current) badges.push('<span class="health-badge current">内容与当前一致</span>');
  badges.push(`<span class="health-badge">${esc(roleLabel(item.role))}</span>`);
  const meta = [];
  if (item.latency_ms > 0) meta.push(`${item.latency_ms} ms`);
  if (item.status_code) meta.push(`HTTP ${item.status_code}`);
  if (item.config_version) meta.push(`配置版本 ${item.config_version}`);
  if (kind === 'oss' && (item.business_count || item.gateway_count)) {
    meta.push(`业务 API ${item.business_count || 0} · 网关 API ${item.gateway_count || 0}`);
  }
  if (kind === 'business' && item.failure_count) meta.push(`连续失败 ${item.failure_count}`);
  if (kind === 'business' && item.recovery_success_count) {
    meta.push(`恢复 ${item.recovery_success_count}/${item.recovery_required || 0}`);
  }
  if (item.circuit_remaining_seconds) meta.push(`熔断剩余 ${item.circuit_remaining_seconds} 秒`);
  const error = item.error || item.failure_reason || '';
  return `
    <div class="health-row">
      <span class="health-dot ${status.tone}"></span>
      <div class="health-main">
        <div class="health-title-line">
          <strong>${esc(item.name || endpointLabel(kind, item.index))}</strong>
          <div class="health-badges">${badges.join('')}</div>
        </div>
        <div class="health-address">${esc(item.address || '—')}</div>
        <div class="health-meta">${meta.map(value => `<span>${esc(value)}</span>`).join('')}</div>
        ${error ? `<div class="health-error">${esc(error)}</div>` : ''}
      </div>
      <span class="health-status ${status.tone}">${esc(status.label)}</span>
    </div>
  `;
}

function healthStatus(status) {
  const values = {
    healthy: ['正常', 'good'], recovering: ['恢复中', 'warning'], circuit_open: ['熔断', 'bad'],
    timeout: ['超时', 'bad'], service_error: ['服务异常', 'bad'], unavailable: ['不可用', 'bad'],
    unreachable: ['无法连接', 'bad'], http_error: ['HTTP 异常', 'bad'], decrypt_error: ['解密失败', 'bad'],
    invalid_config: ['配置无效', 'bad'], invalid_response: ['响应无效', 'bad'], read_error: ['读取失败', 'bad'],
    invalid_address: ['地址无效', 'bad'], missing: ['未生成', 'muted'], not_configured: ['未配置', 'muted'],
  };
  const value = values[status] || ['未知', 'muted'];
  return { label: value[0], tone: value[1] };
}

function roleLabel(role) {
  return { primary: '主线路', backup: '备用线路', emergency: '紧急备用', cache: '本地缓存' }[role] || role || '未分类';
}

function endpointLabel(kind, index) {
  return `${kind === 'gateway' ? 'gateway' : kind === 'business' ? 'business' : 'source'}_${index || 0}`;
}

async function loadStatistics() {
  const res = await api('/statistics');
  if (!res.success) return;
  statisticsData = res.data;
  renderStatistics(statisticsData);
}

function renderStatistics(data) {
  const s = data.summary || {};
  document.getElementById('statistics-summary').innerHTML = `
    ${statCard('users', '总用户', s.total_users ?? 0, '进入用户管理')}
    ${statCard('', '设备总数', s.total_devices ?? 0, '')}
    ${statCard('', '活跃设备', s.active_devices ?? 0, `${s.online_devices ?? 0} 台设备在线`)}
    ${statCard('', '已撤销设备', s.revoked_devices ?? 0, '')}
    ${statCard('', '设备策略', s.device_policy || '—', '')}
  `;
  document.querySelectorAll('#statistics-summary .stat-card.clickable').forEach(card => {
    card.addEventListener('click', () => activateTab('users'));
  });
  renderActivity(data.activity || {});
  renderDistribution('region-panel', data.regions || []);
  renderDistribution('isp-panel', data.isps || []);
  renderDistribution('version-panel', data.versions || []);
}

function statCard(detail, label, value, sub, tone = '') {
  const clickable = detail === 'users';
  return `
    <button class="stat-card ${clickable ? 'clickable' : ''} ${tone}" data-detail="${detail}">
      <span class="label">${esc(label)}</span>
      <span class="value">${esc(String(value))}</span>
      ${sub ? `<span class="sub">${esc(sub)}</span>` : ''}
    </button>
  `;
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
  closeDeviceRow();
  const params = new URLSearchParams({
    page: String(userState.page),
    page_size: String(userState.pageSize),
    sort: userState.sort,
    order: userState.order,
  });
  if (userState.q) params.set('q', userState.q);
  if (userState.deviceStatus !== 'all') params.set('device_status', userState.deviceStatus);
  if (userState.limitMode !== 'all') params.set('limit_mode', userState.limitMode);

  const res = await api('/users?' + params.toString());
  if (!res.success) return;
  allUsers = res.data.users || [];
  userState.pagination = res.data.pagination || null;
  renderUsers(allUsers);
  renderPagination('users-pagination', userState.pagination, async (page) => {
    userState.page = page;
    await loadUsers();
  });
}

document.getElementById('user-search').addEventListener('input', () => {
  clearTimeout(userSearchTimer);
  userSearchTimer = setTimeout(() => {
    userState.q = document.getElementById('user-search').value.trim();
    userState.page = 1;
    loadUsers();
  }, 250);
});

['user-device-status', 'user-limit-mode', 'user-sort', 'user-order'].forEach(id => {
  document.getElementById(id).addEventListener('change', () => {
    userState.deviceStatus = document.getElementById('user-device-status').value;
    userState.limitMode = document.getElementById('user-limit-mode').value;
    userState.sort = document.getElementById('user-sort').value;
    userState.order = document.getElementById('user-order').value;
    userState.page = 1;
    loadUsers();
  });
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
  const params = new URLSearchParams({
    page: String(auditState.page),
    page_size: String(auditState.pageSize),
  });
  const res = await api('/audit-logs?' + params.toString());
  if (!res.success) return;
  const logs = res.data.audit_logs || [];
  auditState.pagination = res.data.pagination || null;
  const tbody = document.querySelector('#audit-table tbody');
  if (!logs.length) {
    tbody.innerHTML = '<tr><td colspan="5" class="empty">暂无日志</td></tr>';
    renderPagination('audit-pagination', auditState.pagination, async (page) => {
      auditState.page = page;
      await loadAuditLogs();
    });
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
  renderPagination('audit-pagination', auditState.pagination, async (page) => {
    auditState.page = page;
    await loadAuditLogs();
  });
}

function renderPagination(id, pagination, onPageChange) {
  const el = document.getElementById(id);
  if (!el) return;
  const page = pagination?.page ?? 1;
  const totalPages = pagination?.total_pages ?? 0;
  const total = pagination?.total ?? 0;
  const hasPrev = Boolean(pagination?.has_prev);
  const hasNext = Boolean(pagination?.has_next);
  el.innerHTML = `
    <button data-page="${page - 1}" ${hasPrev ? '' : 'disabled'}>上一页</button>
    <span class="page-info">第 ${totalPages ? page : 0} / ${totalPages} 页 · 共 ${total} 条</span>
    <button data-page="${page + 1}" ${hasNext ? '' : 'disabled'}>下一页</button>
  `;
  el.querySelectorAll('button:not(:disabled)').forEach(btn => {
    btn.addEventListener('click', () => onPageChange(Number(btn.dataset.page)));
  });
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

function formatDateTime(ts) {
  if (!ts) return '—';
  const value = new Date(ts);
  if (Number.isNaN(value.getTime())) return ts;
  return value.toLocaleString('zh-CN', { hour12: false });
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
