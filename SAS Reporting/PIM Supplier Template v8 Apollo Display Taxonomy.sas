

%let start_date= 01feb2021;
%let end_date= 31jan2022;


*%let structure_filter=840; *Enter List of Structures Here;
*%let Taxonomy_filter='d5.0.0.0.0.0.0'; *Enter List of Taxonomies Here, items need to be listed in single quotes ('','','');
%let company_filter=17590; *Enter List of Vendors/OEM's Here;

/* 320,90,520,490,20,30,270,420,610,550,2080,80,700,450,530,1470,1600,760,220,600,2250,410,690,10,1570,3390   biomed  
   3670,3680,870,840,1100,1070,950,1060,810,960,1040,1050,1140,1270   DI*/

***************************************************************
Select one of these filters to use in the report.
If multiple are not commented, it will only use the last
***************************************************************;

*%let filter = s.structure_id in (&structure_filter); *Structure;
*%let filter = s.parent_id in (&structure_filter); *Parent Structure;

*%let filter = t.structure_id in (&Taxonomy_filter); *Taxonomy;
*%let filter = t.parent_structure_id in (&Taxonomy_filter); *Parent Taxonomy;

*%let filter = i.company_id in (&company_filter); *Vendor ID;
%let filter = io.company_id in (&company_filter); *OEM ID;


***********************
PIM Taxonomy
***********************;

proc sql;
connect to DB2 (database=PFPROD user=dwuser password=sasisgreat);
create table work.Parent_Child as
select *
from connection to DB2
(
SELECT
STRUCTURE_ID
, NAME
, SUBSTR (structure_id, 1 , locate('.',structure_id))||'0.0.0.0.0.0' as PARENT_STRUCTURE_ID
from PIM.OEM_Structure
where oem_id=2
with ur
)
;quit;

proc sql;
create table taxonomy_complete as
select
a.structure_id
, a.name
, a.parent_structure_id
, b.name as Parent_Name

from work.parent_child a
left join work.parent_child b on a.parent_structure_id = b.structure_id
;quit;

proc sql;
connect to DB2 (database=PFPROD user=dwuser password=sasisgreat);
create table work.PIM_Taxonomy as
select *
from connection to DB2
(
select
o.product_number
, o.structure_id
from PIM.OEM_STRUCTURE_PRODUCTS o
left join PIM.OEM_STRUCTURE s on s.STRUCTURE_ID = o.STRUCTURE_ID
where o.OEM_ID=2
with ur
)
;quit;

***********************
Report Begin
***********************;

proc sql;
create table pim_items as
select
s.PARENT_NAME as Structure_Parent_Name
, s.NAME as Structure_Name
, t.structure_id as Taxonomy_ID
, t.NAME as Taxonomy_Name
, t.parent_structure_id as Taxonomy_Parent_ID
, t.Parent_name as Taxonomy_Parent
, i.COMPANY_ID as Vendor_ID
, v.COMPANY_NAME as Vendor_Name
, i.PART_NUMBER as Vendor_Part_Number
, i.DESCRIPTION
, io.COMPANY_ID as OEM_ID
, o.COMPANY_NAME as OEM_Name
, io.PART_NUMBER as OEM_Part_Number
, pip.EXCHANGE_OEM_PRICE
, pip.OUTRIGHT_OEM_PRICE
, pip.EXCHANGE_COST
, pip.OUTRIGHT_COST
, pip.EXCHANGE_PRICE
, pip.OUTRIGHT_PRICE
, pip.COST_CORE_CHARGE
, pip.UOM_CODE
/*QTY/UOM*/
, pip.CONDITION
, pip.COST_WARRANTY_DESCRIPTION
/*Cust Note*/
, pip.IS_RETURNABLE
/*QTY On Hand*/
, pip.LEAD_TIME_DAYS
/*MODEL List/Count*/
/*Reference List/Count*/
, pip.search_item_number as Item_Number
, pip.OEM_item_number
, pip.product_number
, pip.sub_type as Item_Subtype
from D_DW.PIM_ITEM_PRICES pip
left join D_DW.PIM_ITEMS i on i.ITEM_NUMBER=pip.SEARCH_ITEM_NUMBER
left join D_DW.PIM_PRODUCT_STRUCTURE s on s.STRUCTURE_ID=i.PS_STRUCTURE_ID
left join D_dw.vendors v on v.COMPANY_ID=i.COMPANY_ID
left join D_DW.PIM_ITEMS io on io.ITEM_NUMBER=pip.OEM_ITEM_NUMBER
left join D_dw.oems o on o.company_id = io.COMPANY_ID

