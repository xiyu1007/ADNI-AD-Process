% ROI&PET => MRI
% MRI => MNI,ROI&PET => MNI
MNI = 'template\registration\mni_icbm152_t1_tal_nlin_asym_09a.nii';
% Important !!! ROI and ROI_out dir must be different!
ROI = 'ROI';
ROI_out = 'D:\Matlab\Project\GroupMeeting\Datasets_Filter_From_Raw\ADNI1\DICOM2Nii\PET_ROI';
PET = 'D:\Matlab\Project\GroupMeeting\Datasets_Filter_From_Raw\ADNI1\DICOM2Nii\PET';
MRI = 'D:\Matlab\Project\GroupMeeting\Datasets_Filter_From_Raw\ADNI1\DICOM2Nii\MRI';

outputPrefix = 'r'; % 是已经完成的文件前缀
verbose = false; % 打印SPM输出，检查出错

% 定义日志文件路径
logFile = 'err_coregister.log';

% 打开日志文件（若文件已存在，将追加内容）
fid = fopen(logFile, 'w+');
if fid == -1
    error('无法打开日志文件 %s 进行写入', logFile);
end

% 去除PS打印警告，如果你启动了SPM的Graphic,取消注释去除警告，否则不要这么做
% print('-dpdf', 'output.pdf');

%run
batch_coregiter_job(MNI,ROI_out,ROI,PET,MRI,outputPrefix,verbose,fid);  

function batch_coregiter_job(MNI,ROI_out,ROI,PET,MRI,outputPrefix,verbose,fid,interp)
    if nargin<9
        interp = 4;
    end
    if ~exist(ROI_out)
        mkdir(ROI_out);
    end
    % 获取每个目录下的非 r 开头的 .nii 文件
    mni = [MNI,',1'];
    %%
    ROI_files = dir(fullfile(ROI, '*.nii'));
    ROI_files = ROI_files(~startsWith({ROI_files.name}, outputPrefix));
    PET_files = dir(fullfile(PET, '*.nii'));
    PET_files = PET_files(~startsWith({PET_files.name}, outputPrefix));
    MRI_files = dir(fullfile(MRI, '*.nii'));
    MRI_files = MRI_files(~startsWith({MRI_files.name}, outputPrefix));

    % 打印过滤后的文件数量在一行
    fprintf('Filtered file counts - ROI: %d, PET: %d, MRI: %d\n', ...
        numel(ROI_files),numel(PET_files), numel(MRI_files));
    
    % 检查 MRI 和 PET 文件数量是否一致
    if numel(MRI_files) ~= numel(PET_files)
        warning('The number of MRI files (%d) does not match the number of PET files (%d).', ...
            numel(MRI_files), numel(PET_files));
    end

    % 将 MRI 文件列表转为结构，以便快速查找
    MRI_filenames = {MRI_files.name};
    MRI_map = containers.Map();
   
    for i = 1:length(MRI_files)
        [~, name, ext] = fileparts(MRI_files(i).name);
        MRI_map(name) = fullfile(MRI, [name, ext]);
    end

    currentDir = pwd;
    tempName = 'temp.nii';
    rtempName = [outputPrefix,tempName];
    tempFilePath = fullfile(currentDir,tempName);
    rtempFilePath = fullfile(currentDir,rtempName);
    % 遍历 PET 文件并找到匹配的 MRI 文件
    for i = 1:length(PET_files)
        [~, pet_name, ~] = fileparts(PET_files(i).name);
        
        % 检查是否存在匹配的 MRI 文件
        if isKey(MRI_map, pet_name)
            % 获取匹配的 MRI 文件路径
            m = MRI_map(pet_name);
            p = fullfile(PET, PET_files(i).name);

            % 第一步：将 PET 和 ROI 配准到 MRI,再到MNI
            copyfile(p, tempFilePath);
            coregister_job(m, tempFilePath, interp, outputPrefix, verbose); 
            movefile(rtempFilePath,tempFilePath);
            coregister_job(mni, tempFilePath, interp, outputPrefix, verbose);
            movefile(rtempFilePath,fullfile(PET, [outputPrefix,PET_files(i).name]));  

            for j = 1:length(ROI_files)
                r = fullfile(ROI, ROI_files(j).name);
                copyfile(r, tempFilePath);
                coregister_job(m, tempFilePath, 0, outputPrefix, verbose); % 配准 ROI 到 MRI，0 为最近邻插值
                movefile(rtempFilePath,tempFilePath);
                coregister_job(mni, tempFilePath, 0, outputPrefix, verbose);
                % 重命名配准后的 ROI 文件
                [~, roi_name, ext] = fileparts(ROI_files(j).name);
                %% 可以修改自己期望的格式
                ROI_name = sprintf('%s_%s%s%s',roi_name,outputPrefix,pet_name, ext);
                movefile(rtempFilePath,fullfile(ROI_out,ROI_name));      
            end
            copyfile(m, tempFilePath);
            coregister_job(mni,tempFilePath, interp, outputPrefix,verbose); % 将 MRI 配准到 MNI
            movefile(rtempFilePath,fullfile(MRI,[outputPrefix,pet_name])); 
    
        else
            % 如果没有找到匹配的 MRI 文件，记录到日志文件并显示警告信息
            fprintf(fid, '未找到匹配的 MRI 文件用于 PET 文件: %s\n', PET_files(i).name);
            warning('未找到匹配的 MRI 文件用于 PET 文件: %s', PET_files(i).name);
        end
       fprintf('Done(All): %d(%d),Processing... \n',i,length(PET_files)); 
    end

    delete(tempFilePath);
    % 关闭日志文件
    fclose(fid);
end
