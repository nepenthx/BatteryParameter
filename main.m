data=LoadData;
prec=preconditioningData;
prec=prec.init(data);
for k=1:20
    prec.SOC_Windows(k)=prec.SOC_Windows(k).getAllRow(data);
    prec.SOC_Windows(k)=prec.SOC_Windows(k).calculateR0();
    prec.SOC_Windows(k)=prec.SOC_Windows(k).fminconTest();
end