#!/usr/bin/env python3
# -*- coding: utf-8 -*-

def fix_config_encoding():
    """修复config.sh文件的中文编码问题"""
    
    # 乱码映射表
    encoding_map = {
        # 基础乱码字符
        '琛屽彿': '行号',
        '鍑芥暟': '函数', 
        '閫€鍑虹爜': '退出码',
        '璋冭瘯': '调试',
        
        # 单个乱码字符
        '琛': '行',
        '屽': '号',
        '彿': '号',
        '鍑': '函',
        '芥': '数',
        '暟': '数',
        '閫': '退',
        '€': '出',
        '鍑': '出',
        '虹': '码',
        '爜': '码',
        '璋': '调',
        '冭': '试',
        '瘯': '试'
    }
    
    try:
        # 读取文件
        with open('config.sh', 'r', encoding='utf-8') as f:
            content = f.read()
        
        print("开始修复 config.sh 文件的编码问题...")
        print("=" * 50)
        
        # 应用修复
        original_content = content
        for garbled, correct in encoding_map.items():
            if garbled in content:
                content = content.replace(garbled, correct)
                print(f"✓ 已替换: '{garbled}' -> '{correct}'")
        
        # 写回文件
        if content != original_content:
            with open('config.sh', 'w', encoding='utf-8') as f:
                f.write(content)
            print("\n✓ config.sh 文件编码修复完成")
        else:
            print("\n✓ config.sh 文件无需修复")
            
    except Exception as e:
        print(f"✗ 修复失败: {e}")

if __name__ == "__main__":
    fix_config_encoding()