import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const sourceDir = path.resolve(__dirname, '..');
const repoRoot = path.resolve(sourceDir, '..');
const distDir = path.join(sourceDir, 'dist');
const publicDir = path.join(sourceDir, 'public');
const outputDir = path.join(repoRoot, 'release_build', 'fastcat');
const versionFile = path.join(sourceDir, 'theme-version.json');
const defaultVersion = '1.2.4';

const normalizeVersion = value => String(value || '').trim().replace(/^v/, '');

const parseVersion = value => {
  const match = normalizeVersion(value).match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) return null;
  return {
    major: Number(match[1]),
    minor: Number(match[2]),
    patch: Number(match[3])
  };
};

const bumpPatchVersion = value => {
  const parsed = parseVersion(value) || parseVersion(defaultVersion);
  return `${parsed.major}.${parsed.minor}.${parsed.patch + 1}`;
};

const readThemeVersion = async () => {
  try {
    const raw = await fs.readFile(versionFile, 'utf8');
    const data = JSON.parse(raw);
    const version = normalizeVersion(data.version);
    return parseVersion(version) ? version : defaultVersion;
  } catch (_) {
    return defaultVersion;
  }
};

const writeThemeVersion = async value => {
  await fs.writeFile(versionFile, JSON.stringify({ version: value }, null, 2) + '\n', 'utf8');
};

