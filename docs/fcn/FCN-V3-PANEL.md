# FCN v3 面板接入

面板和订阅使用 `fcn-v3`。旧节点 `fcn-v1`、`fcn-v2` 和 `fastcat-v2` 使用各自现有的接入方式。FCN v3 的入口是 QUIC 上的 HTTP/3 CONNECT 和 CONNECT-UDP。

- Catboard 管理端选择「FCN v3」，填写域名、连接端口、服务端口、权限组和 TLS SNI。节点部署页选用可信 CA 证书在节点上的完整证书链及私钥文件路径。客户端验证 SNI 和证书链。
- CatNode 通过现有原生节点 API 同步账号和节点配置。账号 UUID 派生 FCN v3 专用的认证 ID 与密钥。下行和上行沿用现有 Xray dispatcher 按 UID 计量。删除或重置账号 UUID 时撤销已打开的流和 UDP 关联。
- 用户刷新加密订阅。能够识别 FCN v3 的核心发出 `fc_fcn3=1`，由面板下发账号权限组可见的 v3 节点。这是订阅格式兼容性标记，授权沿用普通账号 UUID。
- 部署需要放行服务端 UDP 端口。待 CatNode 原生部署包发布后，在面板设置 `FASTCAT_FCN_V3_NATIVE_BOOTSTRAP_URL`，节点编辑页即可生成一键部署命令。

初始接入使用 CA 验证和固定 64 KiB 写入，面板未开放实验性 ECH、填充和自适应写入选项。UDP 应用载荷上限为 1150 字节。CatNode 的 Xray Freedom 出口当前不会把应用侧 TCP 半关闭传给目标 TCP 套接字，依赖 FIN 的业务需要按实际出站验证。

Go 共享源码位于 `core/fcnv3`，CatNode 独立构建使用相同副本 `protocol/fcnv3`。本地传输集成测试可用 `cd core/fcnv3 && go test -race ./...`。
