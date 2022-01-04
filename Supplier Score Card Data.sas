/*  *Set HTTP headers ; 
**The Data Null needs to be set up before the %STPBEGIN, via Management Console; 
 
data _null_; 
  rc = stpsrv_header('Content-type','application/vnd.ms-excel'); 
  rc = stpsrv_header('Content-disposition','attachment; filename=SupplierScorecard.xls'); 
run; 
 
style={htmlstyle="vnd.ms-excel.numberformat:@"}  **html style allows for text numbers in excel; 
*/ 

/*
Updated 7/21/2015 JW
	Update is to include OEMDirect data into this reporting file:
	Replaced D_DW.REQUESTS_ORDERS_REVENUE_MARGIN with D_DW.RORM_ALL
	Combined Returns tables into work.Comb_Returns
	Dropped unnecessary Group By statements
*/ 

 
*%let start_date = 01jun2020; 
*%let end_date = 16jun2020; 
 
 
/* Get Vendor Order information*/ 
 
proc sql; 
create table  tmpVendormetrics as  
Select  
ven.company_id 
, ven.company_name  
, ven.relationship_manager_id
, ven.relationship_manager
, ven.company_type_code 
, q2.line_item_id 
, lid.smart_price_selected  
, t.auto_label 
, lid.smart_sourced  
, lid.photo_shown  
, q2.quantity 
, q2.requests 
, q2.orders 
, q2.Oem_price 
, q2.revenue 
, q2.margin 
, cal.month_end 
, lid.Backorder_ship_date 
, q2.class_id 
, t.tracking_number  
, lid.return_required 
, lid.smart_Order_Po 
from d_dw.vendors as ven  
left join d_dw.RORM_ALL  as q on q.vendor_id  = ven.company_id
left join d_dw.line_item_details lid on lid.line_item_id = q.line_item_id and lid.contract_pro_id is null 
left join d_dw.RORM_ALL  as q2 on q2.vendor_id  = ven.company_id and q2.line_item_id = lid.line_item_id
left join d_dw.calendar cal on cal.date_key = q2.transaction_date 
left join d_dw.product_classes as clas on clas.class_id = q2.class_id 
left join d_dw.tracking_numbers as t on t.line_item_id = q2.line_item_id and shipment_leg_id =1 
where q2.transaction_date between "&Start_date"d and "&End_date"d 
;quit; 
 
proc sql; 
create table tmpsumvendormetrics as 
select  
met.company_id 
, met.company_name  
, met.relationship_manager_id
, met.relationship_manager
, met.company_type_code 
, met.month_end 
, sum(met.requests) as Total_requests 
, sum(met.orders) as Total_orders  
, sum(met.oem_price * met.quantity) as Oem_list  
, sum(met.revenue-met.margin) as parts_cost 
, sum(met.smart_price_selected  * met.requests) as smart_priced_requests 
, sum(met.smart_sourced * met.requests) as smart_sourced_requests 
, sum(met.photo_shown  * met.requests) as photo_requests 
, sum(case when met.auto_label ="Y" then met.orders else 0 end ) as Auto_label 
, sum(case when met.Backorder_ship_date is not null and met.class_id not in (6,24,42) then met.orders  else 0 end) as Back_order 
, sum(case when met.tracking_number is not null then met.orders else 0 end) as Tracking_provided  
, sum(case when met.return_required = "Y" then met.orders else 0 end ) as sold_on_exchange 
, sum(case when met.smart_Order_Po = 1 then met.orders else 0 end ) as smart_po 
from work.tmpVendormetrics as met 
group by met.company_id 
, met.company_name  
, met.company_type_code 
, met.month_end 
;quit;

/* Get Vendor Return Data*/

proc sql;
create table comb_returns as
select
r.line_item_id 
, r.rga_number 
, r.responsibility
, r.return_reason_id
, r.quantity 
, r.created_timestamp
from d_Dw.returns_ALL r
where r.created_timestamp between "&Start_date"d and "&End_date"d 
	and r.rga_type_id in(2,4)  
	and r.Active = "Y"  
	and r.status_id ne 7  

;quit;


