classdef soc_block
    properties
        SOC
        range_lower      
        range_upper     
        indices         % 属于该窗口的原始数据索引
        R0              
        oth
        rowInfo
        skip = 0            
    end
    
    methods
        function obj = soc_block(lower, upper)
            if nargin == 0
                obj.range_lower = 0;
                obj.range_upper = 0;
            else
                obj.range_lower = lower;
                obj.range_upper = upper;
            end
            obj.indices = [];
            obj.R0 = NaN;
        end
        function obj = calculateR0(obj, threshold, avg_points)
            % 计算 SOC_block 对象在特定 SOC 区间内的 R0
            % 输入：
            %   obj：SOC_block 对象，包含 rowInfo 结构（已按 SOC 区间划分）
            %   threshold：电流跳变阈值（默认 0.5A）
            %   avg_points：跳变前后取平均的点数（默认 3）
            % 输出：
            %   obj：更新后的对象，包含该 SOC 区间的 R0
        
            if nargin < 2 || isempty(threshold)
                threshold = 0.5;
            end
            if nargin < 3 || isempty(avg_points)
                avg_points = 3;
            end
        
            currents = [obj.rowInfo.Amps];    
            voltages = [obj.rowInfo.Volts];  
            N = length(currents);           
        
            if N < 2 * avg_points + 1
                obj.R0 = NaN;
                disp("错误：该 SOC 区间数据点不足，无法计算 R0");
                return;
            end
        
            R0_values = [];
        
            for i = avg_points + 1 : N - avg_points
                % 计算相邻点的电流差
                delta_I = currents(i) - currents(i - 1);
                
                % 检查是否超过跳变阈值
                if abs(delta_I) > threshold
                    % 取跳变前后 avg_points 个点的平均值
                    I_before = mean(currents(i - avg_points : i - 1));
                    V_before = mean(voltages(i - avg_points : i - 1));
                    I_after = mean(currents(i : i + avg_points - 1));
                    V_after = mean(voltages(i : i + avg_points - 1));
                    
                    % 计算变化量
                    delta_I = I_after - I_before;
                    delta_V = V_after - V_before;
                    
                    % 避免除以零并计算 R0
                    if delta_I ~= 0
                        R0 = delta_V / delta_I;
                        R0_values = [R0_values; R0];
                    end
                end
            end
        
            if ~isempty(R0_values)
                obj.R0 = mean(R0_values);
            else
                obj.R0 = NaN; 
                disp("未检测到有效跳变点，统一用数值方法计算参数");
            end
        end
      
        function obj = getAllRow(obj, data)
            totalRows = numel(obj.indices);
            disp(totalRows);
            obj.rowInfo = struct('Rec', {}, 'Cyc', {}, 'Step', {}, ...
                                'TestTime', {}, 'StepTime', {}, ...
                                'Amp_hr', {}, 'Watt_hr', {}, ...
                                'Amps', {}, 'Volts', {});
            for i = 1:totalRows
                tempStruct = data.getRow(obj.indices(i));
                obj.rowInfo(i) = tempStruct;
            end
        end

        function obj = fminconTest(obj)
            data = obj.rowInfo;
            t = [data.TestTime]';
            I = [data.Amps]';
            V_meas = [data.Volts]';
            S = obj.SOC;
            
            if ~isequal(length(t), length(I), length(V_meas), length(S))
                error('t, I, V_meas, S 的长度必须一致！');
            end
            if ~isnumeric(t) || ~isnumeric(I) || ~isnumeric(V_meas) || ~isnumeric(S)
                error('t, I, V_meas, S 必须是数值类型！');
            end
            
            if isnan(obj.R0)
                param0 = [0, mean(V_meas), 0.01, 0.01, 5, 0];
                lb = [-1, 3.0, 0.001, 0.001, 10, -4.2];  % 下界
                ub = [1, 4.2, 0.1, 0.1, 100, 4.2];       % 上界
                disp('R0未初始化，统一计算');
            else
                param0 = [0, mean(V_meas), obj.R0, 0.01, 5, 0];
                lb = [-1, 3.0, obj.R0*0.99, 0, 10, -4.2];
                ub = [1, 4.2, obj.R0*1.01, 0.1, 1000, 4.2];
                disp('R0已初始化');
            end
            
            Aeq = [S(1), 1, -I(1), 0, 0, -1];
            beq = V_meas(1);
            
            options = optimset('Display', 'iter', 'MaxIter', 500);
            [param_opt, fval] = fmincon(@(x) obj.compute_RMSE(x, t, I, V_meas, S), ...
                param0, [], [], Aeq, beq, lb, ub, [], options);
            
            if isnan(obj.R0)
                obj.R0 = param_opt(3);
            end
            obj.oth = param_opt;
        end
        
        function error = compute_RMSE(obj, x, t, I, V_meas, S)
            OCV1 = x(1);
            OCV2 = x(2);
            R0 = x(3);
            R1 = x(4);
            tau1 = x(5);
            V_RC_init = x(6);
            
            N = length(t);
            V_RC = zeros(N,1);
            V_RC(1) = V_RC_init;
            
            for k = 2:N
                dt = t(k) - t(k-1);
                V_RC(k) = V_RC(k-1) + dt * ((I(k-1)*R1 - V_RC(k-1)) / tau1);
            end
            
            OCV = OCV1 * S + OCV2;
            V_model = OCV - I.*R0 - V_RC;
            
            error = sqrt(mean((V_meas - V_model).^2));
        end
    end
end