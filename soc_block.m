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
            obj.SOC = obj.SOC(:); 

        end

        function obj = fminconTest(obj, prev_Vmean)
            data = obj.rowInfo;
            t = [data.TestTime]';
            I = [data.Amps]';
            V_meas = [data.Volts]';
            S = obj.SOC;
            
            t = t(:);
            I = I(:);
            V_meas = V_meas(:);
            S = obj.SOC(:);   
           
            if ~isequal(length(t), length(I), length(V_meas), length(S))
                error('输入数据长度不一致: t=%d, I=%d, V_meas=%d, S=%d',...
                    length(t), length(I), length(V_meas), length(S));
            end
            
            % 初始化参数和约束
            if isnan(obj.R0)
                param0 = [0.001, 3.5, 0.01, 1, 10, 0]; 
                lb = [0,0, 0, 0.01, 0,   -4.2]; 
                ub = [Inf,Inf,1,1,   50, 4.2]; 
            else
                param0 = [0.001, mean(V_meas), obj.R0, 0.01, 10, 0];
                lb = [0.002, 2.7, obj.R0, 0.01,     0,   -4.2]; 
                ub = [0.015,  4.2, obj.R0, 1, 50, 4.2]; 
            end
            
            for i = 1:length(lb)
                if lb(i) > ub(i)
                    ub(i) = lb(i) + 1e-6; % 微小偏移避免数值问题
                    warning('调整窗口 [%.1f%%-%.1f%%] 参数 %d 的边界: lb=%.3f, ub=%.3f', ...
                        obj.range_lower, obj.range_upper, i, lb(i), ub(i));
                end
            end
            if(obj.range_upper<100)
            % 线性约束：OCV(SOC=0) >=2.7 且 OCV(SOC=100) <=4.2
                A = [-(obj.range_lower+obj.range_upper)/2, -1, 0, 0, 0, 0;       % OCV2 >=2.7
                (obj.range_lower+obj.range_upper)/2, 1, 0, 0, 0, 0];   % -OCV1*S_j - OCV2 <= - max V(S_j(ii-1))     OCV(i)>OCV(ii-1)>V(ii-1) . (保证单调性)
                b = [-2.7;prev_Vmean];
            else
                A = [-(obj.range_lower+obj.range_upper)/2, -1, 0, 0, 0, 0;       % OCV2 >=2.7
                (obj.range_lower+obj.range_upper)/2, 1, 0, 0, 0, 0];  % 100*OCV1 + OCV2 <=4.2
                b = [-2.7; 4.2];
            end
            % 初始条件约束
            Aeq = [S(1), 1, -I(1), 0, 0, -1];
            beq = V_meas(1);
            
            options = optimoptions('fmincon', 'display', 'iter', 'MaxIterations', 500);
            try
                [param_opt, ~, exitflag] = fmincon(@(x) obj.compute_RMSE(x, t, I, V_meas, S), ...
                    param0, A, b, Aeq, beq, lb, ub, [], options);
                
                if exitflag <= 0
                    warning('窗口 [%.1f%%-%.1f%%] 优化失败，退出标志: %d', ...
                        obj.range_lower, obj.range_upper, exitflag);
                    obj.skip = 1;
                    return;
                end
            catch ME
                warning('窗口 [%.1f%%-%.1f%%] 优化异常: %s', ...
                    obj.range_lower, obj.range_upper, ME.message);
                obj.skip = 1;
                return;
            end
            
            obj.oth = param_opt;
            obj.R0 = param_opt(3); % 更新R0
        end

        function V_model = predict(obj, params, t, I, S)
            t = t(:);
            I = I(:);
            S = S(:); 
            
            OCV1 = params(1);
            OCV2 = params(2);
            R0 = params(3);
            R1 = params(4);
            tau1 = params(5);
            V_RC_init = params(6);
            
            N = length(t);
            V_RC = zeros(N, 1);
            V_RC(1) = V_RC_init;
            
            for k = 2:N
                dt = t(k) - t(k-1);
                dV_RC = (I(k-1)*R1 - V_RC(k-1)) / tau1;
                V_RC(k) = V_RC(k-1) + dt * dV_RC;
            end
            
            OCV = OCV1 * S + OCV2;  
            V_model = OCV - I .* R0 - V_RC; 
            
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
                if dt <= 0
                    % 直接保持上一个分量，或者丢弃这一点
                    V_RC(k) = V_RC(k-1);
                    continue;
                end
                V_RC(k) = V_RC(k-1) + dt * ((I(k-1)*R1 - V_RC(k-1)) / tau1);
            end
            
            OCV = OCV1 * S + OCV2;
            V_model = OCV - I.*R0 - V_RC;
            
            error = sqrt(mean((V_meas - V_model).^2));
        end
    end
end