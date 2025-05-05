for k=length(prec.SOC_Windows):-1:1
    if prec.SOC_Windows(k).skip==1
        continue;
    end
end
SOC = 1:100;
for k = 1:100
    ocv_res(k)=post.OCVLookup(k);
end
figure;
plot(SOC, ocv_res(k));