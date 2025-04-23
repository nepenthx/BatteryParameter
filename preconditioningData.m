%预处理实验数据，获取必要的数据
%划分SOC窗口，并且根据窗口分别计算数据
%需要计算SOC，用安时积分
classdef preconditioningData
properties
    SOC_Status
    SOC_Windows

    MovingWindowSOC % 新增：存储滑动窗口中心SOC
    MovingWindowR0  % 新增：存储滑动窗口计算的R0
    RawData         % 新增：存储原始数据引用，方便访问
    R0Lookup
end
methods

    function obj = init(obj, data)
        obj.RawData = data; % 存储原始数据引用
        obj = obj.calculateSoc(data);

       
        obj = obj.getSOCWindows(data); % 保留用于其他参数识别

        window_width = config.getInstance().Moving_SOC_Window_Width;
        step_size = config.getInstance().Moving_SOC_Window_Step;   
        r0_threshold = config.getInstance().R0_Threshold; % 获取R0计算参数
        r0_avg_points = config.getInstance().R0_AvgPoints; % 获取R0计算参数

        obj = obj.calculateMovingWindowR0(window_width, step_size, r0_threshold, r0_avg_points);

        valid_indices = ~isnan(obj.MovingWindowR0) & ~isnan(obj.MovingWindowSOC);
        soc_pts = obj.MovingWindowSOC(valid_indices);
        r0_pts = obj.MovingWindowR0(valid_indices);

        [unique_soc_pts, ia, ic] = unique(soc_pts);
        unique_r0_pts = accumarray(ic, r0_pts, [], @mean); % Average R0 for duplicate SOCs

        if length(unique_soc_pts) < 2
            error('Need at least two valid, unique R0 points to create an interpolator.');
        end

        R0_lookup_function = @(soc_query) interp1(unique_soc_pts, unique_r0_pts, ...
            max(min(soc_query, max(unique_soc_pts)), min(unique_soc_pts)), 'linear', 'extrap');
            

        % --- You now have 'R0_lookup_function' ready to be used ---
        % You might store it in the preconditioningData object:
         obj.R0Lookup = R0_lookup_function;
         for i = 1:length(obj.SOC_Windows)
            block = obj.SOC_Windows(i);
            center_soc = (block.range_lower + block.range_upper) / 2; 
            block.R0 = obj.R0Lookup(center_soc); 
            obj.SOC_Windows(i) = block; 
        end
    end
    function obj = calculateSoc(obj,data) 
        SOC0 = config.getInstance().SOC0; 
        capacity = config.getInstance().C0; 
    
        time = data.TestTime;
        current = data.Amps; 
    
        dt = diff(time)/3600; 
        SOC = SOC0; 
        SOC_List = zeros(size(time));
        SOC_List(1) = SOC;
    
        for k = 2:length(time)
            delta_Q = current(k-1) * dt(k-1); 
            
            SOC = SOC - (delta_Q / capacity) * 100; 
            %SOC = max(0, min(SOC, 100));
            SOC_List(k) = SOC;
        end

        max_value=max(SOC_List);
        temp_value=max_value-100;
        for k = 1:length(SOC_List)
            SOC_List(k)=max(0,SOC_List(k)-temp_value);
        end
        obj.SOC_Status = SOC_List();
    end


    function obj = getSOCWindows(obj, data)
        window_size = config.getInstance().SOC_Window_Granularity;
        soc_edges = 0:window_size:100;
        
        num_windows = length(soc_edges) - 1;
        obj.SOC_Windows = repmat(soc_block(), 1, num_windows);
        for i = 1:num_windows
            lower = soc_edges(i);
            upper = soc_edges(i+1);
            
            current_window = soc_block(lower, upper);
            
            if i == num_windows
                mask = (obj.SOC_Status >= lower) & (obj.SOC_Status <= upper);
            else
                mask = (obj.SOC_Status >= lower) & (obj.SOC_Status < upper);
            end
            current_window.indices = find(mask);            
            current_window.SOC = obj.SOC_Status(current_window.indices); 
            obj.SOC_Windows(i) = current_window;
        end
    end

    function obj = calculateMovingWindowR0(obj, window_width, step_size, threshold, avg_points)
        if isempty(obj.SOC_Status) || isempty(obj.RawData)
            error('SOC_Status or RawData is empty. Run calculateSoc first and ensure RawData is stored.');
        end
        if window_width <= 0 || step_size <= 0
            error('Window width and step size must be positive.');
        end

        soc_centers = [];
        r0_values = [];

        min_soc = window_width / 2;
        max_soc = 100 - window_width / 2;

        if min_soc > max_soc % 处理窗口过大的情况
           warning('Window width is too large for the SOC range.');
           obj.MovingWindowSOC = [];
           obj.MovingWindowR0 = [];
           return;
        end

        current_center_soc = min_soc;

        all_currents = obj.RawData.Amps; 
        all_voltages = obj.RawData.Volts; 

        while current_center_soc <= max_soc
            lower_soc = max(0, current_center_soc - window_width / 2);
            upper_soc = min(100, current_center_soc + window_width / 2);

            % 找到当前窗口内的索引
            mask = (obj.SOC_Status >= lower_soc) & (obj.SOC_Status < upper_soc);
            % 对最后一个可能的中心点，包含上限
            if abs(current_center_soc - max_soc) < step_size / 2
                mask = (obj.SOC_Status >= lower_soc) & (obj.SOC_Status <= upper_soc);
            end
            indices = find(mask);

            if length(indices) >= 2 * avg_points + 1 % 确保有足够数据点计算R0
                % 提取当前窗口的电压和电流
                window_currents = all_currents(indices);
                window_voltages = all_voltages(indices);

                % 调用静态R0计算函数
                current_r0 = preconditioningData.staticCalculateR0(window_currents, window_voltages, threshold, avg_points);

                if ~isnan(current_r0)
                    soc_centers = [soc_centers; current_center_soc];
                    r0_values = [r0_values; current_r0];
                else
                     fprintf('Warning: R0 calculation failed for SOC center %.2f%% (Window [%.2f%%, %.2f%%])\n', ...
                             current_center_soc, lower_soc, upper_soc);
                end
            else
                fprintf('Warning: Not enough data points (%d) for SOC center %.2f%% (Window [%.2f%%, %.2f%%])\n', ...
                        length(indices), current_center_soc, lower_soc, upper_soc);
            end

            % 移动到下一个窗口中心
            current_center_soc = current_center_soc + step_size;

            % 确保最后一个点被计算（如果步长不能整除）
             if current_center_soc > max_soc && abs(current_center_soc - step_size - max_soc) > 1e-6 % 检查是否刚超过但之前没算到max_soc
                current_center_soc = max_soc; % 强制计算最后一个中心点
                 % 重复上面的查找和计算逻辑... (可以封装成一个内部函数避免重复)
                 lower_soc = max(0, current_center_soc - window_width / 2);
                 upper_soc = min(100, current_center_soc + window_width / 2);
                 mask = (obj.SOC_Status >= lower_soc) & (obj.SOC_Status <= upper_soc); % 包含上限
                 indices = find(mask);
                 if length(indices) >= 2 * avg_points + 1
                     window_currents = all_currents(indices);
                     window_voltages = all_voltages(indices);
                     current_r0 = preconditioningData.staticCalculateR0(window_currents, window_voltages, threshold, avg_points);
                     if ~isnan(current_r0)
                         % 检查是否已经添加过这个中心点 (避免因浮点数误差重复添加)
                         if isempty(soc_centers) || abs(soc_centers(end) - current_center_soc) > 1e-6
                             soc_centers = [soc_centers; current_center_soc];
                             r0_values = [r0_values; current_r0];
                         end
                     else
                          fprintf('Warning: R0 calculation failed for SOC center %.2f%% (Window [%.2f%%, %.2f%%])\n', ...
                                  current_center_soc, lower_soc, upper_soc);
                     end
                 else
                      fprintf('Warning: Not enough data points (%d) for SOC center %.2f%% (Window [%.2f%%, %.2f%%])\n', ...
                              length(indices), current_center_soc, lower_soc, upper_soc);
                 end
                 break; % 计算完最后一个点后退出循环
             end
        end

        obj.MovingWindowSOC = soc_centers;
        obj.MovingWindowR0 = r0_values;
        fprintf('Calculated R0 for %d moving windows.\n', length(soc_centers));
    end

    function plotSmoothedR0(obj, method)
        if nargin < 2
            method = 'spline'; % 默认使用样条插值
        end
    
        if isempty(obj.MovingWindowSOC) || isempty(obj.MovingWindowR0)
            disp('No moving window R0 data to plot.');
            return;
        end
    
        valid_indices = ~isnan(obj.MovingWindowR0);
        soc_points = obj.MovingWindowSOC(valid_indices);
        r0_points = obj.MovingWindowR0(valid_indices);
    
        if length(soc_points) < 2 
            disp('Not enough valid R0 points for interpolation.');
            figure;
            scatter(soc_points, r0_points, 'filled');
            xlabel('SOC (%)');
            ylabel('R0 (Ohm)');
            title('Calculated R0 Points (Moving Window)');
            grid on;
            return;
        end
    
       
        soc_fine = linspace(min(soc_points), max(soc_points), 200);
    
 
        r0_smooth = interp1(soc_points, r0_points, soc_fine, method);
    
        % 绘图
        figure;
        scatter(soc_points, r0_points, 'b', 'filled', 'DisplayName', 'Calculated R0 Points');
        hold on;
        plot(soc_fine, r0_smooth, 'r-', 'LineWidth', 1.5, 'DisplayName', ['Smoothed R0 (', method, ')']);
        hold off;
        xlabel('SOC (%)');
        ylabel('R0 (Ohm)');
        title('R0 vs SOC ');
        legend show;
        grid on;
    end
