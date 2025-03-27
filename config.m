classdef config < handle 
    properties
        SOC0
        C0 
        SOC_Window_Granularity
    end
    
    properties (Access = private)
        Instance = []
    end
    
    methods (Access = private)
        function obj = config(SOC0, C0, SOC_Window_Granularity)
            if nargin > 0
                obj.SOC0 = SOC0;
                obj.C0 = C0;
                obj.SOC_Window_Granularity = SOC_Window_Granularity;
            end
        end
    end
    
    methods (Static)
        function singleObj = getInstance()
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = config(100, 4.3635, 5);
            end
            singleObj = localObj;
        end
    end
end