data=LoadData;
prec = preconditioningData;
prec = prec.init(data);
prev_R0 = Inf; 
for k = length(prec.SOC_Windows):-1:1
    prec.SOC_Windows(k) = prec.SOC_Windows(k).getAllRow(data);
    prec.SOC_Windows(k) = prec.SOC_Windows(k).calculateR0();
    prec.SOC_Windows(k) = prec.SOC_Windows(k).fminconTest(prev_R0);
    prev_R0 = prec.SOC_Windows(k).R0; 
end

verifyModel(prec, data);


function rmse = verifyModel(prec, data)
    % ===== 1. 预分配内存 =====
    total_points = 0;
    for k = 1:length(prec.SOC_Windows)
        window = prec.SOC_Windows(k);
        if ~isempty(window.rowInfo) && ~window.skip
            total_points = total_points + length(window.rowInfo);
        end
    end
    
    V_actual = zeros(total_points, 1);
    V_predicted = zeros(total_points, 1);
    ptr = 1; % 当前写入位置指针
    
    % ===== 2. 遍历所有窗口填充数据 =====
    for k = 1:length(prec.SOC_Windows)
        window = prec.SOC_Windows(k);
        if isempty(window.rowInfo) || window.skip
            continue;
        end
        
        t = [window.rowInfo.TestTime]';
        I = [window.rowInfo.Amps]';
        S = window.SOC';
        V_meas = [window.rowInfo.Volts]';
        
        try
            V_model = window.predict(window.oth, t, I, S);
            
            % 严格校验数据长度
            if length(V_model) ~= length(V_meas)
                warning('窗口 %d 预测数据长度不匹配（实际=%d，预测=%d），已跳过', ...
                    k, length(V_meas), length(V_model));
                continue;
            end
        catch ME
            fprintf('窗口 %d 预测失败: %s\n', k, ME.message);
            continue;
        end
        
        % 填充到预分配数组
        n = length(V_meas);
        V_actual(ptr:ptr+n-1) = V_meas;
        V_predicted(ptr:ptr+n-1) = V_model;
        ptr = ptr + n;
    end
    
    % ===== 3. 裁剪未使用的空间 =====
    V_actual = V_actual(1:ptr-1);
    V_predicted = V_predicted(1:ptr-1);
    
    % ===== 4. 计算RMSE =====
    if isempty(V_actual)
        error('无有效数据可用于验证');
    end
    fprintf('实际电压范围: [%.2f V, %.2f V]\n', min(V_actual), max(V_actual));
    fprintf('预测电压范围: [%.2f V, %.2f V]\n', min(V_predicted), max(V_predicted));
    rmse = sqrt(mean((V_actual - V_predicted).^2));
    fprintf('全局电压预测 RMSE: %.4f V\n', rmse);
    
    % ... (绘图部分保持不变)
    figure;
    plot(V_actual, 'b', 'DisplayName', '实际电压');
    hold on;
    plot(V_predicted, 'r--', 'DisplayName', '预测电压');
    xlabel('数据点序号');
    ylabel('电压 (V)');
    legend;
    title('实际电压 vs 模型预测电压');
end