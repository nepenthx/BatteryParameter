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
            % 1) 先把 rowInfo 解包
            data   = obj.rowInfo;
            t      = [data.TestTime]';    % 时间
            I_raw  = [data.Amps]';        % 正=放电，负=充电
            V_meas = [data.Volts]';       % 电压
            S      = obj.SOC(:);          % SOC
        
            % 2) 构造幅值&符号向量
            I_mag  = abs(I_raw);
            I_mag  = I_mag(:);
            I_sign = sign(I_raw);
            I_sign = I_sign(:);
        
            % 3) 长度校验
            if ~isequal(length(t), length(I_raw), length(V_meas), length(S))
                error('输入长度不一致: t=%d, I=%d, V=%d, S=%d', ...
                    length(t), length(I_raw), length(V_meas), length(S));
            end
        
            % 4) 初始化 param0, lb, ub
            if isnan(obj.R0)
                param0 = [0.001, 3.5,    0.01, 1, 10, 0];
                lb     = [0,     0,      0,    0.01, 0,  -4.2];
                ub     = [Inf,   Inf,    1,    1,    50, 4.2];
            else
                param0 = [0.001, mean(V_meas), obj.R0, 0.01, 10, 0];
                lb     = [0.002, 2.7, obj.R0, 0.01,    0,   -4.2];
                ub     = [0.015, 4.2, obj.R0, 1,       50,  4.2];
            end
        
            % 5) 检查并调整边界
            for i = 1:numel(lb)
                if lb(i) > ub(i)
                    ub(i) = lb(i) + 1e-6;
                    warning('窗口 [%.1f–%.1f%%] 边界 %d 自动调整', ...
                        obj.range_lower, obj.range_upper, i);
                end
            end
        
            % 6) 线性不等式约束 A, b
            if obj.range_upper < 100
                A = [-(obj.range_lower+obj.range_upper)/2, -1, 0,0,0,0;
                      (obj.range_lower+obj.range_upper)/2,  1, 0,0,0,0];
                b = [-2.7; prev_Vmean];
            else
                A = [-(obj.range_lower+obj.range_upper)/2, -1, 0,0,0,0;
                      (obj.range_lower+obj.range_upper)/2,  1, 0,0,0,0];
                b = [-2.7; 4.2];
            end
        
            % 7) 线性等式约束 Aeq, beq （用 I_raw(1)）
            I0_raw  = I_raw(1);
            I0_mag  = abs(I0_raw);
            I0_sign = sign(I0_raw);
            Aeq = [ S(1), 1, -I0_sign*I0_mag, 0, 0, -1 ];
            beq = V_meas(1);
        
            % 8) 调用 fmincon
            options = optimoptions('fmincon','Display','iter','MaxIterations',500);
            try
                [param_opt, ~, exitflag] = fmincon( ...
                    @(x) obj.compute_RMSE(x, t, I_raw, V_meas, S), ...
                    param0, A, b, Aeq, beq, lb, ub, [], options);
                if exitflag <= 0
                    warning('窗口 [%.1f–%.1f%%] 优化失败 (exitflag=%d)', ...
                        obj.range_lower, obj.range_upper, exitflag);
                    obj.skip = 1;
                    return;
                end
            catch ME
                warning('窗口 [%.1f–%.1f%%] fmincon 异常: %s', ...
                    obj.range_lower, obj.range_upper, ME.message);
                obj.skip = 1;
                return;
            end
        
            % 9) 存回结果
            obj.oth = param_opt;
            obj.R0  = param_opt(3);
        end

        function V_model = predict(obj, params, t,  I_raw , S)
            t = t(:);   
            I_mag  = abs(I_raw(:));
            I_sign = sign(I_raw(:));
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
                dV_RC = (I_mag(k-1)*R1 - V_RC(k-1)) / tau1;
                V_RC(k) = V_RC(k-1) + dt*dV_RC;
            end

            OCV = OCV1 * S + OCV2;  
            % —— 用 sign 恢复方向 —— 
            V_model = OCV - I_sign.*(I_mag*R0) - V_RC;
        end
        
        function error = compute_RMSE(obj, x, t, I_raw, V_meas, S)
            OCV1 = x(1);
            OCV2 = x(2);
            R0 = x(3);
            R1 = x(4);
            tau1 = x(5);
            V_RC_init = x(6);
            I_mag  = abs(I_raw(:));
            I_sign = sign(I_raw(:));
            N = length(t);
            V_RC = zeros(N,1);
            for k = 2:N
                dt = t(k)-t(k-1);
                V_RC(k) = V_RC(k-1) + dt * ((I_mag(k-1)*R1 - V_RC(k-1)) / tau1);
            end
        
            OCV   = x(1)*S + x(2);
            % —— 恢复方向 —— 
            V_model = OCV - I_sign.*(I_mag * x(3)) - V_RC;
            error   = sqrt(mean((V_meas - V_model).^2));
        end
    end
end