left join work.PIM_Taxonomy p on p.product_number = pip.product_number
left join work.taxonomy_complete t on t.structure_id = p.structure_id
where &filter
;quit;

*Photo Counts;
proc sql;
create table photos as 
select
 ITEM_NUMBER
, sum(1) as photos
from D_DW.PIM_IMAGES
group by
 ITEM_NUMBER
;quit;

*Rank Models;
proc sql;
create table model_gather as 
select
i.ITEM_NUMBER
, p.MODEL_CODE
from d_DW.PIM_MODELS p
inner join D_dw.pim_items i on i.ITEM_TYPE='V' and i.PRODUCT_NUMBER = p.PRODUCT_NUMBER
;quit;

proc sort data=work.model_gather;
by item_number;
run;

data model_rank;
set work.model_gather;
by item_number;
rank+1-rank*first.item_number;
run;

*Rank References;
proc sql;
create table ref_gather as 
select distinct
 SEARCH_ITEM_NUMBER
, PART_NUMBER
from D_DW.PIM_SEARCHES
;quit;

proc sort data=work.ref_gather;
by SEARCH_ITEM_NUMBER;
run;

data ref_rank;
set work.ref_gather;
by SEARCH_ITEM_NUMBER;
rank+1-rank*first.SEARCH_ITEM_NUMBER;
run;

*Get Additional Logistic Information from DB2
TAKE CARE WHEN EDITING;
proc sql;
connect to DB2 (database=PFPROD user=dwuser password=sasisgreat);
create table work.Logistics as
select *
from connection to DB2
(
select
 l.ITEM_NUMBER
, l.CUST_NOTES, l.QUANTITY_ON_HAND, l.UOM_QUANTITY
, i.PACKAGE_WEIGHT, CONDITION_CODE
from PIM.ITEM_LOGISTICS l
left join pim.items i on i.item_number = l.ITEM_NUMBER
with ur
)
;quit;

*Get Additional Attribute Information from DB2
TAKE CARE WHEN EDITING;
proc sql;
connect to DB2 (database=PFPROD user=dwuser password=sasisgreat);
create table work.Attributes as
select *
from connection to DB2
(
select
 ITEM_NUMBER
, sum(1) as Attribute
from PIM.ITEM_ATTRIBUTES 
group by
 ITEM_NUMBER
with ur
)
;quit;

*Get Additional Attribute Information from DB2
TAKE CARE WHEN EDITING;
proc sql;
connect to DB2 (database=PFPROD user=dwuser password=sasisgreat);
create table work.AlsoConsider as
select *
from connection to DB2
(
select
"OWNER" as Item_Number
, "TO" as Also_Consider
, sequence
from PIM."REFERENCES"
where type='C' and sequence in (1,2)
with ur
)
;quit;

*Transactional Data;
proc sql;
create table trx as
select
lid.pim_item_number as Item_Number
, lid.condition_code
, sum(requests) as Requests
, sum(Orders) as Orders
, sum(Quantity) as Quantity
, sum(Revenue) as Revenue
, sum(Margin) as Margin
, sum(revenue-Margin) as Ext_Cost
from d_Dw.RORM_ALL (dbsastype=revenue="numeric") q
inner join d_dw.line_item_details lid on lid.line_item_id = q.line_item_id
	and lid.contract_pro_id is null
where lid.pim_item_number is not null and q.transaction_date between "&start_date"D and "&end_date"D
group by
1,2
;quit;



