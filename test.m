% 生成所有窗口的SOC和OCV数据
all_soc = [];
all_ocv = [];
for k = 1:length(prec.SOC_Windows)
    window = prec.SOC_Windows(k);
    soc = linspace(window.range_lower, window.range_upper, 100); % 生成100个点
    ocv = window.oth(1) * soc + window.oth(2); % OCV0*SOC + OCV1
    all_soc = [all_soc, soc];
    all_ocv = [all_ocv, ocv];
end

% 按SOC排序
[sorted_soc, idx] = sort(all_soc);
sorted_ocv = all_ocv(idx);

% 绘制OCV曲线
figure;
plot(sorted_soc, sorted_ocv, 'b-', 'LineWidth', 1.5);
xlabel('SOC (%)');
ylabel('OCV (V)');
title('OCV vs SOC');
grid on;

