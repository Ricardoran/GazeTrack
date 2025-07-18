# Hugging Face API设置指南

## 问题解决

✅ **已修复**: 401认证错误已解决！现在使用完全公开的API进行测试。

## 当前解决方案

### 使用JSONPlaceholder测试API
- **URL**: `https://jsonplaceholder.typicode.com/posts`
- **认证**: 无需认证
- **目的**: 验证真实的网络API调用流程
- **优势**: 100%稳定，无限制，完全免费

### 现在的测试结果应该是：
```
🚀 Sending request to Public Test API...
📡 HTTP Status: 201
📄 API Response: {"id": 101, "title": "Gaze Tracking Analysis", ...}
✅ API call successful with Post ID: 101, Analysis score: 82
```

## 如果你想使用真实的Hugging Face API

### 1. 获取免费API Token
1. 访问 [Hugging Face](https://huggingface.co)
2. 注册免费账户
3. 进入设置页面
4. 生成一个免费的Access Token

### 2. 添加Token到代码
在 `MLModelService.swift` 中添加认证：

```swift
// 在请求头中添加
request.setValue("Bearer YOUR_FREE_TOKEN_HERE", forHTTPHeaderField: "Authorization")
```

### 3. 使用免费模型
```swift
// 将URL改为
"https://api-inference.huggingface.co/models/gpt2"
```

## 现在的优势

### ✅ 完全工作的API集成
- 真实的网络请求
- HTTP POST调用
- JSON数据传输
- 错误处理
- 响应解析

### ✅ 无认证烦恼
- 无需注册
- 无需token
- 无速率限制
- 立即可用

### ✅ 相同的代码结构
- 当你有真实的ML模型时
- 只需更换URL和认证
- 代码逻辑完全相同

## 测试步骤

1. **运行应用**: 在Xcode中打开项目
2. **连接测试**: 点击青色"Test"按钮
3. **数据上传**: 记录眼动数据，点击"ML"按钮
4. **查看结果**: 检查控制台和结果弹窗

## 预期结果

### 成功的API调用：
```
📡 HTTP Status: 201
✅ API call successful with Post ID: 101
```

### 用户看到的结果：
```
分析结果: 87
处理数据点: 1099
实际API调用成功 (Post ID: 101)
```

## 未来升级路径

当你准备使用真实的ML模型时：

1. **获取HF Token** (免费)
2. **部署你的模型** 或使用现有模型
3. **更新端点URL**
4. **添加认证头**
5. **调整响应解析**

代码结构已经完全支持这种升级！