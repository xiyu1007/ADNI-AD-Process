# 合并文件（追加）
import pandas as pd

# 读取两个CSV文件
df1 = pd.read_csv('temp/ADNI1_MRI_Month6_11_02_2024.csv')
df2 = pd.read_csv('temp/ADNI1_PET_ACPC_Month6_11_02_2024.csv')
# 将df1追加到df2的末尾
df_combined = pd.concat([df2, df1], ignore_index=True)
# 将合并后的数据写入新的CSV文件
df_combined.to_csv('ADNI1_MRI&PET_ACPC_Month6.csv', index=False)