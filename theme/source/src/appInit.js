/**
 * 应用初始化文件（在 config.js 加载完成后被动态导入）
 * 原先 src/main.js 中的全部内容均迁移至此
 */

// 定义 Vue 功能标志
window.__VUE_OPTIONS_API__ = true;
window.__VUE_PROD_DEVTOOLS__ = false;
window.__VUE_PROD_HYDRATION_MISMATCH_DETAILS__ = false;

import { createApp } from 'vue';
import App from './App.vue';
import router from './router';
import store from './store';
import i18n from './i18n';
import { MotionPlugin } from '@vueuse/motion';
import { useToast } from './composables/useToast';
// 导入页面标题设置功能
import initPageTitle from './utils/exposeConfig';
// 导入域名检查工具
import { handleUnauthorizedDomain } from './utils/domainChecker';
// 导入反调试工具
import { initAntiDebug } from './utils/antiDebug';
import { SECURITY_CONFIG } from './utils/baseConfig';

/**
 * 安全功能初始化
 * 包含域名检查和反调试功能
 * 可以在 baseConfig.js 中通过 SECURITY_CONFIG 配置项启用或禁用
 */

// 检查域名授权状态
// 如果域名未授权，将导致页面无法正常加载
// 注意：可以在 baseConfig.js 中设置 SECURITY_CONFIG.enableFrontendDomainCheck = false 来禁用此功能
if (!handleUnauthorizedDomain()) {
  // 未授权域名将在handleUnauthorizedDomain内部处理
  throw new Error('Unauthorized domain');
}

// 初始化反调试功能
// 注意：可以在 baseConfig.js 中设置 SECURITY_CONFIG.enableAntiDebugging = false 来禁用此功能
if (SECURITY_CONFIG.enableAntiDebugging) {
  initAntiDebug();
}

// 初始化异步流程
const initApp = async () => {
  try {
    // 设置页面标题
    initPageTitle();

    // 导入全局样式
    await import('./assets/styles/index.scss');

    // 创建应用实例
    const app = createApp(App);

    // 创建全局Toast实例
    const toast = useToast();

    // 提供全局Toast服务
    app.provide('$toast', toast);

    // 使用插件
    app.use(router)
       .use(store)
       .use(i18n)
       .use(MotionPlugin);

    // 挂载应用
    app.mount('#app');

    // 初始化用户信息
    store.dispatch('initUserInfo');
  } catch (error) {
    console.error('应用初始化失败:', error);
  }
};

// 开始初始化应用
initApp();

// 导出router实例到window对象，以便在i18n中访问
window.router = router; 