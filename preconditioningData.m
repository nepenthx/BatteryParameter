%预处理实验数据，获取必要的数据
%划分SOC窗口，并且根据窗口分别计算数据
%需要计算SOC，用安时积分
classdef preconditioningData
properties
    SOC_Status
    SOC_Windows
end
 methods
    function obj = calculateSoc(obj, config, data) 
        SOC0 = config.SOC0; 
        capacity = config.C0; 
    
        time = data.TestTime;
        current = data.Amps; 
    
        dt = diff(time)/3600; 
        SOC = SOC0; 
        SOC_List = zeros(size(time));
        SOC_List(1) = SOC;
    
        for k = 2:length(time)
            delta_Q = current(k-1) * dt(k-1); 
            SOC = SOC + (delta_Q / capacity) * 100; 
            SOC = max(0, min(SOC, 100));
            SOC_List(k) = SOC;
        end
    
        obj.SOC_Status = SOC_List;
    end


    function obj = getSOCWindows(obj, config, data)
        window_size = config.SOC_Window_Granularity;
        soc_edges = 0:window_size:100; 
        
        % 创建空结构体数组存储窗口数据
        obj.SOC_Windows = struct(...
            'Range', {}, ...     % 窗口范围 [min, max]
            'Indices', {}, ...   % 属于该窗口的数据索引
            'MeanVoltage', {}, ... 
            'MeanCurrent', {}, ...
            'StdR0', {} ...     
        );
        
        % 遍历所有SOC窗口
        for i = 1:length(soc_edges)-1
            lower = soc_edges(i);
            upper = soc_edges(i+1);
            
            % 找到属于当前窗口的索引（处理最后一个窗口闭区间）
            if i == length(soc_edges)-1
                mask = (obj.SOC_Status >= lower) & (obj.SOC_Status <= upper);
            else
                mask = (obj.SOC_Status >= lower) & (obj.SOC_Status < upper);
            end
            
            % 填充窗口信息
            obj.SOC_Windows(i).Range = [lower, upper];
            obj.SOC_Windows(i).Indices = find(mask);
            
            % 计算统计量（示例：电压和电流的均值）
            if ~isempty(obj.SOC_Windows(i).Indices)
                obj.SOC_Windows(i).MeanVoltage = mean(data.Volts(mask));
                obj.SOC_Windows(i).MeanCurrent = mean(data.Amps(mask));
            else
                obj.SOC_Windows(i).MeanVoltage = NaN;
                obj.SOC_Windows(i).MeanCurrent = NaN;
            end
        end
    end
 end
    
end