/*  *Set HTTP headers ;

**The Data Null needs to be set up before the %STPBEGIN, via Management Console;

data _null_;
  rc = stpsrv_header('Content-type','application/vnd.ms-excel');
  rc = stpsrv_header('Content-disposition','attachment; filename=VendorCompliance.xls');
run;


style={htmlstyle="vnd.ms-excel.numberformat:@"}  **html style allows for text numbers in excel;
*/

*%let date_min = 01may2013;
*%let date_max = 21may2013;

/*
data _NULL_ ;
CALL SYMPUT('v_research', "'"|| TRIM(LEFT(PUT(INTNX('MONTH',"&date_min"d,0, 's'),mmddyyd10.))) ||"'") ;
CALL SYMPUT('v_research_e', "'"|| TRIM(LEFT(PUT(INTNX('MONTH',"&date_max"d,0, 's'),mmddyyd10.))) ||"'") ;
run;
*/

*Vendor Auto Order Enabled;
proc sql;
create table auto_order as
select distinct
 VENDOR_ID
, is_auto_order
from D_DW.VENDOR_AUTO_ORDER
where IS_AUTO_ORDER='Y'
;quit;

proc sql;
create table vend_im as
select distinct
company_id as vendor_id
, 1 as Coun
from d_dw.pim_items
where item_type = 'V'
;quit;


proc sql;
create table work.vend_research as
select 
v.vendor_id
, put(ve.company_name,$100.) as Vendor
, sum(case when o.user_name is null then 1 else 0 end) as Vendor_Entered_Research
, sum(case when v.research_type_code = "SS" then 1 else 0 end) as SS_Research
, sum(case when v.research_type_code in ("SP","SPP") then 1 else 0 end) as SP_Research
, sum(1) as research_rcrd
, sum(case when v.research_type_code = "SS" then 1 else 0 end)/sum(1) as SS_Research_pct format= percent8.1
, sum(case when v.research_type_code in ("SP","SPP") then 1 else 0 end)/sum(1) as SP_Research_pct format= percent8.1
, sum(case when o.user_name is null then 1 else 0 end)/sum(1) as ePV_Research_pct format= percent8.1
from ( select v.line_item_id, v.research_type_code, created_user_id, vendor_id, outright_cost
     from d_dw.vendor_research v
     where v.created_date between "&date_min"d and "&date_max"d
     ) v
inner join d_dw.line_item_details lid on lid.line_item_id = v.line_item_id and lid.contract_pro_id is null
left join d_dw.organization o on o.organization_id = v.created_user_id
left join d_dw.vendors ve on ve.company_id = v.vendor_id
group by v.vendor_id, Vendor
;quit;



proc sql;
create table vend as
select
q.vendor_id
, put(v.company_name,$75.) as Vendor
, sum(case when q.product_category_id = 2 then orders end)/sum(orders) as Bio_Pct format=percent8.1
, sum(revenue)-sum(margin) as Spend format= dollar15.2
, sum(revenue) as Revenue format= dollar15.2
, sum(margin) as Margin format= dollar15.2
, sum(margin)/sum(revenue) as Margin_pct format= percent8.1
, sum(orders) as Orders format= comma6.
, case when vim.coun =1 then 'Y' else 'N' end as Vendor_in_IM
, v.smart_order_enabled as Smart_Order_enabled
, sum(case when lid.smart_order_conf = 1 and lid.smart_order_PO = 1 and lid.smart_price_presented = 1 
			then orders else 0 end)/sum(orders) as SMart_Order_pct format= percent8.1
, sum(case when lid.smart_order_conf = 1 and lid.smart_order_PO = 1 and lid.smart_price_presented = 1 
			then orders else 0 end) as Smart_Order_Total
, sum(case when lid.smart_order_conf = 1 then orders else 0 end)/sum(orders) as Smart_conf_pct format= percent8.1
, sum(case when lid.smart_order_conf = 1 then orders else 0 end) as Smart_Conf_Total
, sum(case when lid.smart_order_PO = 1 then orders else 0 end)/sum(orders) as Smart_PO_pct format= percent8.1
, sum(case when lid.smart_order_PO = 1 then orders else 0 end) as Smart_PO_Total
, v.smart_label_enabled as Smart_Label_enabled
, sum(case when t.auto_label = 'Y' then orders else 0 end)/sum(orders) as Smart_Label_pct format= percent8.1
, case when v.payment_term_code contains "NET" then 'Y' else 'N' end as Terms
, v.company_type_code
, v.tier_code
, v.epv_member as ePV_activated
, v.choice_level
, v.suspend_vendor
, v.redirect_shipments

from d_Dw.RORM_ALL q
left join d_dw.vendors v on v.company_id = q.vendor_id
left join work.vend_im vim on vim.vendor_id = q.vendor_id
inner join d_dw.line_item_details lid on lid.line_item_id = q.line_item_id and lid.contract_pro_id is null
left join d_dw.shipping_info ship on ship.line_item_id = q.line_item_id
left join d_dw.tracking_numbers t on t.line_item_id = q.line_item_id and t.shipment_leg_id  =1
where q.transaction_date between "&date_min"d and "&date_max"d and q.vendor_id ne 0
group by
q.vendor_id
, Vendor
, Vendor_in_IM
,  Smart_Order_enabled
,  Smart_Label_enabled
, Terms
, v.company_type_code
, v.tier_code
,  ePV_activated
, v.choice_level
, v.suspend_vendor
, v.redirect_shipments
having orders >0
order by Spend desc
;quit;


