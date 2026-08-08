# Tailscale IP Reuse Consistency Test

这个测试工具用于验证修改后的 TSNet 连接逻辑是否能够正确复用现有的状态目录，从而避免在 Tailscale 后台创建重复的设备。

## 功能

- 测试第一次连接到 Tailscale 网络并记录分配的 IP 地址
- 模拟应用重启，使用相同的状态目录进行第二次连接
- 比较两次连接的 IP 地址是否一致
- **验证连接回调在复用状态时也被正确调用**
- 验证状态复用功能是否正常工作

## 使用方法

### 方法一：使用测试脚本（推荐）

```bash
# 设置 Tailscale 认证密钥
export TSNET_AUTH_KEY="your-tailscale-auth-key"

# 运行测试
./test_ip_reuse.sh
```

### 方法二：手动运行

```bash
# 设置环境变量
export TSNET_AUTH_KEY="your-tailscale-auth-key"
export TSNET_HOSTNAME="test-device-name"  # 可选
export TSNET_STATE_DIR="/tmp/my-test-state"  # 可选

# 编译并运行
go build -o ip-reuse-test main.go
./ip-reuse-test
```

## 环境变量

- `TSNET_AUTH_KEY` (必需): Tailscale 认证密钥
- `TSNET_HOSTNAME` (可选): 设备主机名，默认为 "test-ip-reuse"
- `TSNET_STATE_DIR` (可选): 状态目录路径，默认为 "/tmp/tsnet-ip-reuse-test"

## 测试步骤

1. **第一次连接**: 连接到 Tailscale 网络并记录分配的 IP 地址
2. **回调验证**: 验证连接成功回调被正确调用
3. **状态检查**: 验证状态目录是否正确创建
4. **模拟重启**: 清理连接但保留状态目录
5. **第二次连接**: 使用相同配置重新连接，应该复用现有状态
6. **回调验证**: 验证复用连接时回调仍然被正确调用
7. **结果比较**: 比较两次连接的 IP 地址

## 预期结果

✅ **成功**: 如果满足以下条件，说明状态复用功能正常工作：
- 两次连接的 IP 地址完全一致
- **两次连接都正确调用了成功回调**
- 不会在 Tailscale 后台创建重复设备

❌ **失败**: 如果出现以下情况，可能表示状态复用功能存在问题：
- IP 地址不一致
- **回调未被调用或调用次数不正确**
- 这可能导致重复设备或应用层状态不一致

## 获取 Tailscale 认证密钥

1. 登录 [Tailscale Admin Console](https://login.tailscale.com/admin/)
2. 点击 "Settings" → "Keys"
3. 生成一个新的认证密钥（Auth Key）
4. 复制密钥并设置为环境变量

## 测试输出示例

成功的测试输出应该包含：

```
🔔 Callback #1 - Connect Success: hostname=test-ip-reuse, ...
✅ Callback was called for first connection
✅ State directory exists: /tmp/tsnet-ip-reuse-test
🔔 Callback #2 - Connect Success: hostname=test-ip-reuse, ...
✅ Callback was called for second connection (state reuse)
✅ SAME: IP[0] = 100.x.x.x
📊 Callback Statistics:
   - Total callbacks called: 2
   - First connection callback: ✅
   - Second connection callback: ✅
🎉 SUCCESS: All IP addresses remained consistent after state reuse!
✅ Callbacks are called properly in both new and reuse scenarios
```

## 注意事项

- 测试完成后会自动清理测试状态和临时文件
- 每次运行测试都会使用唯一的主机名和状态目录（如果不手动指定）
- 测试过程中会在 Tailscale 网络中短暂显示一个测试设备，测试完成后会自动清理
- **新增**: 测试现在会验证回调函数在状态复用时也被正确调用，确保应用层能够正确感知连接状态 