proc sql; 
create table tmpVendorRTNS as  
select 
ven.company_id 
,r.line_item_id 
,r.rga_number 
, cal.month_end 
,case when r.responsibility = 'C' then 'Customer'   
	when r.responsibility = "P" then 'PartsSource'  
	when r.responsibility in ("V","N") then 'Vendor'  
	when r.responsibility = "S" then 'Shipping' else "other" end as rtn_responsibility  
, case when r.return_reason_id in (3,27,23,9,54,10,4,43,42,52) then "Quality Issue" else "Other" end as rtn_quality  
,(r.quantity * q.price) as returned_revenue 
FROM work.comb_returns as r  
left join d_dw.RORM_ALL as q on q.line_item_id = r.line_item_id  and q.orders = 1 
left join d_dw.calendar as cal on datepart(cal.date_key) = datepart(r.created_timestamp) 
left join d_dw.vendors as ven on ven.company_id = q.vendor_id 
;quit; 
 
 
data tmpVendorRTNS2;
set  work.tmpVendorRTNS;
returned_revenue2=input(returned_revenue ,12.);
drop returned_revenue;
run;
;quit;

proc sql; 
create table tmpvendorRTNSsorted as  
select  
ret.company_id 
,ret.line_item_id 
,ret.rga_number 
,ret.month_end
,count(ret.Line_item_id) as RTN_count
,ret.returned_revenue2
, case when ret.rtn_responsibility = "Customer" then count(ret.Line_item_id) else 0 end as Customer_returns  
, case when ret.rtn_responsibility = "PartsSource" then count(ret.Line_item_id)else 0 end as PartsSource_returns  
, case when ret.rtn_responsibility = "Vendor" then count(ret.Line_item_id)else 0 end as Vendor_returns  
, case when ret.rtn_responsibility = "Shipping" then count(ret.Line_item_id)else  0 end as Shipping_returns  
, case when ret.rtn_quality  = "Quality Issue" and ret.rtn_responsibility = "Vendor" then count(ret.Line_item_id)else 0 end as Quality_returns
, case when ret.rtn_responsibility = "Customer" then sum(ret.returned_revenue2 ) else 0 end as Customer_returns_rev 
, case when ret.rtn_responsibility = "PartsSource" then sum(ret.returned_revenue2 )else 0 end as PartsSource_returns_rev 
, case when ret.rtn_responsibility = "Vendor" then sum(ret.returned_revenue2 )else 0 end as Vendor_returns_rev  
, case when ret.rtn_responsibility = "Shipping" then sum(ret.returned_revenue2 )else  0 end as Shipping_returns_rev  
, case when ret.rtn_quality  = "Quality Issue" and ret.rtn_responsibility = "Vendor"  then sum(ret.returned_revenue2 )else 0 end as Quality_returns_rev
from work.tmpVendorRTNS2 as ret  
group by  
ret.company_id 
,ret.line_item_id 
,ret.rga_number 
,ret.month_end 
;quit; 
 
proc sql; 
create table tmpvendorRTNSsorted2 as  
select  
ret.company_id 
,ret.month_end 
,sum(ret.RTN_count) as Total_returns
,sum(ret.returned_revenue2) as Total_RTN_Rev 
,sum(ret.Customer_returns) as Customer_retrurns 
,sum(ret.PartsSource_returns)  as PS_retrurns 
,sum(ret.Vendor_returns) as Vendor_retrurns 
,sum(ret.Shipping_returns) as Shipping_retrurns 
,sum(ret.Quality_returns) as Quality_retrurns 
,sum(ret.Customer_returns_rev) as Customer_retrurns_rev 
,sum(ret.PartsSource_returns_rev)  as PS_retrurns_rev 
,sum(ret.Vendor_returns_rev) as Vendor_retrurns_rev 
,sum(ret.Shipping_returns_rev) as Shipping_retrurns_rev 
,sum(ret.Quality_returns_rev) as Quality_retrurns_rev 
from work.tmpvendorRTNSsorted as ret  
group by  
ret.company_id 
,ret.month_end 
;quit; 
 
