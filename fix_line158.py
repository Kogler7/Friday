# Fix line 158 in idea_screen.dart - unterminated string
path = r'lib/screens/idea_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()
# Line 158 is index 157
if len(lines) > 157:
    line = lines[157]
    if '选择或新建一个' in line and ('娉' in line or '璇' in line):
        lines[157] = "                              ? '选择或新建一个会话开始记录想法'\n"
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Fixed line 158')