end

methods (Static)
    function R0 = staticCalculateR0(currents, voltages, threshold, avg_points)
        if nargin < 3 || isempty(threshold)
            threshold = 0.5;
        end
        if nargin < 4 || isempty(avg_points)
            avg_points = 3;
        end

        currents = currents(:)'; % 确保是行向量
        voltages = voltages(:)'; % 确保是行向量
        N = length(currents);

        if N < 2 * avg_points + 1
            R0 = NaN;
            % disp("错误：该窗口数据点不足，无法计算 R0"); % 在调用处处理或记录
            return;
        end

        R0_values = [];
        for i = avg_points + 1 : N - avg_points
            delta_I_step = currents(i) - currents(i - 1); % 检测跳变点

            if abs(delta_I_step) > threshold
                % 取跳变前后 avg_points 个点的平均值
                I_before = mean(currents(i - avg_points : i - 1));
                V_before = mean(voltages(i - avg_points : i - 1));
                I_after = mean(currents(i : i + avg_points - 1)); % 注意这里是 i 到 i+avg_points-1
                V_after = mean(voltages(i : i + avg_points - 1));

                delta_I = I_after - I_before;
                delta_V = V_after - V_before;

                if delta_I ~= 0
                    r_val = abs(delta_V / delta_I);
                    
                    if r_val > 0 && r_val < 1 
                       R0_values = [R0_values; r_val];
                    end
                end
            end
        end

        if ~isempty(R0_values)
            R0_values = rmoutliers(R0_values, 'percentiles', [10 90]); % 使用百分位数移除异常值可能更稳健
            if ~isempty(R0_values)
               R0 = mean(R0_values);
            else
               R0 = NaN; % 移除异常值后可能为空
            end
        else
            R0 = NaN;
            % disp("未检测到有效跳变点或计算出的R0值无效");
        end
    end
end
end