const buildAssetTags = distIndexHtml => {
  const cssTags = [];
  const jsTags = [];

  for (const match of distIndexHtml.matchAll(/<link[^>]+rel="stylesheet"[^>]+href="([^"]+\.css(?:\?[^"]*)?)"[^>]*>/g)) {
    cssTags.push(match[1]);
  }

  for (const match of distIndexHtml.matchAll(/<script[^>]+defer="defer"[^>]+src="([^"]+\.js(?:\?[^"]*)?)"[^>]*><\/script>/g)) {
    jsTags.push(match[1]);
  }

  return { cssTags, jsTags };
};

const buildDashboardTemplate = ({ themeVersion, cssTags, jsTags }) => {
  const cssLinks = cssTags
    .map(href => `  <link rel="stylesheet" href="${href.split('?')[0]}?v={{ $version }}">`)
    .join('\n');

  const jsScripts = jsTags
    .map(src => `  <script defer src="${src.split('?')[0]}?v={{ $version }}"></script>`)
    .join('\n');

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <base href="/theme/fastcat/">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,minimum-scale=1,user-scalable=no">
  <meta http-equiv="X-UA-Compatible" content="ie=edge">
  <meta name="description" content="{{ $description }}">
  <link rel="icon" href="images/logo.png">
  <title>{{ $title }}</title>
  <script>
    window.FASTCAT_THEME_CONFIG = {
      PANEL_TYPE: @json($theme_config['panel_type'] ?? 'Xiao-V2board'),
      SITE_CONFIG: {
        siteName: @json($title),
        siteDescription: @json($description),
        showLogo: {{ in_array(strtolower((string) ($theme_config['show_logo'] ?? '1')), ['1', 'true', 'on', 'yes'], true) ? 'true' : 'false' }}
      },
      DEFAULT_CONFIG: {
        primaryColor: @json($theme_config['primary_color'] ?? '#4566AE'),
        enableLandingPage: {{ in_array(strtolower((string) ($theme_config['enable_landing_page'] ?? '1')), ['1', 'true', 'on', 'yes'], true) ? 'true' : 'false' }}
      }
    };
    window.EZ_LOADER = {
      configFileName: '/theme/fastcat/config.js',
      configTimeout: 3000,
      maxRetries: 2,
      configVersion: '${themeVersion}'
    };
  </script>
${cssLinks ? `${cssLinks}\n` : ''}  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow-x: hidden; }
    #app { width: 100%; height: 100%; }
    html.preloader-active, body.preloader-active { overflow: hidden !important; }
    @media (min-width: 769px) {
      * { scrollbar-width: none !important; -ms-overflow-style: none !important; }
      ::-webkit-scrollbar { display: none !important; width: 0 !important; height: 0 !important; }
    }
  </style>
${jsScripts}
</head>
<body>
  <div id="app"></div>
  {!! $theme_config['custom_html'] ?? '' !!}
</body>
</html>
`;
};

const configJson = themeVersion => ({
  name: 'fastcat',
  description: 'Fastcat CatBoard 兼容主题',
  version: themeVersion,
  images: '/theme/fastcat/images/background.jpg',
  configs: [
    {
      label: '面板类型',
      placeholder: '请选择后端面板类型',
      field_name: 'panel_type',
      field_type: 'select',
      select_options: {
        'Xiao-V2board': 'Xiao-V2board',
        V2board: '标准 V2Board',
        Xboard: 'Xboard'
      },
      default_value: 'V2board'
    },
    {
      label: '主题主色',
      placeholder: '例如 #4566AE',
      field_name: 'primary_color',
      field_type: 'input',
      default_value: '#4566AE'
    },
    {
      label: '显示标题 Logo',
      field_name: 'show_logo',
      field_type: 'select',
      select_options: {
        '1': '显示',
        '0': '隐藏'
      },
      default_value: '1'
    },
    {
      label: '启用落地页',
      field_name: 'enable_landing_page',
      field_type: 'select',
      select_options: {
        '1': '启用',
        '0': '关闭'
      },
      default_value: '1'
    },
    {
      label: '自定义页脚 HTML',
      placeholder: '可填写客服代码、统计代码等',
      field_name: 'custom_html',
      field_type: 'textarea',
      default_value: ''
    }
  ]
});

const copyDir = async (src, dest) => {
  await fs.mkdir(dest, { recursive: true });
  const entries = await fs.readdir(src, { withFileTypes: true });
  for (const entry of entries) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      await copyDir(from, to);
    } else if (entry.isFile()) {
      await fs.copyFile(from, to);
    }
  }
};

const removeIfExists = async target => {
  await fs.rm(target, { recursive: true, force: true });
};

const main = async () => {
  const themeVersion = await readThemeVersion();
  const zipPath = path.join(repoRoot, `fastcat-catboard-theme-${themeVersion}.zip`);

  await removeIfExists(outputDir);
  await fs.mkdir(outputDir, { recursive: true });

  const requiredFiles = [
    path.join(distDir, 'config.js'),
    path.join(distDir, 'landingpage.html'),
    path.join(publicDir, 'config.js'),
    path.join(publicDir, 'landingpage.html'),
    path.join(publicDir, 'images', 'logo.png'),
    path.join(publicDir, 'images', 'background.jpg')
  ];

  for (const file of requiredFiles) {
    await fs.access(file);
  }

  const distIndexHtml = await fs.readFile(path.join(distDir, 'index.html'), 'utf8');
  const { cssTags, jsTags } = buildAssetTags(distIndexHtml);
  const dashboardTemplate = buildDashboardTemplate({ themeVersion, cssTags, jsTags });

  await fs.copyFile(path.join(distDir, 'config.js'), path.join(outputDir, 'config.js'));
  await fs.copyFile(path.join(distDir, 'landingpage.html'), path.join(outputDir, 'landingpage.html'));
  await fs.writeFile(path.join(outputDir, 'config.json'), JSON.stringify(configJson(themeVersion), null, 2) + '\n', 'utf8');
  await fs.writeFile(path.join(outputDir, 'dashboard.blade.php'), dashboardTemplate, 'utf8');
  await copyDir(path.join(publicDir, 'images'), path.join(outputDir, 'images'));
  await copyDir(path.join(distDir, 'static'), path.join(outputDir, 'static'));

  await removeIfExists(zipPath);
  execFileSync('zip', ['-r', zipPath, 'fastcat'], {
    cwd: path.join(repoRoot, 'release_build'),
    stdio: 'inherit'
  });

  const nextVersion = bumpPatchVersion(themeVersion);
  await writeThemeVersion(nextVersion);

  const distIndexUpdated = distIndexHtml.replace(/configVersion:\s*'[^']*'/, `configVersion: '${themeVersion}'`);
  await fs.writeFile(path.join(distDir, 'index.html'), distIndexUpdated, 'utf8').catch(() => {});

  console.log(`Theme package built: ${zipPath}`);
  console.log(`Next version queued: ${nextVersion}`);
};

main().catch(error => {
  console.error(error);
  process.exit(1);
});
