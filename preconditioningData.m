%预处理实验数据，获取必要的数据
%需要计算SOC，用安时积分
classdef preconditioningData
properties
    SOC_Status
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
 end
    
end