/*combine Vendor Order information and Return information*/ 
proc sql; 
create table tmpvendorOrderRTNcombo as 
Select 
met.company_id 
, met.company_name
, met.relationship_manager_id
, met.relationship_manager 
, met.company_type_code 
, met.month_end 
, met.Total_requests 
, met.Total_orders  
, met.parts_cost 
, met.oem_list 
, met.smart_priced_requests 
, met.smart_sourced_requests 
, met.photo_requests 
, met.Auto_label 
, met.Back_order 
, met.Tracking_provided  
, met.sold_on_exchange 
, met.smart_po 
,ret.Total_returns 
,ret.Customer_retrurns 
,ret.PS_retrurns 
,ret.Vendor_retrurns 
,ret.Shipping_retrurns 
,ret.Quality_retrurns 
,ret.Total_RTN_Rev 
,ret.Customer_retrurns_rev 
,ret.PS_retrurns_rev 
,ret.Vendor_retrurns_rev 
,ret.Shipping_retrurns_rev 
,ret.Quality_retrurns_rev 
,ret.Vendor_retrurns -ret.Quality_retrurns as Process_RTNS 
from work.tmpsumvendormetrics as met  
left join work.tmpvendorRTNSsorted2  as  ret on ret.company_id = met.company_id and ret.month_end = met.month_end  
;quit; 
 
/*get vendor Research Information*/ 
 
proc sql; 
Create table tmpvendorresearch as  
select 
res.vendor_id  
,ven.company_name  
,res.created_user_id
,lid.line_item_id  
,cal.month_end 
,Result_code 
,research_type_code 
from d_dw.vendor_research as res  
inner join d_dw.line_item_details lid on lid.line_item_id = res.line_item_id and lid.contract_pro_id is null
left join d_dw.vendors as ven on ven.company_id = res.vendor_id  
left join d_dw.calendar as cal on cal.date_key = res.created_date 
where res.created_date between "&Start_date"d and "&End_date"d 
;quit; 
 
 
proc sql; 
Create table tmpvendorsearchcount as  
select 
res.vendor_id
,res.company_name  
,res.month_end 
,count(res.line_item_id ) as Research_lines  
,count(case when res.result_code in ("HP","EHP") then res.line_item_id end ) as Has_part_research_line 
,count(case when res.research_type_code = "SP" or res.research_type_code = "SS" 
	or res.research_type_code = "SPP" or 
	(req.requestor_id  is not null and res.result_code in ("HP","EHP") /*Added per Tessa's Request 11.12.2014*/) then res.line_item_id end) as SS_Research_line  
from work.tmpvendorresearch as res 
left join d_dw.requestors as req on req.requestor_id = res.created_user_id 
group by  
res.vendor_id  
,res.company_name  
,res.month_end 
;quit;  
 
/* Start Vendor TYpe ( Imaging Supplier or Biomed Suppler Table)*/ 
 
proc sql; 
create table tmpvendortype as  
select 
v.company_id 
,v.company_name 
,q.product_category_id 
,q.orders as orders 
from d_dw.RORM_ALL as q
inner join d_dw.line_item_details lid on lid.line_item_id = q.line_item_id and lid.contract_pro_id is null 
left join d_dw.vendors as v on v.company_id =q.vendor_id 
;quit; 
 
proc sql; 
create table tmpvendortype2 as  
select  
q.company_id 
,q.company_name 
, sum(case when q.product_category_id = 2 then q.orders end)/sum(q.orders) as Bio_Pct format=percent8.1 
from work.tmpvendortype as q  
group by  
q.company_id 
,q.company_name 
;quit; 
 
proc sql; 
create table tmpvendortypefinal as  
select  
q.company_id 
,q.company_name 
,case when q.Bio_Pct > .50 then "Biomed" 
	when q.Bio_Pct = .50 then "Biomed/Imaging" 
	when q.Bio_Pct < .5 then "Imaging" 
		end as Supplier_Type 
from work.tmpvendortype2  as q  
;quit; 
 
 
/*Get Delivery on  Time Metrics*/ 
/*Gather Cut off time infor*/ 
 
proc sql; 
create table tmpvendorcutoff as 
select  
 CC.COMPANY_ID  
 , CC.COMPANY_NAME  
