data=LoadData;
prec = preconditioningData;
prec = prec.init(data);
prev_Vmean = Inf; 
for k = length(prec.SOC_Windows):-1:1
    prec.SOC_Windows(k) = prec.SOC_Windows(k).getAllRow(data);
    prec.SOC_Windows(k) = prec.SOC_Windows(k).fminconTest(prev_Vmean);
    if(prec.SOC_Windows(k).skip == 1)
        continue;
    end
    volt_temp=prec.SOC_Windows(k).rowInfo.Volts;
    prev_Vmean = min(volt_temp);
end

    verifyModel(prec, data);


% 或者如果 R0_lookup_function 是一个独立变量:
% verifyModel(prec, data, R0_lookup_function);

function rmse = verifyModel(prec, data)
    t = data.TestTime;    % 时间序列
    I_raw = [data.Amps]';
    I = abs(I_raw);
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
            warning('SOC %.2f%% 没有对应的参数', soc);
            continue
        end
        OCV1 = window.oth(1);
        OCV2 = window.oth(2);
        R0 = window.oth(3);
        R1 = window.oth(4);
        tau1 = window.oth(5);

        OCV = OCV1 * soc + OCV2;

        if k>1
            dt = t(k)-t(k-1);   
            dV_RC = (I(k-1)*R1 - V_RC) / tau1;
            V_RC = V_RC + dt * dV_RC;
        end
        V_predicted(k) = OCV - sign(data.Amps(k))*(I(k)*R0) - V_RC;
    end

    rmse = sqrt(mean((V_actual - V_predicted).^2));
    fprintf('全局电压预测 RMSE: %.4f V\n', rmse);

    cla(app.UIAxes_2);

    plot(app.UIAxes_2, t, V_actual, 'b', 'DisplayName', '实际电压');
    hold(app.UIAxes_2, 'on');
    plot(app.UIAxes_2, t, V_predicted, 'r--', 'DisplayName', '预测电压');
    hold(app.UIAxes_2, 'off');
    legend(app.UIAxes_2, 'show');

    plotGUI(app,prec); 
end