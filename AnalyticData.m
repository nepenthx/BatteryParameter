classdef AnalyticData
    % 解析方法求解R，OCV
    properties
        R0
        OCV
        skip=0 
    end
    
    methods
        function obj = calculateR0(obj, LocalData)
            % calculateR0 - The analytic method calculates the value of R
            % 需要找到电流突变的阈值，在达到阈值后用dv/dt
            %有一个需要注意的问题是，R是和SOC相关的。看表格中的数据，通过安时积分法可以得到SOC的变化量，可能还需要手动提供一个SOC的初始状态来帮助判别
            threshold = 0.1; % 定义的阈值
            currents = LocalData.Amps;
            voltage = LocalData.Volts;
            diff_current = diff(currents);
            change_indices = find(abs(diff_current) > threshold);
            R0_values = [];
            
            for i = 1:length(change_indices)
                index = change_indices(i);
                delta_V = voltage(index + 1) - voltage(index);
                delta_I = diff_current(index);
                R0 = delta_V / delta_I;
                R0_values = [R0_values; R0];
            end
            
            if ~isempty(R0_values)
                obj.R0 = mean(R0_values);
            else
                obj.R0 = NaN; % 没有突变点的情况；此时统一使用数值方法求解 
                obj.skip=1
            end
        end
    end
end