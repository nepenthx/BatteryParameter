classdef LoadData
    properties (SetAccess = private)
        DataTable      % 存储完整数据表格
        FilePath       % 文件路径
    end
    
    properties (Dependent)
        Rec            % 记录号
        Cyc            % 循环次数
        Step           % 步骤编号
        TestTime       % 测试时间戳（秒）
        StepTime       % 步骤内时间戳（秒）
        Amp_hr         % 安时容量
        Watt_hr        % 瓦时容量
        Amps           % 电流（正充电，负放电）
        Volts          % 电压
    end
    
    methods
        function obj = LoadData(filePath)
            if nargin < 1
                fileList = dir('*.csv');
                if isempty(fileList)
                    error('LoadData:FileNotFound', '未找到 CSV 文件');
                end
                obj.FilePath = fullfile(pwd, fileList(1).name);
            else
                if ~exist(filePath, 'file')
                    error('LoadData:FileNotFound', '文件不存在: %s', filePath);
                end
                obj.FilePath = filePath;
            end
            obj = obj.readData();  
        end
        
        function obj = readData(obj)
            try
                tbl = readtable(obj.FilePath, ...
                    'Delimiter', ',', ...          
                    'VariableNamingRule', 'preserve'); 
            catch ME
                error('LoadData:ReadError', 'CSV 文件读取失败: %s', ME.message);
            end
            
            requiredCols = {'Rec', 'Cyc', 'Step', 'TestTime', 'StepTime', ...
                            'Amp_hr', 'Watt_hr', 'Amps', 'Volts'};
            missingCols = setdiff(requiredCols, tbl.Properties.VariableNames);
            if ~isempty(missingCols)
                error('LoadData:MissingColumns', 'CSV 文件中缺失必要列: %s', strjoin(missingCols, ', '));
            end
            
            obj.DataTable = tbl(:, requiredCols);
        end
        function rowData = getRow(obj, idx)
            validateattributes(idx, {'numeric'}, ...
                {'scalar', 'positive', 'integer', '<=', height(obj.DataTable)});
    
            rowData = table2struct(obj.DataTable(idx, :));
        end
    end
    
    methods
        function value = get.Rec(obj),       value = obj.DataTable.Rec;       end
        function value = get.Cyc(obj),       value = obj.DataTable.Cyc;       end
        function value = get.Step(obj),      value = obj.DataTable.Step;      end
        function value = get.TestTime(obj),  value = obj.DataTable.TestTime;  end
        function value = get.StepTime(obj),  value = obj.DataTable.StepTime;  end
        function value = get.Amp_hr(obj),    value = obj.DataTable.Amp_hr;    end
        function value = get.Watt_hr(obj),   value = obj.DataTable.Watt_hr;   end
        function value = get.Amps(obj),      value = obj.DataTable.Amps;      end
        function value = get.Volts(obj),     value = obj.DataTable.Volts;     end
    end
end