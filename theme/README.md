# FastCat Catboard Theme

这个目录是 FastCat 网页端（Catboard）主题源码，和根目录的 Flutter 客户端共同维护。

## 修改入口

- `source/src/views/invite/Invite.vue`：网页邀请页
- `source/src/views/`：网页各功能页面
- `source/src/assets/styles/`：共享视觉令牌、响应式规则和组件样式
- `source/public/config.js`：主题默认配置

移动端客户端的对应功能仍在根目录 `lib/`。同一项功能跨端变更时，应在同一个 Git 提交中同时修改 Flutter 页面与本目录的 Vue 页面。

## 本地构建

```bash
cd theme/source
npm ci
npm run build:theme
```

构建产物是 `theme/fastcat-catboard-theme-<版本>.zip`。它的根目录为 `fastcat/`，可直接在 Catboard 主题管理中上传；也可解压到 Catboard 的 `public/theme/fastcat/`。

不要提交 `node_modules`、`dist`、`release_build` 或生成的 ZIP 包。
