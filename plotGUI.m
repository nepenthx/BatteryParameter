function plotGUI(app, post)
    
    SOC = 1:100;
    OCV = post.OCVLookup(SOC);
    R0 = post.R0Lookup(SOC);
    R1 = post.R1Lookup(SOC);
    C1 = post.Tau1Lookup(SOC) ./ R1;  % 使用逐元素除法

    % OCV 曲线保持不变
    cla(app.UIAxes_OCV);
    plot(app.UIAxes_OCV, SOC, OCV, 'b-', 'LineWidth', 1.5);
    xlabel(app.UIAxes_OCV, 'SOC (%)');
    ylabel(app.UIAxes_OCV, 'OCV (V)');
    title(app.UIAxes_OCV, 'OCV vs SOC');
    grid(app.UIAxes_OCV, 'on');

    % 合并 R0 和 R1 到同一个坐标系
    cla(app.UIAxes_R0);
    hold(app.UIAxes_R0, 'on');
    plot(app.UIAxes_R0, SOC, R0, 'r-', 'LineWidth', 1.5);
    plot(app.UIAxes_R0, SOC, R1, 'g-', 'LineWidth', 1.5);
    hold(app.UIAxes_R0, 'off');
    xlabel(app.UIAxes_R0, 'SOC (%)');
    ylabel(app.UIAxes_R0, 'Resistance (Ohm)');
    title(app.UIAxes_R0, 'R0 and R1 vs SOC');
    legend(app.UIAxes_R0, {'R0', 'R1'});
    grid(app.UIAxes_R0, 'on');

    % 在原R1位置显示C1
    cla(app.UIAxes_R1);
    plot(app.UIAxes_R1, SOC, C1, 'm-', 'LineWidth', 1.5);
    xlabel(app.UIAxes_R1, 'SOC (%)');
    ylabel(app.UIAxes_R1, 'C1 (F)');
    title(app.UIAxes_R1, 'C1 vs SOC');
    grid(app.UIAxes_R1, 'on');

end