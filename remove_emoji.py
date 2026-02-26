#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量删除 Flutter 项目中的 emoji
"""
import os
import re

# emoji 替换映射
EMOJI_MAP = {
    '': '',
    '': '',
    '': '',
    '': '',
    '': '',
    '': '',
    '': '',
    '': '',
    '': '',
    '': '',
    '': '',
    '': '',
}

# 标签替换
TAG_MAP = {
    '[CRITICAL]': '',
    '[NEW]': '',
    '[核心]': '',
}

def remove_emoji_from_file(file_path):
    """从文件中删除 emoji"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # 替换 emoji
        for emoji, replacement in EMOJI_MAP.items():
            content = content.replace(emoji, replacement)
        
        # 替换标签
        for tag, replacement in TAG_MAP.items():
            content = content.replace(tag, replacement)
        
        # 替换分隔线
        content = content.replace('═══════════════════════════════════════════════════════════════════════════', '============================================================')
        
        # 清理多余空格
        content = re.sub(r'//\s+\s+', '// ', content)
        
        # 如果内容有变化，写回文件
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f'已修复: {file_path}')
            return True
        return False
    except Exception as e:
        print(f'错误 {file_path}: {e}')
        return False

def main():
    """主函数"""
    lib_dir = r'c:\Users\20216\Documents\GitHub\Clutch\ceramic-workshop-app\lib'
    
    fixed_count = 0
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                if remove_emoji_from_file(file_path):
                    fixed_count += 1
    
    print(f'\n总共修复了 {fixed_count} 个文件')

if __name__ == '__main__':
    main()

