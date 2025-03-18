%预处理实验数据，获取必要的数据
%划分SOC窗口，并且根据窗口分别计算数据
%需要计算SOC，用安时积分
classdef preconditioningData
properties
    SOC_Status
    SOC_Windows
end
methods
    function obj = calculateSoc(obj,data) 
        SOC0 = config.getInstance().SOC0; 
        capacity = config.getInstance().C0; 
    
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


    function obj = getSOCWindows(obj,data)
        window_size = config.getInstance().SOC_Window_Granularity;
        soc_edges = 0:window_size:100;
        
        num_windows = length(soc_edges) - 1;
        obj.SOC_Windows = repmat(soc_block(), 1, num_windows);
        for i = 1:num_windows
            lower = soc_edges(i);
            upper = soc_edges(i+1);
            
            current_window = soc_block(lower, upper);
            
            if i == num_windows
                mask = (obj.SOC_Status >= lower) & (obj.SOC_Status <= upper);
            else
                mask = (obj.SOC_Status >= lower) & (obj.SOC_Status < upper);
            end
            current_window.indices = find(mask);
            
            obj.SOC_Windows(i) = current_window;
        end
    end
end
end