, CC.VEND_CUTOFF_EST   as Cutoff_Time_EST 
  FROM  D_Dw.vendors cc 
 WHERE  CC.ACTIVE = 'Y' 
   
;quit; 


/*Pull in Tracking and Shipping info */ **************************************;

proc sql;
create table sourcing_setup as
select
r.line_item_id
, FIRST_CLOSED_TIMESTAMP as Closed_Datetime format=datetime.
, FIRST_ORDERED_TIMESTAMP as Ordered_Datetime format=datetime.
from d_dw.line_item_status_summary r
inner join d_dw.line_item_details lid on lid.line_item_id = r.line_item_id and lid.contract_pro_id is null
where datepart(FIRST_ORDERED_TIMESTAMP) >= "&start_date"D 
;quit;

proc sql; 
create table tmpVendorShipsort as 
select 
q.line_item_id 
, lid.backorder_ship_date 
, vc.Cutoff_Time_EST 
, t.tracking_number 
, datepart(t.date_delivered) as date_delivered format=date. 
, s.shipping_method 
, sp.SHIPPING_METHOD_ID 
, ss.Closed_Datetime
, ss.Ordered_Datetime 
from d_dw.RORM_ALL q 
left join d_dw.line_item_details lid on lid.line_item_id = q.line_item_id 
left join d_dw.customers c on c.company_id = q.customer_id 
left join d_dw.tracking_numbers t on t.line_item_id = q.line_item_id and shipment_leg_id = 1 
left join d_dw.shipping_info s on s.line_item_id = q.line_item_id 
left join work.tmpvendorcutoff vc on vc.company_id = q.vendor_id 
left join d_dw.Ship_methods as sp on sp.shipping_method = s.shipping_method 
inner join work.sourcing_setup ss on ss.line_item_id = q.line_item_id
where q.requests=1 and q.transaction_date >= "&start_date"D 
;quit; 
 
data bt_addative; 
set tmpVendorShipsort; 
if backorder_ship_date = . and (timepart(Closed_Datetime) <= cutoff_time_est or cutoff_time_est = .) 
	and date_delivered ne . then  pre_cutoff="Before Vendor Cutoff";  
else pre_cutoff="Other"; 
run; 
 
data calendar_convert; 
set d_dw.calendar; 
keep workday_ind sas_date; 
sas_date = datepart(date_key); 
run; 
 
proc sql; 
create table bt_days as 
select 
line_item_id 
, backorder_ship_date 
, Cutoff_Time_EST 
, tracking_number 
 
, shipping_method 
, shipping_method_id 
 
, Closed_Datetime 
, Ordered_Datetime 
, date_delivered  
, pre_cutoff 
 
, clo.workday_ind as closed_workday 
, ord.workday_ind as ordered_workday 
, del.workday_ind as delivered_workday 
 
, datepart(Closed_Datetime) as ctime 
, datepart(Ordered_Datetime) as otime 
 
 
from bt_addative s 
left join calendar_convert clo on clo.sas_date = datepart(Closed_Datetime) 
left join calendar_convert ord on ord.sas_date = datepart(Ordered_Datetime) 
left join calendar_convert del on del.sas_date = date_delivered 
;quit; 
 
proc sql; 
create table bt_days_range as 
select 
b.line_item_id 
, v.company_id as Vendor_id 
, v.company_name as Vendor_Name 
, v.company_type_code as Vendor_type 
, b.backorder_ship_date 
, b.Cutoff_Time_EST 
, b.tracking_number 
 
, b.shipping_method 
, b.shipping_method_id 
 
, b.Closed_Datetime 
, b.Ordered_Datetime 
, b.date_delivered  
, b.pre_cutoff 
, cal.month_end 
 
, b.closed_workday 
, b.ordered_workday 
, b.delivered_workday 
 
, case when b.date_delivered =. then .  
	else (select sum(workday_ind)-1 from calendar_convert where sas_date 
	between ctime and date_delivered) end as Clo_Del_Days 
