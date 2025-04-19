classdef CustomOutputStream < handle
    properties (Hidden)
        OutputStream  % Java OutputStream 对象
    end
    
    methods
        function obj = CustomOutputStream(textArea)
            % 创建 Java 适配器
            import com.mathworks.mlservices.MatlabOutputServices;
            obj.OutputStream = MatlabOutputServices.getOutputStream();
            
            % 重定向到文本区域
            addlistener(obj, 'DataWritten', @(src,evt) appendText(textArea, evt.Data));
        end
        
        function write(obj, data)
            % 触发事件
            notify(obj, 'DataWritten', data);
        end
    end
    
    events
        DataWritten  % 自定义事件
    end
end

function appendText(textArea, data)
    % 更新 GUI 组件
    textArea.Value = [textArea.Value; {char(data)}];
    scroll(textArea, 'bottom');
end