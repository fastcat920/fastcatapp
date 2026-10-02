/// Shared by mobile/macOS and Windows WebViews. Do not maintain two CSS copies.
const crispThemeInstallerScript = r'''
    window.__fastcatApplyCustomerServiceTheme = function(theme){
      try {
        window.__fastcatCustomerServiceTheme = theme;
        document.documentElement.style.background = theme.background;
        document.documentElement.style.colorScheme = theme.isDark ? 'dark' : 'light';
        if (document.body) {
          document.body.style.background = theme.background;
          document.body.style.color = theme.foreground;
        }
        var style = document.getElementById('fastcat-customer-service-theme');
        if (!style) {
          style = document.createElement('style');
          style.id = 'fastcat-customer-service-theme';
          (document.head || document.documentElement).appendChild(style);
        }
        style.textContent = ''
          + 'html,body{background:' + theme.background + ' !important;color:' + theme.foreground + ' !important;color-scheme:' + (theme.isDark ? 'dark' : 'light') + ' !important;}'
          + '#loading{background:' + theme.background + ' !important;color:' + theme.foreground + ' !important;}'
          + '#spinner{border:2px solid rgba(148,163,184,0.35) !important;border-top-color:' + (theme.accent || '#2563eb') + ' !important;}'
          + 'iframe[src*="crisp"],.crisp-client,[class*="crisp"],[id*="crisp"]{width:100% !important;height:100% !important;max-width:none !important;max-height:none !important;position:fixed !important;top:0 !important;left:0 !important;margin:0 !important;padding:0 !important;border:none !important;border-radius:0 !important;background:' + theme.background + ' !important;color-scheme:' + (theme.isDark ? 'dark' : 'light') + ' !important;}';
        window.$crisp = window.$crisp || [];
        window.$crisp.push(["config", "locale", [window.__fastcatCustomerServiceCrispLocale || 'en']]);
        window.$crisp.push(["config", "color:mode", [theme.isDark ? "dark" : "light"]]);
        window.CRISP_RUNTIME_CONFIG = window.CRISP_RUNTIME_CONFIG || {};
        window.CRISP_RUNTIME_CONFIG.locale = window.__fastcatCustomerServiceCrispLocale || 'en';
      } catch (_) {}
    };
''';
