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
    V_actual    = [];
    V_predicted = [];
    
    for k = 1:length(prec.SOC_Windows)
        window = prec.SOC_Windows(k);
        if isempty(window.rowInfo) || window.skip
            continue;
        end
        
        t      = [window.rowInfo.TestTime]';
        I      = [window.rowInfo.Amps]';
        S      = window.SOC';
        V_meas = [window.rowInfo.Volts]';
        
        try
            V_model = window.predict(window.oth, t, I, S);
        catch
            continue;
        end
        
        V_actual    = [V_actual;    V_meas];
        V_predicted = [V_predicted; V_model];
    end
    
    if isempty(V_actual)
        error('无有效数据可用于验证');
    end
    
    % —— 计算 RMSE —— 
    rmse = sqrt( mean( (V_actual - V_predicted).^2 ) );
    fprintf('全局电压预测 RMSE: %.4f V\n', rmse);
    
    % —— 绘图 —— 
    figure;
    plot(V_actual,    'b',  'DisplayName','实际电压');
    hold on;
    plot(V_predicted, 'r--','DisplayName','预测电压');
    xlabel('数据点序号');
    ylabel('电压 (V)');
    legend;
    title(sprintf('实际 vs 预测 电压 (RMSE=%.4f V)', rmse));
end
