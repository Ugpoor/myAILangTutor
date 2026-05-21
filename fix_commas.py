import re

with open('lib/services/demo_data_initializer.dart', 'r') as f:
    content = f.read()

# 修复多余的逗号模式
content = re.sub(r"\'\'\',\s*,", "''' ,", content)
content = re.sub(r"'''\s*,\s*,", "''' ,", content)

with open('lib/services/demo_data_initializer.dart', 'w') as f:
    f.write(content)

print('Done')
