# Hysteria 2 一键安装脚本

一个简单易用的 Hysteria 2 安装脚本，专为 Ubuntu 系统设计。

## 系统要求

- Ubuntu 20.04/22.04
- 一个域名（需要提前解析到服务器IP）
- Root 权限
- 至少 512MB 内存
- 至少 1GB 可用磁盘空间

## 快速开始

复制以下命令并运行：

```bash
curl -fsSL https://raw.githubusercontent.com/maow318/hysteria2-install/main/install.sh -o install.sh && sudo bash install.sh
```

## 安装步骤

1. **运行安装命令**
2. **输入您的域名**（例如：`hy2.example.com`）
3. **选择是否使用 Cloudflare**
   - 建议选择：`n`（不使用）
   - 如果选择 `y`，需要登录 Cloudflare 账号

## 安装完成后

脚本会自动显示：
- Hysteria 2 链接
- 随机生成的密码
- 所有配置文件位置

### 重要文件位置

- 链接：`/root/hy2_link.txt`
- 密码：`/root/hysteria_password.txt`

### 常用命令

查看链接：
```bash
cat /root/hy2_link.txt
```

查看密码：
```bash
cat /root/hysteria_password.txt
```

查看服务状态：
```bash
systemctl status hysteria
```

查看 WARP 状态：
```bash
warp-cli status
```

## 卸载方法

如需卸载，请运行：

```bash
curl -fsSL https://raw.githubusercontent.com/maow318/hysteria2-install/main/uninstall.sh -o uninstall.sh && sudo bash uninstall.sh
```

## 注意事项

1. **域名设置**
   - 确保域名已正确解析到服务器IP
   - 使用二级域名更好（例如：`hy2.example.com`）

2. **安全建议**
   - 及时保存生成的链接和密码
   - 定期备份配置文件
   - 不要泄露您的链接和密码

3. **故障排除**
   - 如果安装失败，检查：
     - 网络连接
     - 域名解析
     - 系统版本
   - 确保使用 Root 权限运行
   - 如果无法访问国际网络，运行 `warp-cli status` 检查是否已连接，如未连接，可执行 `warp-cli connect`

## 功能特点

- ✨ 全自动安装配置
- 🔒 自动生成随机密码
- 🌐 自动申请和配置 SSL 证书
- ⚡ 智能系统优化
- 📝 自动保存所有配置
- 🔄 支持一键卸载

## 技术支持

如遇问题，请提交 Issue 或联系技术支持。

## 开源协议

MIT License
