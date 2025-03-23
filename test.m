% 示例数据
data = LoadData;
t = data.TestTime;
I = data.Amps;
V_meas = data.Volts;
prec = preconditioningData;
prec = prec.calculateSoc(data);
S = prec.SOC_Status;

% 初始猜测
param0 = [0, mean(V_meas), 0.01, 0.01, 100, 0];  % [OCV1, OCV2, R0, R1, tau1, V_RC_init]

% 参数边界
lb = [-10, 3, 0, 0, 1, -5];    % 下界
ub = [10, 4.2, 0.1, 0.1, 1000, 5];  % 上界

% 等式约束（初始时刻电压一致）
Aeq = [S(1), 1, -I(1), 0, 0, -1];
beq = V_meas(1);

% 优化选项（使用 optimset）
options = optimset('Display', 'iter', 'MaxIter', 1000);

% 运行 fmincon 优化
[param_opt, fval] = fmincon(@(x) compute_RMSE(x, t, I, V_meas, S), param0, [], [], Aeq, beq, lb, ub, [], options);

% 输出优化结果
disp('优化后的电池参数:');
disp(['OCV1: ', num2str(param_opt(1))]);
disp(['OCV2: ', num2str(param_opt(2))]);
disp(['R0: ', num2str(param_opt(3))]);
disp(['R1: ', num2str(param_opt(4))]);
disp(['tau1: ', num2str(param_opt(5))]);
disp(['V_RC_init: ', num2str(param_opt(6))]);
disp(['RMSE: ', num2str(fval)]);

% 定义目标函数
function error = compute_RMSE(x, t, I, V_meas, S)
    % 提取参数
    OCV1 = x(1);    % OCV 与 SOC 的线性关系斜率
    OCV2 = x(2);    % OCV 截距
    R0 = x(3);      % 内阻
    R1 = x(4);      % RC 对电阻
    tau1 = x(5);    % RC 对时间常数
    V_RC_init = x(6); % RC 对初始电压
    
    N = length(t);
    V_RC = zeros(N, 1);  % RC 对电压数组
    V_RC(1) = V_RC_init;
    V_model = zeros(N, 1);  % 模型预测电压数组
    
    % 使用欧拉法计算 V_RC 和 V_model
    for k = 2:N
        dt = t(k) - t(k-1);
        V_RC(k) = V_RC(k-1) + dt * ((I(k-1) * R1 - V_RC(k-1)) / tau1);
        OCV_k = OCV1 * S(k) + OCV2;
        V_model(k) = OCV_k - I(k) * R0 - V_RC(k);
    end
    
    % 初始时刻电压
    OCV_1 = OCV1 * S(1) + OCV2;
    V_model(1) = OCV_1 - I(1) * R0 - V_RC(1);
    
    % 计算均方根误差（RMSE）
    error = sqrt(mean((V_meas - V_model).^2));
end