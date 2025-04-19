function guiRun(app)
cfg = config.getInstance();
cfg.openLog=true;
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

verifyModel(app,prec, data);

end
function rmse = verifyModel(app,prec,data)
    % 获取原始数据
    t = data.TestTime;    % 时间序列
    I = data.Amps;        % 电流
    V_actual = data.Volts; % 实际电压
    S = prec.SOC_Status;   % SOC

    % 检查数据长度一致性
    if length(S) ~= length(t)
        app.log('error:SOC_Status长度 (%d) 与数据行数 (%d) 不匹配', length(S), length(t));
        error();
    end

    % 初始化预测电压数组
    V_predicted = zeros(size(V_actual));
    V_RC = 0; % 初始 V_RC，设为 0，可根据需要调整

    % 按时间顺序遍历
    for k = 1:length(t)
        soc = S(k);
        % 找到对应的 SOC 窗口
        window_idx = find([prec.SOC_Windows.range_lower] <= soc & ...
                          [prec.SOC_Windows.range_upper] >= soc, 1);
        if isempty(window_idx)
            app.log('error:SOC %.2f%% 超出窗口范围', soc);
            error();
        end
        window = prec.SOC_Windows(window_idx);

        % 获取参数
        if isempty(window.oth)
            app.log('SOC %.2f%% 没有对应的参数', soc);
            error();
        end
        OCV1 = window.oth(1);
        OCV2 = window.oth(2);
        R0 = window.oth(3);
        R1 = window.oth(4);
        tau1 = window.oth(5);

        % 计算 OCV
        OCV = OCV1 * soc + OCV2;

        % 计算 V_RC（时间递推）
        if k > 1
            dt = t(k) - t(k-1);
            if dt <= 0
                warning('时间步长非正: dt = %.2f s at k = %d', dt, k);
                V_predicted(k) = V_predicted(k-1); % 使用上一时刻值
                continue;
            end
            dV_RC = (I(k-1) * R1 - V_RC) / tau1;
            V_RC = V_RC + dt * dV_RC;
        end

        % 计算预测电压
        V_predicted(k) = OCV - I(k) * R0 - V_RC;
    end

    % 计算 RMSE
    rmse = sqrt(mean((V_actual - V_predicted).^2));
    text="全局电压预测 RMSE:"+rmse;
    app.showResult(text);

    cla(app.UIAxes_2);
    
    % 绘制新图表
    plot(app.UIAxes_2, t, V_actual, 'b', 'DisplayName', '实际电压');
    hold(app.UIAxes_2, 'on');
    plot(app.UIAxes_2, t, V_predicted, 'r--', 'DisplayName', '预测电压');
    hold(app.UIAxes_2, 'off');
    legend(app.UIAxes_2, 'show');

    plotGUI(app,prec); 
end