*Merging Data output;
proc sql;
create table output as
select
p.Structure_Parent_Name
, p.Structure_Name
, p.Taxonomy_ID
, p.Taxonomy_Name
, p.Taxonomy_Parent_ID
, p.Taxonomy_Parent
, p.Vendor_ID
, p.Vendor_Name
, p.Vendor_Part_Number
, p.item_Number as Vendor_Item_Number
, p.Item_Subtype
, p.DESCRIPTION
, p.OEM_ID
, p.OEM_Name
, p.OEM_Part_Number
, p.OEM_Item_Number
, p.Product_Number
, p.EXCHANGE_OEM_PRICE format=dollar15.2
, p.OUTRIGHT_OEM_PRICE format=dollar15.2
, p.EXCHANGE_COST format=dollar15.2
, p.OUTRIGHT_COST format=dollar15.2
, p.EXCHANGE_PRICE format=dollar15.2
, p.OUTRIGHT_PRICE format=dollar15.2
, p.COST_CORE_CHARGE format=dollar15.2
, p.UOM_CODE
, l.UOM_QUANTITY
, p.CONDITION
, p.COST_WARRANTY_DESCRIPTION
, l.CUST_NOTES
, p.IS_RETURNABLE
, l.QUANTITY_ON_HAND
, p.LEAD_TIME_DAYS
, a.Attribute as Attribute_Count
, ph.photos as Photo_Count
, l.Package_Weight as PIM_Weight

, m1.model_code as Model_1
, m2.model_code as Model_2
, m3.model_code as Model_3
, m4.model_code as Model_4
, m5.model_code as Model_5
, m6.model_code as Model_6
, m7.model_code as Model_7
, m8.model_code as Model_8
, m9.model_code as Model_9
, m10.model_code as Model_10
, case when m11.model_code is not null then 'Y' else 'N' end as More_Models

, r1.PART_NUMBER as Reference_1
, r2.PART_NUMBER as Reference_2
, r3.PART_NUMBER as Reference_3
, r4.PART_NUMBER as Reference_4
, r5.PART_NUMBER as Reference_5
, r6.PART_NUMBER as Reference_6
, r7.PART_NUMBER as Reference_7
, r8.PART_NUMBER as Reference_8
, r9.PART_NUMBER as Reference_9
, r10.PART_NUMBER as Reference_10
, case when r11.part_number is not null then 'Y' else 'N' end as More_References

, a1.Also_Consider as Also_Consider_1
, a2.Also_Consider as Also_Consider_2

, t.Requests format=comma8.
, t.Orders format=comma8.
, t.Quantity format=comma8.
, t.Revenue format=dollar15.2
, t.Ext_Cost format=dollar15.2
, t.Margin format=dollar15.2
from work.pim_items p
left join work.attributes a on a.item_number = p.item_number
left join work.logistics l on l.item_number = p.item_number and L.condition_code = p.condition
left join work.photos ph on ph.item_number = p.oem_item_number
left join work.trx t on t.item_number = p.item_number and t.condition_code = p.condition

left join work.ref_rank r1 on r1.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r1.rank=1
left join work.ref_rank r2 on r2.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r2.rank=2
left join work.ref_rank r3 on r3.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r3.rank=3
left join work.ref_rank r4 on r4.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r4.rank=4
left join work.ref_rank r5 on r5.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r5.rank=5
left join work.ref_rank r6 on r6.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r6.rank=6
left join work.ref_rank r7 on r7.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r7.rank=7
left join work.ref_rank r8 on r8.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r8.rank=8
left join work.ref_rank r9 on r9.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r9.rank=9
left join work.ref_rank r10 on r10.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r10.rank=10
left join work.ref_rank r11 on r11.SEARCH_ITEM_NUMBER = p.OEM_Item_Number and r11.rank=11

left join work.model_rank m1 on m1.item_number = p.item_number and m1.rank=1
left join work.model_rank m2 on m2.item_number = p.item_number and m2.rank=2
left join work.model_rank m3 on m3.item_number = p.item_number and m3.rank=3
left join work.model_rank m4 on m4.item_number = p.item_number and m4.rank=4
left join work.model_rank m5 on m5.item_number = p.item_number and m5.rank=5
left join work.model_rank m6 on m6.item_number = p.item_number and m6.rank=6
left join work.model_rank m7 on m7.item_number = p.item_number and m7.rank=7
left join work.model_rank m8 on m8.item_number = p.item_number and m8.rank=8
left join work.model_rank m9 on m9.item_number = p.item_number and m9.rank=9
left join work.model_rank m10 on m10.item_number = p.item_number and m10.rank=10
left join work.model_rank m11 on m11.item_number = p.item_number and m11.rank=11

left join work.AlsoConsider a1 on a1.item_number = p.OEM_Item_Number and a1.sequence=1
left join work.AlsoConsider a2 on a2.item_number = p.OEM_Item_Number and a2.sequence=2

;quit;