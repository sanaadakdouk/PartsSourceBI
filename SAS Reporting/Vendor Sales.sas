*%let start_date = 01jan2019 ; 
*%let end_date = 30nov2021 ; 
%let vendor = 156115 ; 
 
PROC SQL;  
CREATE TABLE WORK.VEND AS  
SELECT 
Q.LINE_ITEM_ID as "Line Item ID"n 
, LID.GP_PO_NUMBER as "GP PO Number"n 
, datepart(Q.TRANSACTION_DATE) as "PO Date"n format = mmddyys10. 
, q.customer_id as "Site ID"n 
, CUST.COMPANY_NAME AS SITE_NAME as "Site Name"n 
, cust.lvl1_company_id as "Parent ID"n 
, CUST.LVL1_COMPANY_NAME AS "Parent Name"n 
, q.vendor_id as "Vendor ID"n 
, V.COMPANY_NAME AS "Vendor Name"n 
, V.RELATIONSHIP_MANAGER_ID AS "Relationship Manager ID"n
, V.RELATIONSHIP_MANAGER AS "Relationship Manager"n
, q.oem_id as "OEM ID"n 
, OEM.COMPANY_NAME as "OEM Name"n 
, case   
		when q.VENDOR_ID = 24933 then   
		/* Trim trailing character off of PartsSource Options */  
			coalesce(substr(lid.replacement_part_number_stripped, 1,length(lid.replacement_part_number_stripped)-1), lid.REQUESTED_PART_NUMBER_STRIPPED)  
		else coalesce(lid.REPLACEMENT_PART_NUMBER_STRIPPED, lid.REQUESTED_PART_NUMBER_STRIPPED)  
	  end as "Clean Part Number Stripped"n 
, case   
		when q.VENDOR_ID = 24933 then   
		/* Trim trailing character off of PartsSource Options */  
			coalesce(substr(lid.replacement_part_number, 1,length(lid.replacement_part_number)-1), lid.REQUESTED_PART_NUMBER)  
		else coalesce(lid.REPLACEMENT_PART_NUMBER, lid.REQUESTED_PART_NUMBER)  
	  end as "Clean Part Number"n 
, lid.requested_part_number as "Requested Part Number"n  
, lid.Replacement_part_number as "Replacement Part Number"n  
, LID.LINE_ITEM_DESCRIPTION AS Description 
, PCA.PRODUCT_CATEGORY_DESCRIPTION AS "Product Category"n  
, M.MODALITY_CODE AS MODALITY as Modality 
, PCL.CLASS_CODE as "Product Type"n 
, LID.MODEL_NUMBER AS MODEL as Model 
, lid.photo_shown as "Photo Shown"n 
, lid.Warranty_description as Warranty 
, org.user_name as Sourcer 
, lid.condition_code as Condition 
, q.oem_price as "Unit OEM List"n format = dollar15.2 
, Q.PRICE as "Unit Price"n format = dollar15.2 
, Q.COST as "Unit Cost"n format = dollar15.2 
 
,sum(q.orders) as Orders format = comma15. 
,sum(q.quantity) as Quantity format = comma15. 
,sum(q.revenue) as Revenue format = dollar15.2 
,sum(q.margin) as Margin format = dollar15.2 
,sum(q.revenue - q.margin) as Spend format = dollar15.2 
  
FROM D_DW.RORM_ALL Q 
inner JOIN D_DW.LINE_ITEM_DETAILS LID ON LID.LINE_ITEM_ID = Q.LINE_ITEM_ID and lid.contract_pro_id is null
LEFT JOIN D_DW.CUSTOMERS CUST ON Q.CUSTOMER_ID = CUST.COMPANY_ID  
LEFT JOIN D_DW.VENDORS V ON Q.VENDOR_ID = V.COMPANY_ID  
LEFT JOIN d_dw.OEMS OEM on OEM.company_id = q.oem_id  
LEFT JOIN D_DW.MODALITIES M ON Q.MODALITY_ID = M.MODALITY_ID  
LEFT JOIN D_DW.PRODUCT_CLASSES PCL ON PCL.CLASS_ID = Q.CLASS_ID  
INNER JOIN D_DW.PRODUCT_CATEGORIES PCA ON PCA.PRODUCT_CATEGORY_ID = Q.PRODUCT_CATEGORY_ID  
left join d_dw.organization org on org.organization_id = q.sourced_by_id  
  
WHERE datepart(Q.TRANSACTION_DATE) BETWEEN "&start_date"d AND "&end_date"d 
	and q.vendor_id = &vendor 
 
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29 
 
having orders ne 0 or quantity ne 0 or revenue ne 0 or margin ne 0 
 
ORDER BY "PO Date"n 
 
;QUIT;  
 
Proc Print data=work.vend noobs;  
run;