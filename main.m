classdef main 
    methods (Static)
        function obj =init(obj)
            data=LoadData;
            prec=preconditioningData;
            prec=prec.calculateSoc(data).getSOCWindows(data);
        end
    end
end