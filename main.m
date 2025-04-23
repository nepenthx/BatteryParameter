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
    t = data.TestTime;    % 时间序列
    I = data.Amps;        % 电流
    V_actual = data.Volts; % 实际电压
    S = prec.SOC_Status;   % SOC

    if length(S) ~= length(t)
        error('SOC_Status长度 (%d) 与数据行数 (%d) 不匹配', length(S), length(t));
    end

    V_predicted = zeros(size(V_actual));
    V_RC = 0; 
    for k = 1:length(t)
        soc = S(k);
        window_idx = find([prec.SOC_Windows.range_lower] <= soc & ...
                          [prec.SOC_Windows.range_upper] >= soc, 1);
        if isempty(window_idx)
            error('SOC %.2f%% 超出窗口范围', soc);
        end
        window = prec.SOC_Windows(window_idx);

        if isempty(window.oth)
            error('SOC %.2f%% 没有对应的参数', soc);
        end
        OCV1 = window.oth(1);
        OCV2 = window.oth(2);
        R0 = window.oth(3);
        R1 = window.oth(4);
        tau1 = window.oth(5);

        OCV = OCV1 * soc + OCV2;

        if k > 1
            dt = t(k) - t(k-1);
            if dt <= 0
                warning('时间步长非正: dt = %.2f s at k = %d', dt, k);
                V_predicted(k) = V_predicted(k-1); 
                continue;
            end
            dV_RC = (I(k-1) * R1 - V_RC) / tau1;
            V_RC = V_RC + dt * dV_RC;
        end

        V_predicted(k) = OCV - I(k) * R0 - V_RC;
    end

    rmse = sqrt(mean((V_actual - V_predicted).^2));
    fprintf('全局电压预测 RMSE: %.4f V\n', rmse);

figure;
    plot(t, V_actual, 'b', 'DisplayName', '实际电压');
    hold on;
    plot(t, V_predicted, 'r--', 'DisplayName', '预测电压');
    xlabel('时间 (s)');
    ylabel('电压 (V)');
    legend;
    title('实际电压 vs 预测电压');
end