/*
data _null_;
  rc = stpsrv_header('Content-type','application/vnd.ms-excel');
  rc = stpsrv_header('Content-disposition','attachment; filename=Backorder_Trends.xls');
run;
*/
*%let start_date=01dec2016;
*%let end_date=30nov2017;

*Gather Backorder Data;
proc sql;
create table backorders as
select
q.line_item_id
, ls.FIRST_ORDERED_TIMESTAMP
, datepart(ls.FIRST_ORDERED_TIMESTAMP) as Ordered_Date format=mmddyys10.
, datepart(cal.month_end) as month_end format=mmddyys10.
, q.requests
, lid.EVER_BACKORDERED
, lid.line_item_description as Description
, v.company_id as Vendor_ID
, v.company_name as Vendor_Name
, v.Relationship_Manager_ID 
, v.Relationship_Manager
, coalesce(lid.replacement_part_number_stripped,lid.requested_part_number_stripped) as Clean_Part

from d_dw.RORM_ALL q
inner join d_dw.line_item_details lid on lid.line_item_id = q.line_item_id
inner join d_dw.line_item_status_summary ls on ls.line_item_id = q.line_item_id
left join d_dw.vendors v on v.company_id = q.vendor_id
left join d_dw.calendar cal on datepart(cal.date_key) = datepart(ls.FIRST_ORDERED_TIMESTAMP)
where datepart(ls.FIRST_ORDERED_TIMESTAMP) between "&start_date"d and "&end_date"d 
	and q.requests=1 
	and ls.FIRST_ORDERED_TIMESTAMP is not null
	and lid.line_item_status_id ne 5
order by vendor_id, clean_part, ordered_date
;quit;

data work.best_description;
set work.backorders;
keep vendor_id Clean_Part Description;
by Vendor_ID Clean_Part;
if first.clean_part=1;
run;


*Vendor Summary;
proc sql;
create table Vendor_Summary as
select
vendor_id
, Vendor_Name
, Relationship_Manager_ID
, Relationship_Manager
, sum(ever_backordered) as Backorders format=comma15.
, sum(requests) as Requests format=comma15.
, sum(ever_backordered)/sum(requests) as Backorder_Percent format=percent8.1
from work.backorders
group by 1,2,3,4
having Backorders>0
order by 5 desc
;quit;

*Vendor Part Summary Trend;
proc sql;
create table Vendor_Summary_Trends as
select
b.vendor_id
, b.Vendor_Name
, b.Relationship_Manager_ID
, b.Relationship_Manager
, b.month_end
, b.clean_part
, e.description 
, sum(b.ever_backordered) as Backorders format=comma15.
, sum(b.requests) as Requests format=comma15.
from work.backorders b
inner join work.vendor_summary v on v.vendor_id = b.vendor_id /*Only Vendors with Backorders*/
left join work.best_description e on e.vendor_id = b.vendor_id and e.clean_part=b.clean_part
group by 1,2,3,4,5,6,7
;quit;


proc report data=work.vendor_summary_trends;
columns vendor_id Vendor_Name Relationship_Manager_ID Relationship_Manager month_end clean_part description Backorders Requests ;
define vendor_id / display 'Vendor ID';
define Vendor_Name / display 'Vendor Name';
define Relationship_Manager_ID / display 'Relationship Manager ID';
define Relationship_Manager / display 'Relationship Manager';
define month_end / display 'Month End Date';
define clean_part / display 'Part Number'  style={htmlstyle="vnd.ms-excel.numberformat:@"};
define description / display 'Part Description';
define Backorders / display 'Backorders';
define Requests / display 'Requests';
run;