
# Hysteria 2 一键安装脚本

这是一个简单易用的 Hysteria 2 安装脚本，支持 Ubuntu 系统。

## 功能特点

- 🚀 一键安装，无需复杂配置
- 🔒 自动生成随机密码
- 🌐 支持自定义域名
- 🔐 自动配置 SSL 证书
- ⚡ 系统优化，提升性能
- 📝 自动保存配置信息

## 使用方法

### 1. 运行安装命令

```bash
sudo bash <(curl -sSL https://raw.githubusercontent.com/maow318/hysteria2-install/580759d76a8ed3f6c49140fb8cb817cc15ff4ca9/install.sh)
```

### 2. 按提示操作

- 输入您的域名（例如：`hy2.example.com`）
- 选择是否使用 Cloudflare（建议选择 `n`）

### 3. 安装完成

- 脚本会自动显示您的 Hysteria 2 链接
- 链接和密码会自动保存到以下位置：
  - 链接：`/etc/hysteria/hy2_link.txt`
  - 密码：`/etc/hysteria/password.txt`
  - 备份文件在 `/root` 目录下

## 查看信息

安装完成后，您可以：

1. 查看 Hysteria 2 链接：
```bash
cat /etc/hysteria/hy2_link.txt
```

2. 查看密码：
```bash
cat /etc/hysteria/password.txt
```

## 使用说明

1. 复制显示的 Hysteria 2 链接
2. 使用 Hysteria 2 客户端导入链接
3. 开始使用！

## 注意事项

- 请确保您的域名已经正确解析到服务器 IP
- 请保存好您的密码和链接
- 建议定期备份配置文件

## 常见问题

1. **安装失败怎么办？**
   - 检查网络连接
   - 确保使用 root 权限运行
   - 检查域名是否正确解析

2. **找不到链接怎么办？**
   - 运行 `cat /etc/hysteria/hy2_link.txt` 查看
   - 或查看备份文件 `/root/hy2_link.txt`

3. **忘记密码怎么办？**
   - 运行 `cat /etc/hysteria/password.txt` 查看
   - 或查看备份文件 `/root/hysteria_password.txt`

## 技术支持

如有问题，请提交 Issue 或联系技术支持。

## 许可证

MIT License
