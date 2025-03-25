# Hysteria 2 一键安装脚本

一个简单易用的 Hysteria 2 安装脚本，专为 Ubuntu/Debian 系统设计。

## 系统要求

- Ubuntu 20.04/22.04 或 Debian 系统
- 一个域名（需要提前解析到服务器IP）
- Root 权限

## 快速开始

复制以下命令并运行：

```bash
curl -fsSL https://raw.githubusercontent.com/maow318/hysteria2-install/580759d76a8ed3f6c49140fb8cb817cc15ff4ca9/install.sh -o install.sh && sudo bash install.sh
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

- 链接：`/etc/hysteria/hy2_link.txt`
- 密码：`/etc/hysteria/password.txt`
- 备份：
  - 链接：`/root/hy2_link.txt`
  - 密码：`/root/hysteria_password.txt`

### 常用命令

查看链接：
```bash
cat /etc/hysteria/hy2_link.txt
```

查看密码：
```bash
cat /etc/hysteria/password.txt
```

查看服务状态：
```bash
systemctl status hysteria
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

## 功能特点

- ✨ 全自动安装配置
- 🔒 自动生成随机密码
- 🌐 自动申请和配置 SSL 证书
- ⚡ 智能系统优化
- 📝 自动保存所有配置

## 技术支持

如遇问题，请提交 Issue 或联系技术支持。

## 开源协议

MIT License
