# 部署真实ML模型到Hugging Face指南

## 概览

我们将创建一个简单的眼动数据分析模型，部署到Hugging Face Spaces，然后从iOS应用调用它。

## 步骤1: 创建Hugging Face账户和获取Token

### 1.1 注册免费账户
1. 访问 [https://huggingface.co/join](https://huggingface.co/join)
2. 注册免费账户

### 1.2 获取API Token
1. 登录后，点击右上角头像 → Settings
2. 选择 "Access Tokens" 
3. 点击 "New token"
4. 名称: `gaze-track-app`
5. 类型: `Read` (免费用户足够)
6. 复制生成的token

## 步骤2: 创建Hugging Face Space

### 2.1 创建新Space
1. 访问 [https://huggingface.co/new-space](https://huggingface.co/new-space)
2. Space名称: `gaze-tracking-analyzer`
3. 选择SDK: `Gradio`
4. 设为Public
5. 点击 "Create Space"

### 2.2 Space文件结构
```
gaze-tracking-analyzer/
├── app.py              # 主应用文件
├── requirements.txt    # Python依赖
├── README.md          # 说明文档
└── utils.py           # 工具函数
```

## 步骤3: 创建模型代码

### 3.1 app.py (主应用文件)
```python
import gradio as gr
import pandas as pd
import numpy as np
import io
import json

def analyze_gaze_data(csv_data):
    """
    分析眼动数据并返回分析结果
    """
    try:
        # 解析CSV数据
        df = pd.read_csv(io.StringIO(csv_data))
        
        # 基本统计分析
        total_points = len(df)
        duration = df['elapsedTime(seconds)'].max() - df['elapsedTime(seconds)'].min()
        
        # 计算移动距离
        distances = []
        for i in range(1, len(df)):
            dx = df.iloc[i]['x'] - df.iloc[i-1]['x'] 
            dy = df.iloc[i]['y'] - df.iloc[i-1]['y']
            distance = np.sqrt(dx**2 + dy**2)
            distances.append(distance)
        
        avg_distance = np.mean(distances) if distances else 0
        total_distance = np.sum(distances) if distances else 0
        
        # 计算覆盖范围
        x_range = df['x'].max() - df['x'].min()
        y_range = df['y'].max() - df['y'].min()
        coverage_area = x_range * y_range
        
        # 计算稳定性 (速度变化的标准差)
        speeds = np.array(distances) / np.diff(df['elapsedTime(seconds)'].values) if len(distances) > 1 else [0]
        stability = 100 - min(np.std(speeds) * 10, 100) if len(speeds) > 1 else 50
        
        # 计算注意力分数 (基于多个因素)
        attention_score = calculate_attention_score(
            duration, avg_distance, stability, coverage_area, total_points
        )
        
        # 返回分析结果
        result = {
            "score": int(attention_score),
            "analysis": {
                "total_points": total_points,
                "duration_seconds": round(duration, 2),
                "average_movement": round(avg_distance, 2),
                "total_movement": round(total_distance, 2),
                "stability_score": round(stability, 2),
                "coverage_area": round(coverage_area, 2)
            },
            "message": f"Analysis completed: {get_score_description(attention_score)}"
        }
        
        return json.dumps(result, indent=2)
        
    except Exception as e:
        error_result = {
            "score": 0,
            "error": str(e),
            "message": "Analysis failed"
        }
        return json.dumps(error_result, indent=2)

def calculate_attention_score(duration, avg_movement, stability, coverage, points):
    """
    计算注意力分数 (1-100)
    """
    # 基础分数
    base_score = 50
    
    # 持续时间分数 (10-30秒为最佳)
    if 10 <= duration <= 30:
        duration_score = 25
    elif duration > 30:
        duration_score = 25 - min((duration - 30) * 0.5, 15)
    else:
        duration_score = duration * 2.5
    
    # 移动稳定性分数
    stability_score = min(stability * 0.3, 20)
    
    # 数据质量分数 (基于数据点数量)
    quality_score = min(points / 100, 1) * 15
    
    # 合理移动范围分数
    if 50 <= avg_movement <= 200:
        movement_score = 10
    else:
        movement_score = max(10 - abs(avg_movement - 125) * 0.05, 0)
    
    total_score = base_score + duration_score + stability_score + quality_score + movement_score
    return max(1, min(100, total_score))

def get_score_description(score):
    """
    根据分数返回描述
    """
    if score >= 85:
        return "Excellent attention patterns"
    elif score >= 70:
        return "Good attention stability" 
    elif score >= 55:
        return "Moderate attention focus"
    elif score >= 40:
        return "Needs attention improvement"
    else:
        return "Poor attention patterns"

# 创建Gradio界面
def create_interface():
    interface = gr.Interface(
        fn=analyze_gaze_data,
        inputs=gr.Textbox(
            label="CSV Data", 
            placeholder="Paste your CSV data here...",
            lines=10
        ),
        outputs=gr.Textbox(
            label="Analysis Result",
            lines=15
        ),
        title="Gaze Tracking Data Analyzer",
        description="Upload CSV gaze tracking data to get attention and focus analysis"
    )
    return interface

# 启动应用
if __name__ == "__main__":
    app = create_interface()
    app.launch()
```

### 3.2 requirements.txt
```
gradio>=4.0.0
pandas>=1.5.0
numpy>=1.21.0
```

### 3.3 README.md
```markdown
# Gaze Tracking Data Analyzer

A simple ML model for analyzing gaze tracking data and providing attention/focus scores.

## Features
- Analyzes CSV gaze tracking data
- Calculates attention scores (1-100)
- Provides movement and stability metrics
- REST API compatible

## Usage
Send POST request with CSV data to get analysis results.
```

## 步骤4: 部署到Hugging Face

### 4.1 上传文件
1. 在你的Space页面，点击 "Files" 标签
2. 点击 "Add file" → "Upload files"
3. 上传所有文件 (app.py, requirements.txt, README.md)
4. 提交更改

### 4.2 等待部署
- Space会自动构建和部署
- 通常需要2-5分钟
- 可在"Logs"标签查看进度

## 步骤5: 获取API端点

部署完成后，你的API端点将是：
```
https://YOUR_USERNAME-gaze-tracking-analyzer.hf.space/api/predict
```

例如：
```
https://johndoe-gaze-tracking-analyzer.hf.space/api/predict
```

## 步骤6: 测试部署的模型

### 6.1 使用curl测试
```bash
curl -X POST \
  https://YOUR_USERNAME-gaze-tracking-analyzer.hf.space/api/predict \
  -H "Content-Type: application/json" \
  -d '{
    "data": ["elapsedTime(seconds),x,y\n0.000,100.50,200.30\n0.016,101.20,201.15\n"]
  }'
```

### 6.2 预期响应
```json
{
  "data": [
    "{\"score\": 75, \"analysis\": {...}, \"message\": \"Analysis completed: Good attention stability\"}"
  ]
}
```

## 步骤7: 更新iOS应用

现在我们需要更新iOS应用来调用真实的模型...

## 成本说明

✅ **完全免费**: 
- Hugging Face Spaces: 免费
- Gradio应用: 免费
- API调用: 免费 (有合理限制)
- 存储: 免费

## 下一步

1. 创建Space并上传代码
2. 获取你的API端点URL
3. 更新iOS应用代码
4. 测试真实的模型调用