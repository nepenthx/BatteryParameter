%预处理实验数据，获取必要的数据
%划分SOC窗口，并且根据窗口分别计算数据
%需要计算SOC，用安时积分
classdef preconditioningData
properties
    SOC_Status
    SOC_Windows
end
methods

    function obj= init(obj,data)
        obj=obj.calculateSoc(data);
        obj=obj.getSOCWindows(data);
    end
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
            %SOC = max(0, min(SOC, 100));
            SOC_List(k) = SOC;
        end

        max_value=max(SOC_List);
        temp_value=max_value-100;
        for k = 1:length(SOC_List)
            SOC_List(k)=max(0,SOC_List(k)-temp_value);
        end
        obj.SOC_Status = SOC_List();
    end


    function obj = getSOCWindows(obj, data)
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
            current_window.SOC = obj.SOC_Status(current_window.indices); 
            obj.SOC_Windows(i) = current_window;
        end
    end

    function verifyModel(prec, data)
        V_actual = [];
        V_predicted = [];
        
        for k = 1:length(prec.SOC_Windows)
            window = prec.SOC_Windows(k);
            if isempty(window.rowInfo)
                continue;
            end
            t = [window.rowInfo.TestTime]';
            I = [window.rowInfo.Amps]';
            S = window.SOC';
            V_meas = [window.rowInfo.Volts]';
            params = window.oth;
            
            V_model = window.predict(params, t, I, S);
            
            V_actual = [V_actual; V_meas];
            V_predicted = [V_predicted; V_model];
        end
        
        rmse = sqrt(mean((V_actual - V_predicted).^2));
        disp('RMSE: %.4f V\n', rmse);
        
        figure;
        plot(V_actual, 'b', 'DisplayName', '实际电压');
        hold on;
        plot(V_predicted, 'r', 'DisplayName', '预测电压');
        xlabel('数据点');
        ylabel('电压 (V)');
        legend;
        title('电压比较');
    end
end
end