figure;
for k=1:20
temp(k)=prec.SOC_Windows(k).oth(4);
end
plot(temp)


figure;

    for k=1:20
        temp(k)=prec.SOC_Windows(k).oth(5)./prec.SOC_Windows(k).oth(4);
    end
    plot(temp)