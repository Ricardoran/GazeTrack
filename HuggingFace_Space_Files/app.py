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
        if len(distances) > 1:
            time_diffs = np.diff(df['elapsedTime(seconds)'].values)
            speeds = np.array(distances) / time_diffs
            stability = 100 - min(np.std(speeds) * 10, 100)
        else:
            stability = 50
        
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
        description="Upload CSV gaze tracking data to get attention and focus analysis",
        examples=[
            ["elapsedTime(seconds),x,y\n0.000,100.50,200.30\n0.016,101.20,201.15\n0.032,102.10,202.05\n0.048,103.05,203.20\n0.064,104.15,204.35"]
        ],
        api_name="predict",  # 显式设置API端点名称
        allow_flagging="never",  # 禁用标记功能
        show_api=True  # 显示API
    )
    return interface

# 启动应用
if __name__ == "__main__":
    app = create_interface()
    app.launch(share=False, show_api=True)