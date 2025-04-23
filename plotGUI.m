function plotR(app,prec) 
    ax = app.UIAxes;
    
    cla(ax, 'reset');
    

    all_soc = [];
    all_ocv = [];
    for k = 1:length(prec.SOC_Windows)
        window = prec.SOC_Windows(k);
        soc = linspace(window.range_lower, window.range_upper, 100);
        ocv = window.oth(1) * soc + window.oth(2);
        all_soc = [all_soc, soc];
        all_ocv = [all_ocv, ocv];
    end
    [sorted_soc, idx] = sort(all_soc);
    sorted_ocv = all_ocv(idx);

    num_windows = length(prec.SOC_Windows);
    X_stairs = zeros(1, 2 * num_windows);
    Y_stairs = zeros(1, 2 * num_windows);
    for k = 1:num_windows
        window = prec.SOC_Windows(k);
        X_stairs(2*k-1:2*k) = [window.range_lower, window.range_upper];
        Y_stairs(2*k-1:2*k) = [window.oth(3), window.oth(3)];
    end

    yyaxis(ax, 'left');
    plot(ax, sorted_soc, sorted_ocv, 'b-', 'LineWidth', 1.5);
    ylabel(ax, 'OCV (V)');
    
    yyaxis(ax, 'right');
    stairs(ax, X_stairs, Y_stairs, 'r-', 'LineWidth', 1.5);
    ylabel(ax, 'R0 (Ohm)');

    xlabel(ax, 'SOC (%)');
    title(ax, 'OCV and R0 vs SOC');
    legend(ax, {'OCV', 'R0'}, 'Location', 'best');
    
    axis(ax, 'tight');
end