proc sql; /*Counts are all character, link to vendor name for actionable events*/
create table vend_map as
select
vendor_id
, count(distinct oem_id) as OEM_Maps
, count(distinct model_id) as Model_Maps
, count(distinct modality_id) as Modality_Maps
, count(distinct Class_id) as Class_Maps
from d_Dw.vendor_mapping 
group by
vendor_id
;quit;

proc sql;
create table combine_totals as
select
coalesce(v.Vendor_id, vr.Vendor_id) as Vendor_id
,coalesce(v.Vendor, vr.Vendor) as Vendor
, vend.Relationship_Manager_Id
, vend.Relationship_Manager
, coalesce(Bio_Pct,0) as Bio_pct format=percent8.1
, case when Bio_Pct > .50 then "Biomed Supplier"
	when Bio_Pct = .50 then "Biomed/Imaging Supplier"
	when Bio_Pct < .5 then "Imaging Supplier"
		end as Supplier_Type
, case when vm.vendor_id is not null then "Y" else "N" end as Mapping_Exists
, coalesce(v.Spend,0) as Spend format= dollar15.2
, coalesce(v.Revenue,0) as Revenue format= dollar15.2
, coalesce(v.Margin,0) as Margin format= dollar15.2
, coalesce(v.Margin_pct,0) as Margin_pct format= percent8.1
, coalesce(v.Orders,0) as Orders format= comma6.
, coalesce(v.Vendor_in_IM, case when vim.coun =1 then 'Y' else 'N' end) as Vendor_in_IM

, coalesce(vr.SS_Research_pct,0) as SS_Research_pct format= percent8.1
, coalesce(vr.SP_Research_pct,0) as SP_Research_pct format= percent8.1
, coalesce(vr.SS_Research_pct + vr.SP_Research_pct,0) as IM_Research_pct format= percent8.1

, coalesce(a.is_auto_order, 'N') as Smart_Order_Enabled
, coalesce(v.Smart_Order_Total,0) as Number_of_Smart_Orders format= comma8.
, coalesce(v.Smart_Order_pct,0) as Smart_Order_pct format=percent8.1
, coalesce(v.Smart_Conf_Total,0) as Number_of_Smart_Conf format= comma8.
, coalesce(v.Smart_conf_pct,0) as Smart_Conf_pct format= percent8.1
, coalesce(v.Smart_PO_Total,0) as Number_of_Smart_PO format= comma8.
, coalesce(v.Smart_PO_pct,0) as Smart_PO_pct format= percent8.1

, coalesce(v.Smart_Label_enabled, vend.Smart_Label_enabled) as Smart_Label_Enabled
, coalesce(v.Smart_Label_pct,0) as Smart_Label_pct format= percent8.1
, coalesce(v.Terms, case when vend.payment_term_code contains "NET" then 'Y' else 'N' end ) as Terms
, coalesce(v.company_type_code, vend.company_type_code) as Vendor_Type
, coalesce(v.tier_code, vend.tier_code) as Vendor_Tier

, coalesce(v.ePV_activated, vend.epv_member) as ePF_Activated
, coalesce(vr.ePV_Research_pct,0) as sPV_Research_pct format= percent8.1

, coalesce(v.choice_level, vend.choice_level) as Choice_Level
, coalesce(v.suspend_vendor, vend.suspend_vendor) as Suspended
, coalesce(v.redirect_shipments, vend.redirect_shipments) as No_Drop_Ship

from work.vend v
full join work.vend_research vr on vr.vendor_id = v.vendor_id
left join d_dw.vendors vend on vend.company_id = coalesce(v.Vendor_id, vr.Vendor_id)
left join work.vend_im vim on vim.vendor_id = coalesce(v.Vendor_id, vr.Vendor_id)
left join work.vend_map vm on vm.vendor_id = coalesce(v.Vendor_id, vr.Vendor_id)
left join work.auto_order a on a.vendor_id = coalesce(v.Vendor_id, vr.Vendor_id)
order by Spend desc
;quit;

proc sql;
create table summary_totals as
select
'Company Totals' as Totals
, sum(spend) as Spend format=dollar15.2
, sum(Revenue) as Revenue format=dollar15.2
, sum(Margin) as Margin format=dollar15.2
, sum(Margin)/sum(Revenue) as Margin_pct format=percent8.1
, sum(Orders) as Orders format=comma10.
, sum(case when Vendor_in_IM = "Y" then 1 end)/count(Vendor_in_IM) as Vendor_in_IM_pct format=percent8.1
, sum(case when Smart_Order_Enabled = "Y" then 1 end)/count(Smart_Order_Enabled) as Smart_Order_Enabled_pct format=percent8.1

, sum(Number_of_Smart_Orders) as Number_of_Smart_Orders format=comma10.
, sum(Number_of_Smart_Orders)/sum(Orders) as Smart_Order_pct format=percent8.1
, sum(Number_of_Smart_Conf) as Number_of_Smart_Conf format=comma10.
, sum(Number_of_Smart_Conf)/sum(Orders) as Smart_Conf_pct format=percent8.1
, sum(Number_of_Smart_PO) as Number_of_Smart_PO format=comma10.
, sum(Number_of_Smart_PO)/sum(Orders) as Smart_PO_pct format=percent8.1

, sum(case when Smart_Label_Enabled = "Y" then 1 end)/count(Smart_Label_Enabled) as Smart_Label_Enabled_pct format=percent8.1
, sum(Smart_Label_pct*Orders)/sum(orders) as Smart_Label_pct format=percent8.1
, sum(case when Terms = "Y" then 1 end)/count(Terms) as Terms_pct format=percent8.1
from combine_totals
;quit;

title1 "All Vendors for &date_min to &date_max";

proc print data=work.combine_totals noobs;
run;
title;

proc print data=work.summary_totals noobs;
run;