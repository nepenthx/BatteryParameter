classdef soc_block
    properties
        range_lower      
        range_upper     
        indices         % 属于该窗口的原始数据索引
        R0              
        oth             
    end
    
    methods
        function obj = soc_block(lower, upper)
            if nargin == 0
                obj.range_lower = 0;
                obj.range_upper = 0;
            else
                obj.range_lower = lower;
                obj.range_upper = upper;
            end
            obj.indices = [];
            obj.R0 = NaN;
        end
    end
end