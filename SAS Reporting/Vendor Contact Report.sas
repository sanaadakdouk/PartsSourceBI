proc sql;  
create table tmptechnicians as  
select  
cr.requestor_id as "Contact ID"n
, cr.company_id as "Company ID"n 
, cr.company_name as "Company Name"n 
, v.relationship_manager_id as "Relationship Manager ID"n
, v.relationship_manager as "Relationship Manager"n
, r.requestor_name as "Name"n
, cr.first_name as "First Name"n 
, cr.last_name as "Last Name"n 
, v.SMART_ORDER_ENABLED
, v.SMART_LABEL_ENABLED
, cr.position_description as "Position"n 
, cr.main_phone as "Phone"n 
, cr.email_address as "Email Address"n 
, cr.salesrep_user_name as "Sale Rep"n 
, cr.Fax_Line
, cr.Direct_Line
, cr.Website
, cr.Cell_Phone
, cr.Alt_Phone
, cr.Alt_Fax
, cr.Pager
, cr.Emergency_Phone
,ao1.settings as NexT_AM_transmission
,ao2.settings as NexT_day_transmission
,ao3.settings as second_day_transmission
,ao4.settings as ground_transmission
,ao5.settings as other_transmission
from d_dw.company_requestors cr 
/* left join d_dw.companies c on c.company_id = cr.company_id 
 -- adds a join to vendors to pull relationship manager fields
    and removes join to companies table since it's not needed */
left join d_dw.vendors v on v.company_id = cr.company_id 
left join d_dw.requestors r on r.requestor_id = cr.requestor_id
left join d_dw.vendor_auto_order ao1 on ao1.vendor_id = cr.company_id and ao1.ship_priority_id = 1 
left join d_dw.vendor_auto_order ao2 on ao2.vendor_id = cr.company_id and ao2.ship_priority_id = 2
left join d_dw.vendor_auto_order ao3 on ao3.vendor_id = cr.company_id and ao3.ship_priority_id = 3
left join d_dw.vendor_auto_order ao4 on ao4.vendor_id = cr.company_id and ao4.ship_priority_id = 4
left join d_dw.vendor_auto_order ao5 on ao5.vendor_id = cr.company_id and ao5.ship_priority_id = 5 
where
 cr.active= "Y"
and cr.cc_active= "Y" 
and cr.vendor_ind = "Y"
;quit; 
 

proc print data=work.tmptechnicians noobs;
run;