, case when b.SHIPPING_METHOD_ID in (11) then 0 
    when b.SHIPPING_METHOD_ID in (6,8,18,19,20,21,26,27,30,31,32,36,37,38,57) then 1 
    when b.SHIPPING_METHOD_ID in (59,60,61,62,63,69,70,71,72) then 2 
    when b.SHIPPING_METHOD_ID in (24,34,64,65) then 3 
    when b.SHIPPING_METHOD_ID in (28,66,68) then 4 
    when b.SHIPPING_METHOD_ID in (39,40) then 5 
    when b.SHIPPING_METHOD_ID in (25,35,43) then 6 
    when b.SHIPPING_METHOD_ID in (42) then 7 
    when b.SHIPPING_METHOD_ID in (58,67) then 8 
    when b.SHIPPING_METHOD_ID in (73,74) then 10 
   end as TRANSIT_DAYS 
 
from bt_days b 
left join d_dw.RORM_ALL q on q.line_item_id = b.line_item_id and q.requests=1 
left join d_dw.vendors v on v.company_id = q.vendor_id 
left join  D_DW.calendar as cal on datepart(cal.date_key) = datepart(b.Ordered_Datetime) 
;quit; 
 
data bt_summary; 
set bt_days_range; 
 
if datepart(closed_datetime)=date_delivered and pre_cutoff = "Before Vendor Cutoff" then Days_to_Deliver=0; 
	else if date_delivered < datepart(Closed_Datetime) then days_to_deliver = .; 
		else if pre_cutoff = "Before Vendor Cutoff" then days_to_deliver = Clo_Del_Days; 
			else days_to_deliver = Clo_Del_Days-1; 
 
if days_to_deliver = -1 then days_to_deliver=0; 

run; 
 
 
proc sql; 
create table bt_days_range2 as  
select  
* 
,case when  Days_to_deliver = 0 or Days_to_deliver LE Transit_days  then 1 else 0 end as Ontime_ID  
from work.bt_summary 
where Tracking_number is not null  
;quit; 
 
 
proc sql; 
create table tmpOntimeotals as  
select  
 Bt.Vendor_Name 
,bt.month_end 
,sum(bt.Ontime_ID) as Total_Orders_ontime 
from work.bt_days_range2 as bt 
left join D_DW.RORM_ALL as q on q.line_item_id = bt.line_item_id and q.orders= 1 
group by  
Bt.Vendor_Name 
,bt.Month_end 
;quit; 
 
 
 
 
/* Get BEst Pricer options */ 
 
proc sql; 
create table tmpbestpricemetrice AS 
select  
VR.LINE_ITEM_ID  
, V.COMPANY_NAME 
, CAL.Month_end as Month_End 
, p.part_number_stripped 
, VR.CONDITION_CODE 
, VR.EXCHANGE_COST  
, VR.OUTRIGHT_COST 
, VR.RESULT_CODE 
FROM D_DW.VENDOR_RESEARCH AS VR
inner join d_dw.line_item_details lid on lid.line_item_id = vr.line_item_id and lid.contract_pro_id is null 
left join d_dw.part_numbers as p on p.part_number_id = vr.part_number_id 
LEFT JOIN D_DW.VENDORS AS V ON V.COMPANY_ID = VR.VENDOR_ID  
left join D_DW.RORM_ALL as q on q.line_item_id = VR.LINE_ITEM_ID and q.requests=1  
left join D_DW.calendar as cal on cal.date_key = q.transaction_date  
where vr.result_code in ("HP","EHP") 
     and VR.CREATED_DATE >= '01jan13'd 
;QUIT; 
 
proc sql; 
create table tmpSORBESTMET as  
SELECT 
*  
, case  
     when EXCHANGE_COST <= 0.01  then  OUTRIGHT_COST  
     when  OUTRIGHT_COST <= 0.01 then EXCHANGE_COST   
     when EXCHANGE_COST < OUTRIGHT_COST then EXCHANGE_COST  
     else OUTRIGHT_COST   
end as New_cost  
from work.tmpbestpricemetrice 
WHERE OUTRIGHT_COST > 0.01 or EXCHANGE_COST > 0.01  
ORDER BY  
LINE_ITEM_ID 
;QUIT; 
 
