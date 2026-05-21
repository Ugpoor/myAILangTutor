import re

with open('lib/services/demo_data_initializer.dart', 'r') as f:
    content = f.read()

# 修复 aiReview 字段结尾的多余逗号
content = re.sub(r"aiReview: '[^']+',,", lambda m: m.group(0).replace(',,', ','), content)

with open('lib/services/demo_data_initializer.dart', 'w') as f:
    f.write(content)

print('Done')
