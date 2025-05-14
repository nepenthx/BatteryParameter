classdef postProcessing
    properties
        OCVLookup
        R0Lookup 
        R1Lookup 
        Tau1Lookup
        SOC_Windows
    end

    methods
        function obj = init(obj, prec)
            obj.SOC_Windows = prec.SOC_Windows;
            obj.R0Lookup = prec.R0Lookup;
            obj = obj.createParamInterpolators();
        end

        
        function obj = createParamInterpolators(obj)

            soc_centers = arrayfun(@(w) (w.range_lower + w.range_upper)/2, obj.SOC_Windows);
            valid_mask = ~[obj.SOC_Windows.skip];
            
            valid_soc = soc_centers(valid_mask);
        
            oth_cells = {obj.SOC_Windows(valid_mask).oth}';
            params = cell2mat(oth_cells);
            
            valid_soc_col = valid_soc(:);
            
            ocv_pts = params(:,1) .* valid_soc_col + params(:,2);
            disp(params(:,1));
            disp(params(:,2));
            disp(valid_soc_col);
            r1_pts = params(:,4);
            tau1_pts = params(:,5);
            obj.OCVLookup = createInterpolator(valid_soc_col, ocv_pts);
            obj.R1Lookup = createInterpolator(valid_soc_col, r1_pts);
            obj.Tau1Lookup = createInterpolator(valid_soc_col, tau1_pts);

            
            function interp_func = createInterpolator(soc, values)
                [unique_soc, ~, ic] = unique(soc);
                unique_values = accumarray(ic, values, [], @mean);
                
                if numel(unique_soc) < 2
                    interp_func = @(s) mean(values); 
                else
                    interp_func = @(s) interp1(unique_soc, unique_values,...
                        max(min(s, max(unique_soc)), min(unique_soc)), 'pchip', 'extrap');
                end
            end
        end
    end
end