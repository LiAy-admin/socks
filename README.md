# Socks 代理管理工具

一个用于 Ubuntu/Debian 系统的 Socks 代理管理工具，帮助中国大陆用户更好地访问开源社区。

## 功能特点

- 一键配置系统级代理
- 支持 HTTP/HTTPS 协议
- 自动配置 APT 软件包管理器代理
- 多站点连接测试
- 多源下载速度测试
- 配置持久化保存
- 支持一键卸载

## 快速开始

1. 克隆仓库：
```bash
git clone https://github.com/LiAy-admin/socks.git
cd socks
```

2. 运行安装脚本：
```bash
sudo bash install.sh
```

3. 使用代理：
```bash
socks  # 启动交互式菜单
# 或者使用命令行
proxy_on   # 启用代理
proxy_off  # 禁用代理
```

## 详细文档

请查看 [使用说明.md](使用说明.md) 获取详细信息。

## 系统要求

- 操作系统：Ubuntu/Debian
- 权限要求：需要 root 权限
- 依赖工具：curl、wget（脚本会自动安装）

## 目录结构

```
socks/
├── install.sh           # 安装脚本
├── 使用说明.md          # 详细使用说明
├── etc/                # 配置文件模板
│   ├── environment     # 环境变量配置
│   └── apt/
│       └── apt.conf.d/
│           └── proxy.conf  # APT代理配置
└── .bashrc             # Bash配置模板
```

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 联系方式

- GitHub Issues: [提交问题](https://github.com/LiAy-admin/socks/issues)
- Email: *****@**.com
