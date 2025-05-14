figure;
for k=1:25
if prec.SOC_Windows(k).skip==1
        continue;
    end
temp(k)=prec.SOC_Windows(k).oth(4);
end
plot(temp)


figure;

    for k=1:25
        if prec.SOC_Windows(k).skip==1
            continue;
        end
        temp(k)=prec.SOC_Windows(k).oth(5)./prec.SOC_Windows(k).oth(4);
    end
    plot(temp)