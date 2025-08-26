#!/usr/bin/env python3
# -*- coding: utf-8 -*-

def check_reinstall_encoding():
    """检查reinstall.sh文件的中文编码问题"""
    
    try:
        with open('reinstall.sh', 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        print(f"检查 reinstall.sh 文件 ({len(lines)} 行)")
        print("=" * 50)
        
        encoding_issues = []
        
        for i, line in enumerate(lines, 1):
            # 检查常见的中文乱码字符
            garbled_chars = [
                '涓€', '閿', '畨', '瑁', '呯', '▼', '搴', '廫',
                '宸', 'ュ', '叿', '缁', '犺', '京', '顓', '搁', '悶', '鍝', '眓',
                '绠', '辩', '鐞', '哱', '绋', '嬪', '簭', '瀹', '夎',
                '閿', '欒', '鍙', '傛', '暟', '涓', '嶈', '兘', '涓', '虹', '┖',
                '鐞哱', '绠辩', '宸ュ叿', '涓€閿', '畨瑁', '▼搴',
                '琛屽彿', '鍑芥暟', '閫€鍑虹爜', '璋冭瘯',
                '鑷村懡', '閿欒', '涓嬭浇', '澶辫触', '鍒囨崲', '婧愪笅杞', '瀹屾垚'
            ]
            
            # 检查是否包含乱码字符
            found_garbled = [char for char in garbled_chars if char in line]
            
            if found_garbled:
                encoding_issues.append({
                    'line_no': i,
                    'content': line.strip(),
                    'garbled_chars': found_garbled
                })
        
        if encoding_issues:
            print(f"发现 {len(encoding_issues)} 行存在编码问题:")
            print()
            for issue in encoding_issues:
                print(f"第 {issue['line_no']} 行:")
                print(f"  内容: {issue['content']}")
                print(f"  乱码字符: {', '.join(issue['garbled_chars'])}")
                print()
        else:
            print("✓ 未发现明显的中文编码问题")
            
        return encoding_issues
        
    except Exception as e:
        print(f"✗ 检查失败: {e}")
        return []

if __name__ == "__main__":
    check_reinstall_encoding()