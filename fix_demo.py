import re

with open('lib/services/demo_data_initializer.dart', 'r') as f:
    content = f.read()

# 匹配并删除 content: '''...''' 块
pattern = r'\s+content: \'\'\'[\s\S]*?\'\'\''
content = re.sub(pattern, '', content)

with open('lib/services/demo_data_initializer.dart', 'w') as f:
    f.write(content)

print('Done')