/* Find the minimum cost for each condition for each line_item_id */ 
proc sql; 
create table tmpFindMinCost as 
select 
sor.LINE_ITEM_ID  
,sor.month_end 
, sor.CONDITION_CODE 
, min(sor.new_cost) as Best_Cost 
from work.tmpSORBESTMET as sor 
/*where sor.line_item_id = 1791862*/ 
group by   sor.LINE_ITEM_ID  
,sor.month_end 
,sor.CONDITION_CODE 
;Quit; 
 
/* Join back to obtain vendor for best cost options */ 
proc sql; 

create table tmpAddVendor as 
select 
sor.LINE_ITEM_ID  
,sor.month_end 
, sor.CONDITION_CODE 
, sor.COMPANY_NAME 
, count(sor.CONDITION_CODE) as total_lines 
, case  
when mc.best_cost is NULL then 0 
	else 1 
	end as best_cost_ind 
from work.tmpSORBESTMET as sor 
left join work.tmpFindMinCost as mc on mc.line_item_id = sor.line_item_id 
and mc.condition_code = sor.condition_code 
and mc.best_cost = sor.new_cost 
/*where sor.line_item_id = 1791862*/ 
group by   sor.LINE_ITEM_ID  
,sor.month_end 
, sor.CONDITION_CODE 
, sor.COMPANY_NAME 
;Quit; 
 
 
/* Group by Vendor */ 
proc sql; 
create table tmpGroupbyVendor as 
select 
av.COMPANY_NAME 
,AV.month_end 
, sum(av.total_lines) as total_lines 
, sum(av.best_cost_ind) as best_cost_ind 
, sum(av.best_cost_ind) / sum(av.total_lines) as Best_Cost_Rate format=percent8.1 
from work.tmpAddVendor as av 
group by  av.COMPANY_NAME 
,AV.month_end 
;Quit; 
 
 /* Combine Vendor RTN's , Order information , Reserch Information and Supplier Type , Best Price and Ontiem Shipping */ 
 
 
proc sql; 
create table tmpsupplierperformance as  
select  
 met.company_id as 'Suppler Id'n 
, met.company_name as 'Supplier Name'n 
, met.relationship_manager_id as 'Relationship Manager Id'n
, met.relationship_manager as 'Relationship Manager'n
, datepart(met.month_end) as 'Month End'n format = mmddyy10. 
, met.company_type_code as 'Supplier Type'n 
, v.Supplier_Type  as 'Suppler Specialty'n 
, res.Research_lines  as 'Opportunities'n  
, res.Has_part_research_line as ' Quotes Provided'n 
, bp.best_cost_ind as "Best Price"n 
, res.SS_Research_line as ' Auto Quote'n 
, met.photo_requests as 'Photo Shown'n 
, met.Total_orders as 'Total Orders'n 
, met.Auto_label as 'PartsSource Shipping Labels Used'n 
, met.Tracking_provided as ' Tracking Provided'n 
, met.smart_po as 'Automated Order'n 
, ot.Total_Orders_ontime as "Orders Delivered on Time"n 
, met.Back_order as 'Backorders'n 
, met.Total_returns as 'Total Returns'n 
, met.Customer_retrurns as 'Customer Fault'n 
, met.Shipping_retrurns aS 'Shipping Courier Faul'n 
, met.Process_RTNS  as 'Return - Process Related Issue'n 
, met.Quality_retrurns as 'Return - Quality Related Issue'n 
, met.sold_on_exchange as 'Total Exchanges'n 
, met.oem_list as 'Total OEM List'n 
, met.parts_cost as 'Total Cost'n 
,met.Total_RTN_Rev as " Total RTN Rev"n
,met.Vendor_retrurns_rev as "Vendor Coded RTN rev"n
,met.Quality_retrurns_rev as "Quality RTN rev"n
from work.tmpvendorOrderRTNcombo as met 
left join work.tmpvendorsearchcount as res on res.vendor_id  = met.company_id and res.month_end = met.month_end 
left join work.tmpvendortypefinal as v on v.company_id = met.company_id  
left join work.tmpOntimeotals as ot on ot.vendor_name = met.company_name and ot.month_end = met.month_end 
left join work.tmpGroupbyVendor as bp on bp.company_name = met.company_name and bp.month_end= met.month_end 
;quit; 


proc report data= work.tmpsupplierperformance;
run;