#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import glob

def check_lib_files_encoding():
    """检查所有lib_*.sh库文件的中文编码问题"""
    
    # 查找所有lib_*.sh文件
    lib_files = glob.glob('lib_*.sh')
    
    if not lib_files:
        print("未找到lib_*.sh文件")
        return
    
    print(f"找到 {len(lib_files)} 个lib库文件:")
    for f in lib_files:
        print(f"  - {f}")
    print("=" * 60)
    
    # 乱码字符列表
    garbled_chars = [
        '涓€', '閿', '畨', '瑁', '呯', '▼', '搴', '廫',
        '宸', 'ュ', '叿', '缁', '犺', '京', '顓', '搁', '悶', '鍝', '眓',
        '绠', '辩', '鐞', '哱', '绋', '嬪', '簭', '瀹', '夎',
        '閿', '欒', '鍙', '傛', '暟', '涓', '嶈', '兘', '涓', '虹', '┖',
        '鐞哱', '绠辩', '宸ュ叿', '涓€閿', '畨瑁', '▼搴',
        '琛屽彿', '鍑芥暟', '閫€鍑虹爜', '璋冭瘯',
        '鑷村懡', '閿欒', '涓嬭浇', '澶辫触', '鍒囨崲', '婧愪笅杞', '瀹屾垚',
        '瀹夎', '鍗歌浇', '鍚姩', '鍋滄', '閲嶅惎', '閰嶇疆', '妫€鏌',
        '鏈嶅姟', '绔彛', '闃茬伀澧', '缃戠粶', '绯荤粺', '鐢ㄦ埛',
        '鏉冮檺', '鏂囦欢', '鐩綍', '澶囦唤', '鎭㈠', '鏇存柊'
    ]
    
    total_issues = 0
    files_with_issues = []
    
    for lib_file in sorted(lib_files):
        try:
            with open(lib_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            print(f"\n检查 {lib_file} ({len(lines)} 行)")
            print("-" * 40)
            
            file_issues = []
            
            for i, line in enumerate(lines, 1):
                # 检查是否包含乱码字符
                found_garbled = [char for char in garbled_chars if char in line]
                
                if found_garbled:
                    file_issues.append({
                        'line_no': i,
                        'content': line.strip(),
                        'garbled_chars': found_garbled
                    })
            
            if file_issues:
                print(f"发现 {len(file_issues)} 行存在编码问题:")
                for issue in file_issues:
                    print(f"  第 {issue['line_no']} 行: {', '.join(issue['garbled_chars'])}")
                    if len(issue['content']) > 80:
                        print(f"    内容: {issue['content'][:80]}...")
                    else:
                        print(f"    内容: {issue['content']}")
                files_with_issues.append(lib_file)
                total_issues += len(file_issues)
            else:
                print("✓ 未发现编码问题")
                
        except Exception as e:
            print(f"✗ 检查 {lib_file} 失败: {e}")
    
    print("\n" + "=" * 60)
    print("检查结果汇总:")
    print(f"总计检查文件: {len(lib_files)}")
    print(f"存在问题文件: {len(files_with_issues)}")
    print(f"总计问题行数: {total_issues}")
    
    if files_with_issues:
        print("\n需要修复的文件:")
        for f in files_with_issues:
            print(f"  - {f}")
    else:
        print("\n✓ 所有lib库文件编码正常")
    
    return files_with_issues

if __name__ == "__main__":
    check_lib_files_encoding()