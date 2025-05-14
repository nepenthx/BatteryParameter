
function guiRun(app)
data=LoadData;
prec = preconditioningData;
prec = prec.init(data);
prev_Vmean = 0; 
for k = 1:length(prec.SOC_Windows)

    prec.SOC_Windows(k) = prec.SOC_Windows(k).getAllRow(data);
    prec.SOC_Windows(k) = prec.SOC_Windows(k).fminconTest(prev_Vmean);
    if(prec.SOC_Windows(k).skip == 1)
        continue;
    end
    volt_temp=prec.SOC_Windows(k).rowInfo.Volts;
    prev_Vmean = min(volt_temp);
end
post=postProcessing;
post=post.init(prec);
verifyModel(prec,post, data,app);

end
function rmse = verifyModel(prec,post, data,app)
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
    

    OCV_lookup_function = post.OCVLookup;
    R0_lookup_function = post.R0Lookup;
    R1_lookup_function = post.R1Lookup;
    tau1_lookup_function = post.Tau1Lookup;
    for k = 1:length(t)
        soc = S(k);
       
        OCV= OCV_lookup_function(soc);
        R0 = R0_lookup_function(soc);
        R1 = R1_lookup_function(soc);
        tau1 = tau1_lookup_function(soc);
        if k>1
            dt = t(k)-t(k-1);   
            dV_RC = (I(k-1)*R1 - V_RC) / tau1;
            V_RC =  V_RC + dt * dV_RC;
        end
        V_predicted(k) = OCV - sign(data.Amps(k))*(I(k)*R0) - V_RC;
    end

    rmse = sqrt(mean((V_actual - V_predicted).^2));
    fprintf('全局电压预测 RMSE: %.4f V\n', rmse);

    cla(app.UIAxes_volt);

    plot(app.UIAxes_volt, t, V_actual, 'b', 'DisplayName', '实际电压');
    hold(app.UIAxes_volt, 'on');
    plot(app.UIAxes_volt, t, V_predicted, 'r--', 'DisplayName', '预测电压');
    hold(app.UIAxes_volt, 'off');
    legend(app.UIAxes_volt, 'show');

    plotGUI(app,post); 
end