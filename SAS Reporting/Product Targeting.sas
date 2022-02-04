
proc sql;
create table Item_Returns as


;quit;

proc sql;
create table Formulary_Rules as
Select  Count(distinct Formulary.Document_Id),
        Items.Item_Number,
        Vendors.Company_Id,
        Vendors.Company_Name,
        Items.Description

From    DW.RAVEN_FORMULARY_OSTRING_USAGE Formulary
        join DW.PIM_ITEM_PRICES as Prices on Formulary.O_STRING = Prices.OEM_ITEM_NUMBER
        join DW.PIM_ITEMS as Items on Prices.Oem_Item_Number = Items.Item_Number
        join DW.VENDORS Vendors on Vendors.Company_Id = Items.Company_Id
        
Group By Items.ITEM_NUMBER, Vendors.Company_Id, Vendors.Company_Name, Items.Description

;quit;

proc sql;
create table Customer_Lists as


;quit;

proc sql;

CREATE TABLE Pricing_Rules AS
SELECT 	DISTINCT price_rule_Id
FROM 	d_dw.PRICING_RULES
WHERE 	PROD_SEG_PART_NUMBER IS NOT NULL

;quit;

;quit;


proc print data= Item_Returns noobs; run;

proc print data= Formulary_Rules noobs; run;

proc print data= Customer_Lists noobs; run;

proc print data= Pricing_Rules noobs; run;

