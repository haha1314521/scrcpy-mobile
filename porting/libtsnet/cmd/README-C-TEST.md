# C Test Program for libtsnet-forwarder

这是一个用于测试 libtsnet-forwarder C 静态库连接功能的测试程序。

## 功能特性

- ✅ 测试 Tailscale 网络连接
- ✅ 显示连接状态和详细信息
- ✅ 获取并打印 MagicDNS 和 IP 地址
- ✅ 彩色输出和友好的用户界面
- ✅ 自动等待连接完成
- ✅ 错误处理和超时机制

## 构建和运行

### 快速开始

```bash
# 1. 构建 C 静态库和测试程序
make build-c-test

# 2. 运行测试程序（需要 Tailscale AuthKey）
TS_AUTHKEY="your-tailscale-auth-key" make run-c-test
```

### 手动运行

```bash
# 构建
make build-c-test

# 运行（基本用法）
./build/c-test tskey-auth-xxxxxx

# 运行（指定主机名和状态目录）
./build/c-test tskey-auth-xxxxxx my-hostname /tmp/tsnet-test
```

## 命令行参数

```
./build/c-test <auth-key> [hostname] [state-dir]
```

- `auth-key`: Tailscale 认证密钥（必需）
- `hostname`: 设备主机名（可选，默认：tsnet-c-test）
- `state-dir`: 状态存储目录（可选，默认：/tmp/tsnet-c-test）

## 示例输出

```
========================================
  libtsnet-forwarder C Test Program
========================================
[INFO] Starting Tailscale connection test...
   Auth Key: tskey-****
   Hostname: my-device
   State Dir: /tmp/tsnet-test

[STEP] Setting Tailscale authentication key...
[SUCCESS] Authentication key set successfully
[STEP] Setting hostname...
[SUCCESS] Hostname set successfully
[STEP] Setting state directory...
[SUCCESS] State directory set successfully
[STEP] Current configuration:
   Hostname: my-device
   State Dir: /tmp/tsnet-test
[STEP] Connecting to Tailscale network...
[STEP] Waiting for connection to complete...
[SUCCESS] Connected to Tailscale network!

🎉 Connection Information:
   📍 Hostname:  my-device
   🌐 MagicDNS:  my-device.tail-scale.ts.net
   🔗 IPv4:      100.78.206.85
   🔗 IPv6:      fd7a:115c:a1e0::1234

[SUCCESS] TSNet server is running
Current Tailscale IP: 100.78.206.85
[STEP] Cleaning up...
[SUCCESS] Cleaned up 0 connections

========================================
  Test completed successfully!
========================================
```

## 测试的功能

### 1. 配置设置
- 设置 Tailscale 认证密钥
- 设置设备主机名
- 设置状态存储目录

### 2. 连接测试
- 异步连接到 Tailscale 网络
- 监控连接状态
- 处理连接超时（60秒）

### 3. 信息获取
- 获取分配的主机名
- 获取 MagicDNS 地址
- 获取 IPv4 和 IPv6 地址
- 显示当前连接状态

### 4. 资源清理
- 自动清理连接
- 释放分配的内存

## API 函数测试

程序测试以下 C API 函数：

### 配置函数
- `update_tsnet_auth_key()` - 设置认证密钥
- `tsnet_update_hostname()` - 设置主机名
- `tsnet_update_state_dir()` - 设置状态目录

### 连接函数
- `tsnet_connect_async()` - 异步连接
- `tsnet_get_connect_status()` - 获取连接状态

### 信息获取函数
- `tsnet_get_last_hostname()` - 获取主机名
- `tsnet_get_last_magic_dns()` - 获取 MagicDNS
- `tsnet_get_last_ipv4()` - 获取 IPv4
- `tsnet_get_last_ipv6()` - 获取 IPv6
- `tsnet_get_last_error()` - 获取错误信息

### 状态检查函数
- `tsnet_is_started()` - 检查服务状态
- `tsnet_get_tailscale_ips()` - 获取 IP 地址
- `tsnet_get_hostname()` - 获取当前主机名
- `tsnet_get_state_dir()` - 获取状态目录

### 清理函数
- `tsnet_cleanup()` - 清理资源

## 故障排除

### 常见错误

1. **认证失败**
   - 检查 AuthKey 是否有效
   - 确保 AuthKey 有正确的权限

2. **连接超时**
   - 检查网络连接
   - 确保防火墙允许 Tailscale 流量

3. **编译错误**
   - 确保已安装 gcc
   - 检查头文件路径是否正确

### 调试技巧

1. **查看详细日志**
   ```bash
   # 运行时会显示详细的连接过程
   ./build/c-test your-auth-key
   ```

2. **检查状态目录**
   ```bash
   # 检查状态文件
   ls -la /tmp/tsnet-c-test/
   ```

3. **手动清理**
   ```bash
   # 清理旧的状态文件
   rm -rf /tmp/tsnet-c-test/
   ```

## 开发参考

这个测试程序展示了如何：

1. **正确调用 C API**
2. **处理异步连接**
3. **管理内存（释放 C 字符串）**
4. **实现连接状态监控**
5. **处理错误和超时**

可以作为集成 libtsnet-forwarder 到 C/C++ 项目的参考示例。 