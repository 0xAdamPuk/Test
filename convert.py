# 读取 e.txt 文件，处理每一行，并写入到 f.txt 文件
with open('e.txt', 'r') as infile, open('f.txt', 'w') as outfile:
    for line in infile:
        AAA, BBB, CCC, DDD = line.strip().split(':')
        outfile.write(f'http://{CCC}:{DDD}@{AAA}:{BBB}\n')
