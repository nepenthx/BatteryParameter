
function plotR(prec) 
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

    figure;
    plot(sorted_soc, sorted_ocv, 'b-', 'LineWidth', 1.5);
    xlabel('SOC (%)');
    ylabel('OCV (V)');
    title('OCV vs SOC');
    grid on;

    X_stairs = [];
    Y_stairs = [];
    for k = 1:length(prec.SOC_Windows)
        window = prec.SOC_Windows(k);
        X_stairs = [X_stairs, window.range_lower, window.range_upper];
        Y_stairs = [Y_stairs, window.oth(3), window.oth(3)];
    end

    figure;
    stairs(X_stairs, Y_stairs, 'r-', 'LineWidth', 1.5);
    xlabel('SOC (%)');
    ylabel('R0 (Ohm)');
    title('R0 vs SOC');
    grid on;

    figure;
    yyaxis left;
    plot(sorted_soc, sorted_ocv, 'b-', 'LineWidth', 1.5);
    ylabel('OCV (V)');

    yyaxis right;
    stairs(X_stairs, Y_stairs, 'r-', 'LineWidth', 1.5);
    ylabel('R0 (Ohm)');

    xlabel('SOC (%)');
    title('OCV and R0 vs SOC');
    grid on;
end