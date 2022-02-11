%let date_min = 08Aug2021;
%let date_max = 02Feb2022;

proc sql;
create table Item_Returns as
select	Items.Item_Number,
		Vendors.Company_Id,
		Vendors.Company_Name,
		Items.Description,
		Count(distinct(Returns.rga_number)) as Num_Of_Returns
From 	D_DW.RETURNS_ALL Returns
		join D_Dw.LINE_ITEM_DETAILS lid on lid.line_item_id = Returns.line_item_id
		join D_DW.PIM_ITEMS as Items on lid.Pim_Item_Number = Items.Item_Number
		join D_DW.Vendors on Vendors.COMPANY_ID = lid.VENDOR_ID
where 	Returns.rga_type_id in(2,4)
		and Returns.active = 'Y'
		and Returns.Created_Timestamp between "&date_min"d and "&date_max"d
Group By 1,2,3,4

;quit;

proc sql;
create table Formulary_Rules as
Select  Items.Item_Number,
        Vendors.Company_Id,
        Vendors.Company_Name,
        Items.Description,
		Count(distinct Formulary.Document_Id) as Num_Of_Rules_Involved

From    D_DW.RAVEN_FORMULARY_OSTRING_USAGE Formulary
        join D_DW.PIM_ITEM_PRICES as Prices on Formulary.O_STRING = Prices.OEM_ITEM_NUMBER
        join D_DW.PIM_ITEMS as Items on Prices.Oem_Item_Number = Items.Item_Number
        join D_DW.VENDORS Vendors on Vendors.Company_Id = Items.Company_Id
        
Group By 1,2,3,4

;quit;
*
proc sql;
*create table Customer_Lists as
SELECT	Items.Item_Number,
        Vendors.Company_Id,
        Vendors.Company_Name,
        Items.Description,	
		Count(DISTINCT pr.cust_list_company_id) as Num_of_Lists_Involved
FROM 	D_DW.Apollo_Add_To-List as al
        join D_DW.Apollo_Delete_List dl on 
        join D_DW.PIM_ITEMS as Items on lid.Pim_Item_Number = Items.Item_Number
        join D_DW.VENDORS Vendors on Vendors.Company_Id = Items.Company_Id
WHERE   
Group By 1,2,3,4
;
*quit; 

proc sql;

CREATE TABLE Pricing_Rules AS
SELECT	Items.Item_Number,
        Vendors.Company_Id,
        Vendors.Company_Name,
        Items.Description,	
		Count(DISTINCT pr.price_rule_Id) as Num_of_Lists_Involved
FROM 	D_DW.PRICING_RULES as pr
        join D_DW.Line_Item_Details as lid on pr.price_rule_id = lid.price_rule_id
        join D_DW.PIM_ITEMS as Items on lid.Pim_Item_Number = Items.Item_Number
        join D_DW.VENDORS Vendors on Vendors.Company_Id = lid.Vendor_Id
WHERE 	PROD_SEG_PART_NUMBER IS NOT NULL
Group By 1,2,3,4

;quit;


proc print data= Item_Returns noobs; run;

proc print data= Formulary_Rules noobs; run;

*proc print data= Customer_Lists noobs; run;

proc print data= Pricing_Rules noobs; run;

