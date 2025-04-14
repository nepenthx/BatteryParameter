t = [prec.SOC_Windows(13).rowInfo.TestTime]';
dt = diff(t);
fprintf('SOC 窗口 [60%%-65%%] dt 范围: [%.2f, %.2f] 秒\n', min(dt), max(dt));
if any(dt <= 0)
    warning('TestTime 不单调递增');
end