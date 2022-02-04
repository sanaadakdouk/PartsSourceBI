/*  *Set HTTP headers ;

**The Data Null needs to be set up before the %STPBEGIN, via Management Console;

data _null_;
  rc = stpsrv_header('Content-type','application/vnd.ms-excel');
  rc = stpsrv_header('Content-disposition','attachment; filename=VendorComplianceDetails.xls');
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


proc sql;
create table vendor_details as
select
q.vendor_id
, v.company_name as Vendor
, q.line_item_id
, c.company_id as Site_Id
, c.company_name as Site_Name
, c.lvl1_company_id as Parent_Id
, c.lvl1_company_name as Parent_Name
, v.relationship_manager_id as Relationship_Manager_Id
, v.relationship_manager as Relationship_Manager
, lid.line_item_description
, ship.shipping_method

, sum(revenue)-sum(margin) as Spend format= dollar15.2
, sum(revenue) as Revenue format= dollar15.2
, sum(margin) as Margin format= dollar15.2
, sum(orders) as Orders format= comma6.
, sum(case when lid.smart_order_conf = 1 and lid.smart_order_PO = 1 and lid.smart_price_presented = 1 
			then orders else 0 end) as Smart_Order_Total
, sum(case when lid.smart_order_conf = 1 then orders else 0 end) as Smart_Conf_Total
, sum(case when lid.smart_order_PO = 1 then orders else 0 end) as Smart_PO_Total

from d_Dw.RORM_ALL q
left join d_dw.vendors v on v.company_id = q.vendor_id
inner join d_dw.line_item_details lid on lid.line_item_id = q.line_item_id and lid.contract_pro_id is null
left join d_dw.shipping_info ship on ship.line_item_id = q.line_item_id
left join d_dw.tracking_numbers t on t.line_item_id = q.line_item_id and t.shipment_leg_id  =1
left join d_dw.customers c on c.company_id = q.customer_id
where q.transaction_date between "&date_min"d and "&date_max"d and q.vendor_id ne 0 and q.orders=1
group by
q.vendor_id
, v.company_name 
, q.line_item_id
, c.company_id 
, c.company_name 
, c.lvl1_company_id 
, c.lvl1_company_name 
, v.relationship_manager_id
, v.relationship_manager
, lid.line_item_description
, ship.shipping_method
;quit;

proc report data=work.vendor_details;
columns vendor_id Vendor line_item_id Site_Id Site_Name Parent_Id Parent_Name relationship_manager_id relationship_manager
line_item_description shipping_method Spend Revenue Margin
Orders Smart_Order_Total Smart_Conf_Total Smart_PO_Total;

define vendor_id / "Vendor ID";
define Vendor / "Vendor Name";

define line_item_id / "Line Item ID";
define Site_Id / "Site ID";
define Site_Name / "Site Name";
define Parent_Id / "Parent ID";
define Parent_Name / "Parent Name";
define Relationship_Manager_Id / "Relationship Manager ID";
define Relationship_Manager / "Relationship Manager";
define line_item_description / "Line Item Description";
define shipping_method / "Shipping Method";
define Spend / "Spend";
define Revenue / "Revenue";
define Margin / "Margin";
define Orders / "Orders";
define Smart_Order_Total / "Smart Order Count";
define Smart_Conf_Total / "Smart Confirmed Count";
define Smart_PO_Total / "Smart PO Total";

quit;