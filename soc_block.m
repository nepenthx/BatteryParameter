classdef soc_block
    properties
        SOC
        range_lower      
        range_upper     
        indices         % 属于该窗口的原始数据索引
        R0              
        oth
        rowInfo
        skip=0            
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
      
        function obj = calculateR0(obj)
            % calculateR0 - The analytic method calculates the value of R
            % 需要找到电流突变的阈值，在达到阈值后用dv/dt
            %有一个需要注意的问题是，R是和SOC相关的。看表格中的数据，通过安时积分法可以得到SOC的变化量，可能还需要手动提供一个SOC的初始状态来帮助判别
            threshold = 0.1; % 定义的阈值
            currents = obj.rowInfo.Amps;
            voltage = obj.rowInfo.Volts;
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
                disp("NANNANNAN")
                obj.skip=1
            end
        end

        function obj = getAllRow(obj, data)
            totalRows = height(obj.indices);
            disp(totalRows);
            obj.rowInfo = struct('Rec', {}, 'Cyc', {}, 'Step', {}, ...
                                'TestTime', {}, 'StepTime', {}, ...
                                'Amp_hr', {}, 'Watt_hr', {}, ...
                                'Amps', {}, 'Volts', {});
            for i = 1:totalRows
                tempStruct = data.getRow(i);
                obj.rowInfo(i) = tempStruct;
            end
        end

    

        function obj = fminconTest(obj)
            data = obj.rowInfo;
            t = data.TestTime;
            I = data.Amps;
            V_meas = data.Volts;
            S = obj.SOC;
                        
            % 初始猜测
            param0 = [0, mean(V_meas), 0.01, 0.01, 100, 0];  % [OCV1, OCV2, R0, R1, tau1, V_RC_init]
        
            % 参数边界
            lb = [-10, 3, 0, 0, 1, -5];    % 下界
            ub = [10, 4.2, 0.1, 0.1, 1000, 5];  % 上界
        
            % 等式约束（初始时刻电压一致）
            Aeq = [S(1), 1, -I(1), 0, 0, -1];
            beq = V_meas(1);
        
            % 优化选项
            options = optimset('Display', 'iter', 'MaxIter', 1000);
        
            % 运行 fmincon 优化，使用 obj 调用 compute_RMSE
            [param_opt, fval] = fmincon(@(x) obj.compute_RMSE(x, t, I, V_meas, S), param0, [], [], Aeq, beq, lb, ub, [], options);
        
            % 输出优化结果
            disp('优化后的电池参数:');
            disp(['OCV1: ', num2str(param_opt(1))]);
            disp(['OCV2: ', num2str(param_opt(2))]);
            disp(['R0: ', num2str(param_opt(3))]);
            disp(['R1: ', num2str(param_opt(4))]);
            disp(['tau1: ', num2str(param_opt(5))]);
            disp(['V_RC_init: ', num2str(param_opt(6))]);
            disp(['RMSE: ', num2str(fval)]);
        end
        
      
            % 定义目标函数
            function error = compute_RMSE(obj, x, t, I, V_meas, S)
            % 提取参数
            OCV1 = x(1);    % OCV 与 SOC 的线性关系斜率
            OCV2 = x(2);    % OCV 截距
            R0 = x(3);      % 内阻
            R1 = x(4);      % RC 对电阻
            tau1 = x(5);    % RC 对时间常数
            V_RC_init = x(6); % RC 对初始电压
            
            N = length(t);
            V_RC = zeros(N, 1);  % RC 对电压数组
            V_RC(1) = V_RC_init;
            V_model = zeros(N, 1);  % 模型预测电压数组
            
            % 使用欧拉法计算 V_RC 和 V_model
            for k = 2:N
                dt = t(k) - t(k-1);
                V_RC(k) = V_RC(k-1) + dt * ((I(k-1) * R1 - V_RC(k-1)) / tau1);
                OCV_k = OCV1 * S(k) + OCV2;
                V_model(k) = OCV_k - I(k) * R0 - V_RC(k);
            end
            
            % 初始时刻电压
            OCV_1 = OCV1 * S(1) + OCV2;
            V_model(1) = OCV_1 - I(1) * R0 - V_RC(1);
            
            % 计算均方根误差（RMSE）
            error = sqrt(mean((V_meas - V_model).^2));
        end
    end
end