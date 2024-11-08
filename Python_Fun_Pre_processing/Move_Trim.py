# 根据filtered_data.csv，将对应数据集的dicom数据移出到指定目录

import os
import shutil
import pandas as pd
import re

def Move_Trim(root_directory, target_root, csv_file_path, move_miss_file,Prefix,endswith,moveNocopy):

    # 读取CSV文件
    df = pd.read_csv(csv_file_path)

    # 检查Miss_Value.csv是否存在，如果存在则读取内容
    if os.path.exists(move_miss_file):
        print(move_miss_file, "\texists")

    miss_df = pd.DataFrame(columns=df.columns)

    # 遍历每一行数据
    print("Moving & Trimming ...")
    for index, row in df.iterrows():
        subject = row['Subject']
        description = row['Description']
        # 根据Modality和Subject构造目标目录
        modality = row['Modality']
        target_directory = os.path.join(target_root, modality, subject)

        if not os.path.exists(target_directory):
            # 如果目标目录不存在则创建它
            os.makedirs(target_directory)

        # 将描述中的非字母数字字符替换为下划线
        # \W：匹配任何非单词字符（等价于[ ^a-zA-Z0-9]）+：表示匹配前面的子模式一次或多次。
        # 因此，r'\W+'匹配任何连续的非单词字符序列,去掉+

        description_cleaned = re.sub(r'[^-,\w]', '_', description)
        # 构造DICOM文件的根路径
        dicom_root_path = os.path.join(root_directory, subject, f"{Prefix}{description_cleaned}")
        if not os.path.exists(dicom_root_path):
            print("NULL PATH",{subject}, "\t", {modality}, "\t", {description}, "\t", {description_cleaned}, "\t",
                  {dicom_root_path})
            miss_df = pd.concat([miss_df, df.iloc[[index]]])
            continue
        # assert os.path.exists(dicom_root_path), "Path is not exists!"

        # 查找DICOM文件
        dicom_file_found = False
        for dirpath, dirnames, filenames in os.walk(dicom_root_path):
            for filename in filenames:
                if filename.lower().endswith(tuple(endswith)):  # 识别以.dcm结尾的文件
                    dicom_file_found = True
                    # 若不是字符串类型，则转换
                    if isinstance(dirpath, bytes):
                        dirpath = dirpath.decode('utf-8')
                    if isinstance(filename, bytes):
                        filename = filename.decode('utf-8')

                    dicom_file_path = os.path.join(dirpath, filename)
                    # 复制或移动DICOM文件到目标目录
                    target_file_path = os.path.join(target_directory, filename)

                    if moveNocopy:
                        shutil.move(dicom_file_path, target_file_path)
                    else:
                        shutil.copy(dicom_file_path, target_file_path)
            if dicom_file_found:
                break  # 找到一个DICOM文件后跳出循环
        if not dicom_file_found:
            # 如果没有找到DICOM文件，将该行数据添加到Miss_Value.csv中
            miss_df = pd.concat([miss_df, df.iloc[[index]]])
    # 保存Miss_Value.csv
    move_miss_file = os.path.join(os.path.dirname(target_root), move_miss_file)
    miss_df.to_csv(move_miss_file, index=False)
    print("Moving & Trimming Successful！")
    print(f"total: {len(df)}, {len(miss_df)} item fail to move ")


