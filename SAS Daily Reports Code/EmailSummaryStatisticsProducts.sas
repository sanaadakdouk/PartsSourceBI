


data _null_;
CALL SYMPUT('DATE', TRIM(LEFT(PUT(today()-1,date9.))) ) ;
run; 




*Email Distribution;
%let email_list = "currentstatsdaily@partssource.com""creeves@partssource.com";;
*%let email_list = "cakalchthaler@partssource.com"; *Test Emails;

*Subject Line Message;
%let subject = Daily Sales Reporting Dashboard;


*****************************************************************************************************************************
													Daily Budget Values Section
*****************************************************************************************************************************;


data _null_;
 CALL SYMPUT('current_date', TRIM(LEFT(PUT(today()-1,date9.))) ) ;
run; 



*Month Start and End;
data _null_;
CALL SYMPUT('month_start', TRIM(LEFT(PUT(intnx("Month","&current_date"d,0,"b"),date9.)))  )  ;
CALL SYMPUT('year_start', TRIM(LEFT(PUT(intnx("Year","&current_date"d,0,"b"),date9.)))  )  ;
CALL SYMPUT('month_end', TRIM(LEFT(PUT(intnx("Month","&current_date"d,0,"e"),date9.)))  )  ;
run; 

*Month Workdays;
proc sql noprint;
select
sum(workday_ind)
into :month_workdays
from d_Dw.calendar (dbsastype=workday_ind="numeric")
where date_key between "&month_start"d and "&current_date"d
;quit;

*Week Start;
Proc sql noprint;
select
datepart(week_start) format date9.
into :week_start
from d_dw.calendar 
where date_key = "&current_date"d
;quit;

*Week Workdays;
proc sql noprint;
select
sum(workday_ind)
into :week_workdays
from d_Dw.calendar (dbsastype=workday_ind="numeric")
where date_key between "&week_start"d and "&current_date"d
;quit;

*Construct Calendar Table for Daily values;
proc sql;
create table Calendar2022 as
select
month_end
, date_key
, workday_ind
from d_dw.calendar cal
where year=(year("&current_date"d))
;quit;

proc sql;
create table temp_values as
select
b.SEGMENT
, b.SORT as Segment_Sort
, datepart(c.MONTH_END) as Month_end format=date9.
, datepart(c.date_key) as Transaction_date format=date9.
, b.BUDGET_REVENUE/days*workday_ind as Budget_Revenue format=dollar15.2
, b.BUDGET_MARGIN/days*workday_ind as BUDGET_MARGIN format=dollar15.2
, b.REVENUE/days*workday_ind as REVENUE format=dollar15.2
, b.MARGIN/days*workday_ind as MARGIN format=dollar15.2
, b.DAYS

from work.calendar2022 c
left join d_dw.Budget_Import_2022_Supplement b on b.month_end = c.month_end
;quit;

*Program Start;
proc sql;
create table gather_data as
select
case 
	when upper(left(SEGMENT))in ("ENTERPRISE") then "Enterprise"
	when upper(left(SEGMENT))in ("SODEXO") then "Sodexo"
	when upper(left(SUB_SEGMENT))in ("PROVIDER") then "Provider"
	when upper(left(SUB_SEGMENT)) in ("ISO")then "ISO"
	when upper(left(SUB_SEGMENT)) = "GOVERNMENT" then "Government"
	else "Provider" end as Segment
,case 
	when upper(left(SEGMENT))in ("ENTERPRISE") then 1
		when upper(left(SEGMENT))in ("SODEXO") then 2
	when upper(left(SUB_SEGMENT))in ("PROVIDER") then 3
	when upper(left(SUB_SEGMENT)) in ("ISO")  then 4
	when upper(left(SUB_SEGMENT))  = "GOVERNMENT" then 5
	else 3 end as Segment_Sort
, sum(case when datepart(transaction_date) = "&current_date"d then Actual_Revenue else 0 end) as Actual_Revenue_Day format=dollar15.
, sum(case when datepart(transaction_date) = "&current_date"d then Budget_Revenue else 0 end) as Budget_Revenue_Day format=dollar15.
, sum(case when datepart(transaction_date) between "&week_start"d and "&current_date"d then Actual_Revenue else 0 end)/&week_workdays as Actual_Revenue_Week_Avg format=dollar15.
, sum(case when datepart(transaction_date) between "&month_start"d and "&current_date"d then Actual_Revenue else 0 end)/&month_workdays as Actual_Revenue_Month_Avg format=dollar15.

, sum(case when datepart(transaction_date) = "&current_date"d then Actual_Margin else 0 end) as Actual_Margin_Day format=dollar15.
, sum(case when datepart(transaction_date) = "&current_date"d then Budget_Margin else 0 end) as Budget_Margin_Day format=dollar15.
, sum(case when datepart(transaction_date) between "&week_start"d and "&current_date"d then Actual_Margin else 0 end)/&week_workdays as Actual_Margin_Week_Avg format=dollar15.
, sum(case when datepart(transaction_date) between "&month_start"d and "&current_date"d then Actual_Margin else 0 end)/&month_workdays as Actual_Margin_Month_Avg format=dollar15.

, sum(Actual_Revenue) as Actual_Revenue_Year format=dollar15.
, sum(Budget_Revenue) as Budget_Revenue_Year format=dollar15.
, sum(Actual_Margin) as Actual_Margin_Year format=dollar15.
, sum(Budget_Margin) as Budget_Margin_Year format=dollar15.
from D_DW.DAILY_BUDGET_FORECAST_AND_ACTUAL (dbsastype=Actual_Revenue="numeric")
where Transaction_date between "&year_start"d and "&current_date"d 
group by 1,2
UNION ALL
select
Segment 
, segment_sort 

, sum(case when (transaction_date) = "&current_date"d then Revenue else 0 end) as Actual_Revenue_Day format=dollar15.
, sum(case when (transaction_date) = "&current_date"d then Budget_Revenue else 0 end) as Budget_Revenue_Day format=dollar15.
, sum(case when (transaction_date) between "&week_start"d and "&current_date"d then Revenue else 0 end)/&week_workdays as Actual_Revenue_Week_Avg format=dollar15.
, sum(case when (transaction_date) between "&month_start"d and "&current_date"d then Revenue else 0 end)/&month_workdays as Actual_Revenue_Month_Avg format=dollar15.

, sum(case when (transaction_date) = "&current_date"d then Margin else 0 end) as Actual_Margin_Day format=dollar15.
, sum(case when (transaction_date) = "&current_date"d then Budget_Margin else 0 end) as Budget_Margin_Day format=dollar15.
, sum(case when (transaction_date) between "&week_start"d and "&current_date"d then Margin else 0 end)/&week_workdays as Actual_Margin_Week_Avg format=dollar15.
, sum(case when (transaction_date) between "&month_start"d and "&current_date"d then Margin else 0 end)/&month_workdays as Actual_Margin_Month_Avg format=dollar15.

, sum(Revenue) as Actual_Revenue_Year format=dollar15.
, sum(Budget_Revenue) as Budget_Revenue_Year format=dollar15.
, sum(Margin) as Actual_Margin_Year format=dollar15.
, sum(Budget_Margin) as Budget_Margin_Year format=dollar15.
from work.temp_values
where transaction_date between "&year_start"d and "&current_date"d
group by 1,2
order by 2


;quit;

proc sql;
create table Combined_Data as
select
Segment 
, segment_sort
, sum(Actual_Revenue_Day) as Actual_Revenue_Day format=dollar15.
, sum(Budget_Revenue_Day) as Budget_Revenue_Day format=dollar15.
, sum(Actual_Revenue_Week_Avg) as Actual_Revenue_Week_Avg  format=dollar15.
, sum(Actual_Revenue_Month_Avg) as Actual_Revenue_Month_Avg format=dollar15.
, sum(Actual_Margin_Day) as Actual_Margin_Day format=dollar15.
, sum(Budget_Margin_Day) as Budget_Margin_Day format=dollar15.
, sum(Actual_Margin_Week_Avg) as Actual_Margin_Week_Avg format=dollar15.
, sum(Actual_Margin_Month_Avg) as Actual_Margin_Month_Avg format=dollar15.

, sum(Actual_Revenue_Year) as Actual_Revenue_Year format=dollar15.
, sum(Budget_Revenue_Year) as Budget_Revenue_Year format=dollar15.
, sum(Actual_Margin_Year) as Actual_Margin_Year format=dollar15.
, sum(Budget_Margin_Year) as Budget_Margin_Year format=dollar15.
from work.gather_data G
group by 1,2
UNION ALL
select
'Estimated Total' as Segment
, 99 as Segment_sort
, sum(Actual_Revenue_Day) as Actual_Revenue_Day
, sum(Budget_Revenue_Day) as Budget_Revenue_Day
, sum(Actual_Revenue_Week_Avg) as Actual_Revenue_Week_Avg
, sum(Actual_Revenue_Month_Avg) as Actual_Revenue_Month_Avg

, sum(Actual_Margin_Day) as Actual_Margin_Day
, sum(Budget_Margin_Day) as Budget_Margin_Day
, sum(Actual_Margin_Week_Avg) as Actual_Margin_Week_Avg
, sum(Actual_Margin_Month_Avg) as Actual_Margin_Month_Avg

, sum(Actual_Revenue_Year) as Actual_Revenue_Year format=dollar15.
, sum(Budget_Revenue_Year) as Budget_Revenue_Year format=dollar15.
, sum(Actual_Margin_Year) as Actual_Margin_Year format=dollar15.
, sum(Budget_Margin_Year) as Budget_Margin_Year format=dollar15.
from work.gather_data 
order by 2
;quit;

*****************************************************************************************************************************
										Billing Transactions Over/Under $25,000 Section
*****************************************************************************************************************************;


proc sql;
create table salvages as
SELECT        
A.SALVAGE_LINE_ITEM_ID                              
 , MIN(a.CREATED_TIMESTAMP) AS SALVAGED_PO_DATE  
FROM D_DW.RETURNS_ALL A  
WHERE A.ACTIVE = 'Y' 
GROUP BY  A.SALVAGE_LINE_ITEM_ID
;quit;

proc sql; 
create table bill_sum as 
SELECT 
RV.LINE_ITEM_ID  AS  LINE_ITEM_ID                       
, datepart(RV.TRANSACTION_DATE)   AS TXN_DATE    format = date9. 
, vend.COMPANY_NAME  AS VENDOR_NAME 
, CU.COMPANY_NAME  AS CUSTOMER_NAME                      
, LI.LINE_ITEM_DESCRIPTION AS LINE_ITEM_DESCRIPTION                        
, LI.LINE_ITEM_PO AS CUSTOMER_PO                       
, RV.OEM_PRICE AS OEM_PRICE                        
, OR.USER_NAME  AS SALESREP_NAME                        
, mod.MODALITY_CODE AS MODALITY                      
, class.CLASS_CODE AS Product_TYPE                          
, cat.PRODUCT_CATEGORY_DESCRIPTION  AS PRODUCT_CATEGORY                    
, datepart(SA.SALVAGED_PO_DATE) AS SALVAGED_PO_DATE  format = date9.            
, SUM(RV.QUANTITY) AS QUANTITY               
, SUM(RV.REVENUE) AS EXT_PRICE                                                                                                              
, SUM(RV.REVENUE) - SUM(RV.MARGIN)  AS EXT_COST      
, SUM(RV.MARGIN)   AS EXT_MARGIN_DOLLARS      
, SUM(RV.REQUESTS)  AS REQUESTS                        
, SUM(RV.ORDERS)  AS ORDERS                         
, SUM(RV.RETURNS)  AS RETURNS                         
FROM D_DW.RORM_ALL RV                                      
left JOIN D_DW.CUSTOMERS   CU ON RV.CUSTOMER_ID = CU.COMPANY_ID                                      
LEFT JOIN D_DW.LINE_ITEM_DETAILS LI ON RV.LINE_ITEM_ID = LI.LINE_ITEM_ID                                     
LEFT JOIN D_DW.ORGANIZATION OR ON RV.SALES_REP_ID = OR.ORGANIZATION_ID                            
LEFT JOIN work.salvages  SA ON RV.LINE_ITEM_ID = SA.SALVAGE_LINE_ITEM_ID            
 
left join d_dw.modalities mod ON RV.MODALITY_ID = mod.MODALITY_ID 
left join d_dw.PRODUCT_CLASSES class ON RV.MODALITY_ID = class.CLASS_ID 
left JOIN d_dw.PRODUCT_CATEGORIES cat on RV.PRODUCT_CATEGORY_ID  = cat.PRODUCT_CATEGORY_ID  
left join d_dw.VENDORS as vend on vend.company_id = rv.vendor_id
WHERE RV.TRANSACTION_DATE = "&DATE"d 
     
GROUP BY RV.LINE_ITEM_ID                                                                                                                       
, RV.TRANSACTION_DATE   
, vend.COMPANY_NAME 
, CU.COMPANY_NAME                                                                                                                              
, LI.LINE_ITEM_DESCRIPTION                                                                                                                             
, LI.LINE_ITEM_PO 
, RV.OEM_PRICE   
, OR.USER_NAME                                                                                                                                  
, MODALITY                                                                                                               
, Product_TYPE                                                                                                                                   
, PRODUCT_CATEGORY                                     
, SA.SALVAGED_PO_DATE 
;quit;

 
 
proc sql; 
create table bill_sum2 as   
 SELECT LINE_ITEM_ID                       
, TXN_DATE   
, VENDOR_NAME
, CUSTOMER_NAME                      
, LINE_ITEM_DESCRIPTION                        
, CUSTOMER_PO                       
, SUM(QUANTITY) AS QUANTITY               
, SUM(OEM_PRICE)    AS OEM_PRICE                        
, SUM(EXT_PRICE)   AS EXT_PRICE                                                                                                              
, SUM(EXT_COST)      AS EXT_COST      
, SUM(EXT_MARGIN_DOLLARS)       AS EXT_MARGIN_DOLLARS      
, SUM(REQUESTS)                                     AS REQUESTS                        
, SUM(ORDERS)                                        AS ORDERS                         
, SUM(RETURNS)                                     AS RETURNS                         
, SALESREP_NAME                        
, MODALITY                                                                                                               
, Product_TYPE                                                                                                                                   
, PRODUCT_CATEGORY                        
, SALVAGED_PO_DATE              
FROM bill_sum 
GROUP BY LINE_ITEM_ID                       
, TXN_DATE   
, VENDOR_NAME
, CUSTOMER_NAME                      
, LINE_ITEM_DESCRIPTION                        
, CUSTOMER_PO               
, SALESREP_NAME                        
, MODALITY                                                                                                               
, Product_TYPE                                                                                                                                   
, PRODUCT_CATEGORY                        
, SALVAGED_PO_DATE      
;quit; 
 
proc sql; 
create table t1 as 
select 
LINE_ITEM_ID as  "Ref #"N 
, CASE WHEN ORDERS > 0 and RETURNS = 0 THEN 'O' 
           WHEN ORDERS=0 and RETURNS > 0 THEN 'R' 
           WHEN ORDERS>0 and RETURNS > 0 THEN 'O/R' 
           WHEN ORDERS=0 and RETURNS = 0 THEN 'PC' 
           ELSE 'N/A' END as Type 
, TXN_DATE  as "Trx Date"n 
, VENDOR_NAME as 'Vendor'n
, CUSTOMER_NAME as 'Customer'n                
, LINE_ITEM_DESCRIPTION as 'Description'n                   
, CUSTOMER_PO as 'Customer PO #'n 
, QUANTITY as 'QTY'n 
, OEM_PRICE as 'OEM Price'n   format=dollar15.2               
, EXT_PRICE as Revenue    format=dollar15.2                                                                                             
, EXT_COST as Cost format=dollar15.2 
, EXT_MARGIN_DOLLARS as Margin format=dollar15.2  /*Dollar format needs to be more than 9.2 ($0,000.00 is 9 characters)*/ 
, EXT_MARGIN_DOLLARS/EXT_PRICE as 'Margin %'n format=percent8.1 /*Percent format tends to work best at 8.1 or 9.2 to allow for (,), and %*/ 
 
, SALESREP_NAME as AM 
, case when SALVAGED_PO_DATE is not null then 'Y' else '' end as Salvage 
from bill_sum2 
where Ext_Price >=25000 or ext_price <=-25000
;quit; 
 

*****************************************************************************************************************************
													Summary Statistics Section
*****************************************************************************************************************************;

/* Create formats for negative values */
proc format;                           
   picture mypct low-0='0,009.0%)' (prefix='(')  
                 other='0,009.0%';
   picture mydlr 
   /* without negatives */
   other='000,000,000' (prefix='$')
   /* with negatives */
   low-0='000,000,000)' (prefix='($');

   value negfmt
   low-0='red';
run;

proc sql;
create table BFA_setup as
select
REPORT_DATE
,SEGMENT
,PRODUCT_CATEGORY_DESCRIPTION
,CY_MTD_BUDGET_REQUESTS
,CY_MTD_BUDGET_ORDERS
,CY_MTD_BUDGET_REVENUE
,CY_MTD_BUDGET_MARGIN
,CY_MTD_FORECAST_REQUESTS
,CY_MTD_FORECAST_ORDERS
,CY_MTD_FORECAST_REVENUE
,CY_MTD_FORECAST_MARGIN
,CY_MTD_ACTUAL_REQUESTS
,CY_MTD_ACTUAL_ORDERS
,CY_MTD_ACTUAL_REVENUE
,CY_MTD_ACTUAL_MARGIN
,CY_YTD_BUDGET_REQUESTS
,CY_YTD_BUDGET_ORDERS
,CY_YTD_BUDGET_REVENUE
,CY_YTD_BUDGET_MARGIN
,CY_YTD_FORECAST_REQUESTS
,CY_YTD_FORECAST_ORDERS
,CY_YTD_FORECAST_REVENUE
,CY_YTD_FORECAST_MARGIN
,CY_YTD_ACTUAL_REQUESTS
,CY_YTD_ACTUAL_ORDERS
,CY_YTD_ACTUAL_REVENUE
,CY_YTD_ACTUAL_MARGIN
,CY_QTD_BUDGET_REQUESTS
,CY_QTD_BUDGET_ORDERS
,CY_QTD_BUDGET_REVENUE
,CY_QTD_BUDGET_MARGIN
,CY_QTD_FORECAST_REQUESTS
,CY_QTD_FORECAST_ORDERS
,CY_QTD_FORECAST_REVENUE
,CY_QTD_FORECAST_MARGIN
,CY_QTD_ACTUAL_REQUESTS
,CY_QTD_ACTUAL_ORDERS
,CY_QTD_ACTUAL_REVENUE
,CY_QTD_ACTUAL_MARGIN
,PY_MTD_BUDGET_REQUESTS
,PY_MTD_BUDGET_ORDERS
,PY_MTD_BUDGET_REVENUE
,PY_MTD_BUDGET_MARGIN
,PY_MTD_FORECAST_REQUESTS
,PY_MTD_FORECAST_ORDERS
,PY_MTD_FORECAST_REVENUE
,PY_MTD_FORECAST_MARGIN
,PY_MTD_ACTUAL_REQUESTS
,PY_MTD_ACTUAL_ORDERS
,PY_MTD_ACTUAL_REVENUE
,PY_MTD_ACTUAL_MARGIN
,PY_YTD_BUDGET_REQUESTS
,PY_YTD_BUDGET_ORDERS
,PY_YTD_BUDGET_REVENUE
,PY_YTD_BUDGET_MARGIN
,PY_YTD_FORECAST_REQUESTS
,PY_YTD_FORECAST_ORDERS
,PY_YTD_FORECAST_REVENUE
,PY_YTD_FORECAST_MARGIN
,PY_YTD_ACTUAL_REQUESTS
,PY_YTD_ACTUAL_ORDERS
,PY_YTD_ACTUAL_REVENUE
,PY_YTD_ACTUAL_MARGIN
,PY_QTD_ACTUAL_REQUESTS
,PY_QTD_ACTUAL_ORDERS
,PY_QTD_ACTUAL_REVENUE
,PY_QTD_ACTUAL_MARGIN
,CY_MTD_BUDGET_REVENUE_K
,CY_MTD_BUDGET_MARGIN_K
,CY_MTD_FORECAST_REVENUE_K
,CY_MTD_FORECAST_MARGIN_K
,CY_MTD_ACTUAL_REVENUE_K
,CY_MTD_ACTUAL_MARGIN_K
,CY_QTD_BUDGET_REVENUE_K
,CY_QTD_BUDGET_MARGIN_K
,CY_QTD_FORECAST_REVENUE_K
,CY_QTD_FORECAST_MARGIN_K
,CY_QTD_ACTUAL_REVENUE_K
,CY_QTD_ACTUAL_MARGIN_K
,CY_YTD_BUDGET_REVENUE_K
,CY_YTD_BUDGET_MARGIN_K
,CY_YTD_FORECAST_REVENUE_K
,CY_YTD_FORECAST_MARGIN_K
,CY_YTD_ACTUAL_REVENUE_K
,CY_YTD_ACTUAL_MARGIN_K
,PY_MTD_BUDGET_REVENUE_K
,PY_MTD_BUDGET_MARGIN_K
,PY_MTD_FORECAST_REVENUE_K
,PY_MTD_FORECAST_MARGIN_K
,PY_MTD_ACTUAL_REVENUE_K
,PY_MTD_ACTUAL_MARGIN_K
,PY_YTD_BUDGET_REVENUE_K
,PY_YTD_BUDGET_MARGIN_K
,PY_YTD_FORECAST_REVENUE_K
,PY_YTD_FORECAST_MARGIN_K
,PY_YTD_ACTUAL_REVENUE_K
,PY_YTD_ACTUAL_MARGIN_K
,PY_QTD_ACTUAL_REVENUE_K
,PY_QTD_ACTUAL_MARGIN_K

, (select max(workday_nbr_mtd) from d_dw.calendar cal where cal.date_key = ba.report_date) as workdays
, (select max(workday_nbr_ytd) from d_dw.calendar cal where cal.date_key = ba.report_date) as workdays_ytd
, (select max(workday_nbr_mtd) from d_dw.calendar cal 
	where year(cal.date_key) = year(ba.report_date)-1 and month(cal.date_key) = month(ba.report_date)) as workdays_py_mtd
, (select max(workday_nbr_mtd) from d_dw.calendar cal 
	where year(cal.date_key) = year(ba.report_date) and month(cal.date_key) = month(ba.report_date)) as workdays_cy_mtd
from d_dw.budget_forecast_and_actual ba 

;quit;


proc sql;
create table BFA_output as
select
/*Total*/
'Total' as customer_segment
, 'Revenue' as Metric
, sum(cy_mtd_actual_revenue) as MTD_ACTUAL
, sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue) as MTD_VAR
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/sum(cy_mtd_Budget_revenue) as MTD_VAR_PCT

, sum(cy_mtd_actual_revenue)-sum(py_mtd_actual_revenue) as MTD_VAR_PRI_MTD
, (sum(cy_mtd_actual_revenue)-sum(py_mtd_actual_revenue))/sum(py_mtd_actual_revenue) as MTD_VAR_PRI_MTD_PCT

, sum(cy_ytd_actual_revenue) as YTD_ACTUAL
, sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue) as YTD_VAR
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/sum(cy_ytd_Budget_revenue) as YTD_VAR_PCT

, sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD_PCT
from BFA_setup

union all
select
'Total' as customer_segment
, 'Margin' as Metric
, sum(cy_mtd_actual_margin) as MTD_ACTUAL
, sum(cy_mtd_actual_margin)-sum(cy_mtd_Budget_margin) as MTD_VAR
, (sum(cy_mtd_actual_margin)-sum(cy_mtd_Budget_margin))/sum(cy_mtd_Budget_margin) as MTD_VAR_PCT

, sum(cy_mtd_actual_margin)-sum(py_mtd_actual_margin) as MTD_VAR_PRI_MTD
, (sum(cy_mtd_actual_margin)-sum(py_mtd_actual_margin))/sum(py_mtd_actual_margin) as MTD_VAR_PRI_MTD_PCT

, sum(cy_ytd_actual_margin) as YTD_ACTUAL
, sum(cy_ytd_actual_margin)-sum(cy_ytd_Budget_margin) as YTD_VAR
, (sum(cy_ytd_actual_margin)-sum(cy_ytd_Budget_margin))/sum(cy_ytd_Budget_margin) as YTD_VAR_PCT

, sum(cy_ytd_actual_margin)-sum(py_ytd_actual_margin) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_margin)-sum(py_ytd_actual_margin))/sum(py_ytd_actual_margin) as YTD_VAR_PRI_YTD_PCT
from BFA_setup
union all

select
'Total' as customer_segment
, 'GM %' as Metric
, sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue) as MTD_ACTUAL
, sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue)-(sum(cy_mtd_Budget_margin)/sum(cy_mtd_Budget_revenue)) as MTD_VAR
, . as MTD_VAR_PCT

, (sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue))-(sum(py_mtd_actual_margin)/sum(py_mtd_actual_revenue)) as MTD_VAR_PRI_MTD
, . as MTD_VAR_PRI_MTD_PCT

, (sum(cy_ytd_actual_margin))/(sum(cy_ytd_actual_revenue)) as YTD_ACTUAL
, (sum(cy_ytd_actual_margin)/sum(cy_ytd_actual_revenue))-(sum(cy_ytd_Budget_margin)/sum(cy_ytd_Budget_revenue)) as YTD_VAR
, . as YTD_VAR_PCT

, (sum(cy_ytd_actual_margin)/sum(cy_ytd_actual_revenue))-(sum(py_ytd_actual_margin)/sum(py_ytd_actual_revenue)) as YTD_VAR_PRI_YTD
, . as YTD_VAR_PRI_YTD_PCT

from BFA_setup
union all

select
'Total' as customer_segment
, 'AVG REV' as Metric
, sum(cy_mtd_actual_revenue)/mean(workdays) as MTD_ACTUAL
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/mean(workdays) as MTD_VAR
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/sum(cy_mtd_Budget_revenue) as MTD_VAR_PCT

, (sum(cy_mtd_actual_revenue)/mean(workdays)
	-sum(py_mtd_actual_revenue)/mean(workdays)/mean(workdays_py_mtd)*mean(workdays_cy_mtd)) as MTD_VAR_PRI_MTD
, 1-(sum(py_mtd_actual_revenue)/mean(workdays)/mean(workdays_py_mtd)*mean(workdays_cy_mtd)
	/(sum(cy_mtd_actual_revenue)/mean(workdays))) as MTD_VAR_PRI_MTD_PCT

, (sum(cy_ytd_actual_revenue))/mean(workdays_ytd) as YTD_ACTUAL
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/mean(workdays_ytd) as YTD_VAR
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/sum(cy_ytd_Budget_revenue) as YTD_VAR_PCT

, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/mean(workdays_ytd) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD_PCT
from BFA_setup
union all

/*Ex ARAMARK*/
select
'Biomed' as customer_segment
, 'Revenue' as Metric
, sum(cy_mtd_actual_revenue) as MTD_ACTUAL
, sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue) as MTD_VAR
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/sum(cy_mtd_Budget_revenue) as MTD_VAR_PCT

, sum(cy_mtd_actual_revenue)-sum(py_mtd_actual_revenue) as MTD_VAR_PRI_MTD
, (sum(cy_mtd_actual_revenue)-sum(py_mtd_actual_revenue))/sum(py_mtd_actual_revenue) as MTD_VAR_PRI_MTD_PCT

, sum(cy_ytd_actual_revenue) as YTD_ACTUAL
, sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue) as YTD_VAR
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/sum(cy_ytd_Budget_revenue) as YTD_VAR_PCT

, sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD_PCT
from BFA_setup
where product_category_description in ("Biomed","Stryker")

union all
select
'Biomed' as customer_segment
, 'Margin' as Metric
, sum(cy_mtd_actual_margin) as MTD_ACTUAL
, sum(cy_mtd_actual_margin)-sum(cy_mtd_Budget_margin) as MTD_VAR
, (sum(cy_mtd_actual_margin)-sum(cy_mtd_Budget_margin))/sum(cy_mtd_Budget_margin) as MTD_VAR_PCT

, sum(cy_mtd_actual_margin)-sum(py_mtd_actual_margin) as MTD_VAR_PRI_MTD
, (sum(cy_mtd_actual_margin)-sum(py_mtd_actual_margin))/sum(py_mtd_actual_margin) as MTD_VAR_PRI_MTD_PCT

, sum(cy_ytd_actual_margin) as YTD_ACTUAL
, sum(cy_ytd_actual_margin)-sum(cy_ytd_Budget_margin) as YTD_VAR
, (sum(cy_ytd_actual_margin)-sum(cy_ytd_Budget_margin))/sum(cy_ytd_Budget_margin) as YTD_VAR_PCT

, sum(cy_ytd_actual_margin)-sum(py_ytd_actual_margin) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_margin)-sum(py_ytd_actual_margin))/sum(py_ytd_actual_margin) as YTD_VAR_PRI_YTD_PCT
from BFA_setup
where product_category_description in ("Biomed","Stryker")
union all

select
'Biomed' as customer_segment
, 'GM %' as Metric
, sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue) as MTD_ACTUAL
, sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue)-(sum(cy_mtd_Budget_margin)/sum(cy_mtd_Budget_revenue)) as MTD_VAR
, . as MTD_VAR_PCT

, (sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue))-(sum(py_mtd_actual_margin)/sum(py_mtd_actual_revenue)) as MTD_VAR_PRI_MTD
, . as MTD_VAR_PRI_MTD_PCT

, (sum(cy_ytd_actual_margin))/(sum(cy_ytd_actual_revenue)) as YTD_ACTUAL
, (sum(cy_ytd_actual_margin)/sum(cy_ytd_actual_revenue))-(sum(cy_ytd_Budget_margin)/sum(cy_ytd_Budget_revenue)) as YTD_VAR
, . as YTD_VAR_PCT

, (sum(cy_ytd_actual_margin)/sum(cy_ytd_actual_revenue))-(sum(py_ytd_actual_margin)/sum(py_ytd_actual_revenue)) as YTD_VAR_PRI_YTD
, . as YTD_VAR_PRI_YTD_PCT

from BFA_setup
where product_category_description in ("Biomed","Stryker")
union all

select
'Biomed' as customer_segment
, 'AVG REV' as Metric
, sum(cy_mtd_actual_revenue)/mean(workdays) as MTD_ACTUAL
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/mean(workdays) as MTD_VAR
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/sum(cy_mtd_Budget_revenue) as MTD_VAR_PCT

, (sum(cy_mtd_actual_revenue)/mean(workdays)
	-sum(py_mtd_actual_revenue)/mean(workdays)/mean(workdays_py_mtd)*mean(workdays_cy_mtd)) as MTD_VAR_PRI_MTD
, 1-(sum(py_mtd_actual_revenue)/mean(workdays)/mean(workdays_py_mtd)*mean(workdays_cy_mtd)
	/(sum(cy_mtd_actual_revenue)/mean(workdays))) as MTD_VAR_PRI_MTD_PCT

, (sum(cy_ytd_actual_revenue))/mean(workdays_ytd) as YTD_ACTUAL
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/mean(workdays_ytd) as YTD_VAR
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/sum(cy_ytd_Budget_revenue) as YTD_VAR_PCT

, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/mean(workdays_ytd) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD_PCT
from BFA_setup
where product_category_description in ("Biomed","Stryker")
union all

/*ARAMARK*/
select
'Imaging' as customer_segment
, 'Revenue' as Metric
, sum(cy_mtd_actual_revenue) as MTD_ACTUAL
, sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue) as MTD_VAR
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/sum(cy_mtd_Budget_revenue) as MTD_VAR_PCT

, sum(cy_mtd_actual_revenue)-sum(py_mtd_actual_revenue) as MTD_VAR_PRI_MTD
, (sum(cy_mtd_actual_revenue)-sum(py_mtd_actual_revenue))/sum(py_mtd_actual_revenue) as MTD_VAR_PRI_MTD_PCT

, sum(cy_ytd_actual_revenue) as YTD_ACTUAL
, sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue) as YTD_VAR
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/sum(cy_ytd_Budget_revenue) as YTD_VAR_PCT

, sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD_PCT
from BFA_setup
where product_category_description not in  ("Biomed","Stryker")

union all
select
'Imaging' as customer_segment
, 'Margin' as Metric
, sum(cy_mtd_actual_margin) as MTD_ACTUAL
, sum(cy_mtd_actual_margin)-sum(cy_mtd_Budget_margin) as MTD_VAR
, (sum(cy_mtd_actual_margin)-sum(cy_mtd_Budget_margin))/sum(cy_mtd_Budget_margin) as MTD_VAR_PCT

, sum(cy_mtd_actual_margin)-sum(py_mtd_actual_margin) as MTD_VAR_PRI_MTD
, (sum(cy_mtd_actual_margin)-sum(py_mtd_actual_margin))/sum(py_mtd_actual_margin) as MTD_VAR_PRI_MTD_PCT

, sum(cy_ytd_actual_margin) as YTD_ACTUAL
, sum(cy_ytd_actual_margin)-sum(cy_ytd_Budget_margin) as YTD_VAR
, (sum(cy_ytd_actual_margin)-sum(cy_ytd_Budget_margin))/sum(cy_ytd_Budget_margin) as YTD_VAR_PCT

, sum(cy_ytd_actual_margin)-sum(py_ytd_actual_margin) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_margin)-sum(py_ytd_actual_margin))/sum(py_ytd_actual_margin) as YTD_VAR_PRI_YTD_PCT
from BFA_setup
where product_category_description not in ("Biomed","Stryker")
union all

select
'Imaging' as customer_segment
, 'GM %' as Metric
, sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue) as MTD_ACTUAL
, sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue)-(sum(cy_mtd_Budget_margin)/sum(cy_mtd_Budget_revenue)) as MTD_VAR
, . as MTD_VAR_PCT

, (sum(cy_mtd_actual_margin)/sum(cy_mtd_actual_revenue))-(sum(py_mtd_actual_margin)/sum(py_mtd_actual_revenue)) as MTD_VAR_PRI_MTD
, . as MTD_VAR_PRI_MTD_PCT

, (sum(cy_ytd_actual_margin))/(sum(cy_ytd_actual_revenue)) as YTD_ACTUAL
, (sum(cy_ytd_actual_margin)/sum(cy_ytd_actual_revenue))-(sum(cy_ytd_Budget_margin)/sum(cy_ytd_Budget_revenue)) as YTD_VAR
, . as YTD_VAR_PCT

, (sum(cy_ytd_actual_margin)/sum(cy_ytd_actual_revenue))-(sum(py_ytd_actual_margin)/sum(py_ytd_actual_revenue)) as YTD_VAR_PRI_YTD
, . as YTD_VAR_PRI_YTD_PCT

from BFA_setup
where product_category_description not in ("Biomed","Stryker")
union all

select
'Imaging' as customer_segment
, 'AVG REV' as Metric
, sum(cy_mtd_actual_revenue)/mean(workdays) as MTD_ACTUAL
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/mean(workdays) as MTD_VAR
, (sum(cy_mtd_actual_revenue)-sum(cy_mtd_Budget_revenue))/sum(cy_mtd_Budget_revenue) as MTD_VAR_PCT

, (sum(cy_mtd_actual_revenue)/mean(workdays)
	-sum(py_mtd_actual_revenue)/mean(workdays)/mean(workdays_py_mtd)*mean(workdays_cy_mtd)) as MTD_VAR_PRI_MTD
, 1-(sum(py_mtd_actual_revenue)/mean(workdays)/mean(workdays_py_mtd)*mean(workdays_cy_mtd)
	/(sum(cy_mtd_actual_revenue)/mean(workdays))) as MTD_VAR_PRI_MTD_PCT

, (sum(cy_ytd_actual_revenue))/mean(workdays_ytd) as YTD_ACTUAL
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/mean(workdays_ytd) as YTD_VAR
, (sum(cy_ytd_actual_revenue)-sum(cy_ytd_Budget_revenue))/sum(cy_ytd_Budget_revenue) as YTD_VAR_PCT

, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/mean(workdays_ytd) as YTD_VAR_PRI_YTD
, (sum(cy_ytd_actual_revenue)-sum(py_ytd_actual_revenue))/sum(py_ytd_actual_revenue) as YTD_VAR_PRI_YTD_PCT
from BFA_setup
where product_category_description not in ("Biomed","Stryker")
;quit;




*****************************************************************************************************************************
											Product Category Metrics MTD Section
*****************************************************************************************************************************;

data _null_; 
    call symput('MTD_BEG',trim(left(put(intnx('month',"&date"d,0,'b'),date9.)))); 
    call symput('MTD_END',trim(left(put(intnx('month',"&date"d,0,'e'),date9.)))); 
run; 
 
/* Create formats for negative values */ 
proc format;                            
   picture mypct low-0='0,009.0%)' (prefix='(')   
                 other='0,009.0%'; 
   picture mydlr  
   /* without negatives */ 
   other='000,000,000' (prefix='$') 
   /* with negatives */ 
   low-0='000,000,000)' (prefix='($'); 
 
   value negfmt 
   low-0='red'; 
run; 
proc sql; 
create table WORK.BUDGET_FACTORS 
as 
SELECT  
input(PUT(YEAR ,4.),best4.) AS YEAR 
, MONTH  
, SUM(1)       AS DAYS_IN_MONTH  
, SUM(CASE WHEN DOW IN ( 2, 3, 4, 5, 6 ) AND PS_HOL_IND = 0 THEN 1 ELSE 0 END)     AS WORKDAYS  
, 1 / SUM(CASE WHEN DOW IN ( 2, 3, 4, 5, 6 ) AND PS_HOL_IND = 0 THEN 1 ELSE 0 END) AS WORKDAY_FACTOR  
FROM   D_DW.CALENDAR c 
WHERE  c.YEAR = YEAR("&date"d)  
GROUP  BY YEAR,  
MONTH 
;quit; 
 
 
proc sql; 
create table WORK.DAILY_BUDGET_FACTORS 
as 
SELECT  
CA.DATE_KEY 
, CA.YEAR 
, CA.MONTH 
, CASE WHEN DOW IN ( 2, 3, 4, 5, 6 ) AND PS_HOL_IND = 0 THEN 1 ELSE 0 END * BF.WORKDAY_FACTOR AS DAILY_BUDGET_FACTOR  
FROM   D_DW.CALENDAR CA  
LEFT JOIN WORK.BUDGET_FACTORS BF  
	ON CA.YEAR = BF.YEAR AND CA.MONTH = BF.MONTH  
WHERE  CA.YEAR = YEAR("&date"d)  
ORDER  BY DATE_KEY 
;quit; 
 
proc sql; 
create table Prior_year as 
SELECT  
CAL.YEAR 
, CAL.MONTH 
, PUT(case when Q.product_category_ID= 2 then 'Biomed' else 'Imaging' end,$50.) AS Product_type 
, SUM(REQUESTS) AS ACTUAL_REQUESTS 
, SUM(ORDERS)   AS ACTUAL_ORDERS 
, SUM(REVENUE)  AS ACTUAL_REVENUE 
, SUM(MARGIN)   AS ACTUAL_MARGIN 
FROM   d_DW.RORM_ALL Q 
INNER JOIN d_DW.CALENDAR CAL ON CAL.DATE_KEY = Q.TRANSACTION_DATE 
INNER JOIN d_DW.CUSTOMERS C ON C.COMPANY_ID = Q.CUSTOMER_ID 
WHERE  YEAR(Q.TRANSACTION_DATE) = YEAR("&date"d)-1 and c.lvl1_company_ID NOT IN (39438)
GROUP  BY 
CAL.YEAR 
,CAL.MONTH 
,Product_type 
;quit; 
 
proc sql; 
create table PY_SALES as 
SELECT  
DATE_KEY 
,MB.Product_type  AS Product_type  
,(DB.DAILY_BUDGET_FACTOR * MB.ACTUAL_REQUESTS) AS DAILY_PY_REQUESTS 
,(DB.DAILY_BUDGET_FACTOR * MB.ACTUAL_ORDERS)   AS DAILY_PY_ORDERS 
,(DB.DAILY_BUDGET_FACTOR * MB.ACTUAL_REVENUE)  AS DAILY_PY_REVENUE 
,(DB.DAILY_BUDGET_FACTOR * MB.ACTUAL_MARGIN)   AS DAILY_PY_MARGIN 
FROM   DAILY_BUDGET_FACTORS DB 
inner join Prior_year MB  ON DB.YEAR = MB.YEAR +1 AND DB.MONTH = MB.MONTH 
WHERE   
DB.DATE_KEY IS NOT NULL 
AND datepart(DATE_KEY) <= "&date"d 
;quit; 
 
 
proc sql; 
create table PY_SALES_calc as 
SELECT  
DATE_KEY 
, Product_type  
, sum(DAILY_PY_REQUESTS) AS DAILY_PY_REQUESTS 
, sum(DAILY_PY_ORDERS) AS DAILY_PY_ORDERS 
, sum(DAILY_PY_REVENUE) AS DAILY_PY_REVENUE 
, sum(DAILY_PY_MARGIN) AS DAILY_PY_MARGIN 
FROM   PY_SALES 
group by  
DATE_KEY 
, Product_type  
;quit; 
 
 
 
data BFA; 
set d_DW.DAILY_BUDGET_FORECAST_AND_ACTUAL; 
where ACCOUNTING_DATE BETWEEN "&mtd_beg"D AND "&date"D and sub_segment ne "ARAMARK" ; 
run; 
 
 
proc sql; 
create table DB_UNIONS as 
SELECT  
BFA.ACCOUNTING_DATE as DATE_KEY 
, PUT(case when product_category_Description IN ("Biomed","Stryker") then 'Biomed' else 'Imaging' end,$50.) AS Product_type 
,sum(ACTUAL_REQUESTS)              AS ACTUAL_REQUESTS 
,sum(ACTUAL_ORDERS)                AS ACTUAL_ORDERS 
,sum(ACTUAL_REVENUE)               AS ACTUAL_REVENUE 
,sum(ACTUAL_MARGIN)                AS ACTUAL_MARGIN 
,sum(BUDGET_REQUESTS)              AS BUDGET_REQUESTS 
,sum(BUDGET_ORDERS)                AS BUDGET_ORDERS 
,sum(BUDGET_REVENUE)               AS BUDGET_REVENUE 
,sum(BUDGET_MARGIN)                AS BUDGET_MARGIN 
,sum(FORECAST_REQUESTS)            AS FORECAST_REQUESTS 
,sum(FORECAST_ORDERS)              AS FORECAST_ORDERS 
,sum(FORECAST_REVENUE)             AS FORECAST_REVENUE 
,sum(FORECAST_MARGIN)              AS FORECAST_MARGIN 
FROM  BFA  
group by ACCOUNTING_DATE, Product_type 
order by accounting_date 
;quit; 
 
proc sql; 
create table DB_Group as 
SELECT  
datepart(d.DATE_KEY) as Date_KEY format=date9. 
, d.Product_type as Product_type 
, ACTUAL_REQUESTS 
, ACTUAL_ORDERS 
, ACTUAL_REVENUE 
, ACTUAL_MARGIN 
, BUDGET_REQUESTS 
, BUDGET_ORDERS 
, BUDGET_REVENUE 
, BUDGET_MARGIN 
, FORECAST_REQUESTS 
, FORECAST_ORDERS 
, FORECAST_REVENUE 
, FORECAST_MARGIN 
, DAILY_PY_REQUESTS 
, DAILY_PY_ORDERS 
, DAILY_PY_REVENUE 
, DAILY_PY_MARGIN 
, ACTUAL_REQUESTS-BUDGET_REQUESTS as Requests_Variance  
, ACTUAL_ORDERS-BUDGET_ORDERS as Orders_Variance  
, ACTUAL_REVENUE-BUDGET_REVENUE as Rev_Variance  
, ACTUAL_MARGIN-BUDGET_MARGIN as Margin_Variance  
FROM  DB_UNIONS d 
left join PY_SALES_calc PY on d.DATE_KEY=py.DATE_KEY and d.Product_type = py.Product_type  
;quit; 
 
proc sql; 
create table DB_Group_Totals as 
SELECT  
datepart(d.DATE_KEY) as Date_KEY format=date9. 
, sum(ACTUAL_REQUESTS) as ACTUAL_REQUESTS 
, sum(ACTUAL_ORDERS) as ACTUAL_ORDERS 
, sum(ACTUAL_REVENUE) as ACTUAL_REVENUE 
, sum(ACTUAL_MARGIN) as ACTUAL_MARGIN 
 
, sum(BUDGET_REQUESTS) as BUDGET_REQUESTS 
, sum(BUDGET_ORDERS) as BUDGET_ORDERS 
, sum(BUDGET_REVENUE) as BUDGET_REVENUE 
, sum(BUDGET_MARGIN) as BUDGET_MARGIN 
 
, sum(FORECAST_REQUESTS) as FORECAST_REQUESTS 
, sum(FORECAST_ORDERS) as FORECAST_ORDERS 
, sum(FORECAST_REVENUE) as FORECAST_REVENUE 
, sum(FORECAST_MARGIN) as FORECAST_MARGIN 
 
, sum(DAILY_PY_REQUESTS) as DAILY_PY_REQUESTS 
, sum(DAILY_PY_ORDERS) as DAILY_PY_ORDERS 
, sum(DAILY_PY_REVENUE) as DAILY_PY_REVENUE 
, sum(DAILY_PY_MARGIN) as DAILY_PY_MARGIN 
 
, sum(ACTUAL_REQUESTS)-sum(BUDGET_REQUESTS) as Requests_Variance  
, sum(ACTUAL_ORDERS)-sum(BUDGET_ORDERS) as Orders_Variance  
, sum(ACTUAL_REVENUE)-sum(BUDGET_REVENUE) as Rev_Variance  
, sum(ACTUAL_MARGIN)-sum(BUDGET_MARGIN) as Margin_Variance  
 
 
FROM  DB_UNIONS d 
left join PY_SALES_calc PY on d.DATE_KEY=py.DATE_KEY and d.Product_type = py.Product_type  
group by d.DATE_KEY  
;quit; 
 
 
 
 
proc sql; 
create table DB_Group_Totals as 
SELECT  
datepart(d.DATE_KEY) as Date_KEY format=date9. 
, sum(ACTUAL_REQUESTS) as ACTUAL_REQUESTS 
, sum(ACTUAL_ORDERS) as ACTUAL_ORDERS 
, sum(ACTUAL_REVENUE) as ACTUAL_REVENUE 
, sum(ACTUAL_MARGIN) as ACTUAL_MARGIN 
 
, sum(BUDGET_REQUESTS) as BUDGET_REQUESTS 
, sum(BUDGET_ORDERS) as BUDGET_ORDERS 
, sum(BUDGET_REVENUE) as BUDGET_REVENUE 
, sum(BUDGET_MARGIN) as BUDGET_MARGIN 
 
, sum(FORECAST_REQUESTS) as FORECAST_REQUESTS 
, sum(FORECAST_ORDERS) as FORECAST_ORDERS 
, sum(FORECAST_REVENUE) as FORECAST_REVENUE 
, sum(FORECAST_MARGIN) as FORECAST_MARGIN 
 
, sum(DAILY_PY_REQUESTS) as DAILY_PY_REQUESTS 
, sum(DAILY_PY_ORDERS) as DAILY_PY_ORDERS 
, sum(DAILY_PY_REVENUE) as DAILY_PY_REVENUE 
, sum(DAILY_PY_MARGIN) as DAILY_PY_MARGIN 
 
, sum(ACTUAL_REQUESTS)-sum(BUDGET_REQUESTS) as Requests_Variance  
, sum(ACTUAL_ORDERS)-sum(BUDGET_ORDERS) as Orders_Variance  
, sum(ACTUAL_REVENUE)-sum(BUDGET_REVENUE) as Rev_Variance  
, sum(ACTUAL_MARGIN)-sum(BUDGET_MARGIN) as Margin_Variance  
 
 
FROM  DB_UNIONS d 
left join PY_SALES_calc PY on d.DATE_KEY=py.DATE_KEY and d.Product_type = py.Product_type  
group by d.DATE_KEY  
;quit; 
 
data Biomed; 
set DB_Group; 
where Product_type = 'Biomed'; 
run; 
  
 
data DI; 
set DB_Group; 
where Product_type = 'Imaging'; 
run; 

*****************************************************************************************************************************
										Monthly Trend Report
*****************************************************************************************************************************
 
 
options validvarname=any;

data _NULL_ ; 
CALL SYMPUT('start_date', "'"|| TRIM(LEFT(PUT(INTNX('MONTH',DATE()-1,-12, 'b'),DATE9.))) ||"'d") ; 
CALL SYMPUT('End_Date', "'"|| TRIM(LEFT(PUT(DATE()-1,DATE9.))) ||"'d") ; 
run; 

proc sql; 
create table work.trend as  
select  
  SUM(q.REQUESTS) AS REQUESTS 
, SUM(q.ORDERS) AS ORDERS 
, SUM(q.REVENUE) AS REVENUE 
, SUM(q.MARGIN) AS MARGIN 
, MAX(cdr.WORKDAY_NBR_MTD) AS WORKDAYS 
, cdr.YEAR 
, cdr.MONTH 
, DATEPART(cdr.MONTH_END) format=mmddyyd10. as MONTH_END 
, PUT(cdr.MONTH_LONG, $15.) AS MONTH_LONG 
, q.TRANSACTION_DATE 
from D_DW.REQUESTS_ORDERS_REVENUE_MARGIN q 
inner join D_DW.CALENDAR cdr on q.TRANSACTION_DATE = cdr.DATE_KEY 
left JOIN D_DW.CUSTOMERS cust ON q.CUSTOMER_ID = cust.COMPANY_ID 
WHERE q.transaction_date between &start_date and &End_Date 
AND cust.lvl1_company_ID NOT IN (39438)
GROUP BY cdr.YEAR 
, cdr.MONTH 
, cdr.MONTH_END 
, cdr.MONTH_LONG 
, q.TRANSACTION_DATE 
; 
quit; 
proc sql; 
create table work.trend2 as  
select  
  SUM(REQUESTS) AS REQUESTS 
, SUM(ORDERS) AS ORDERS 
, SUM(REVENUE) AS REVENUE 
, SUM(MARGIN) AS MARGIN 
, MAX(WORKDAYS) AS WORKDAYS 
, YEAR 
, MONTH 
, MONTH_END 
, PUT(t.MONTH_LONG, $15.) AS MONTH_LONG 
, MAX(REQUESTS) AS MAX_REQUESTS 
, MAX(ORDERS) AS MAX_ORDERS 
, MAX(MARGIN) AS MAX_MARGIN 
from work.trend t 
GROUP BY YEAR 
, MONTH 
, MONTH_END 
, MONTH_LONG 
 
; 
Quit; 
 
 
 
 
proc sql; 
create table work.trend3 
as select  
   MONTH_LONG AS Month 
 , REQUESTS format = comma8. AS 'Monthly Requests'n 
 , ORDERS format = comma8.  AS 'Monthly Orders'n 
 , revenue format = dollar15.  as 'Net Revenue'n 
 , Margin format = dollar15. as 'Net Margin'n 
 , Margin/Revenue format = percent7.1  as 'GM %'n 
 , WORKDAYS as 'Selling Days'n 
 , Requests/WORKDAYS format = comma10. AS 'Requests per Day'n 
 , ORDERS/WORKDAYS format = comma10. AS  'Orders per Day'n 
 , revenue/WORKDAYS format = dollar15. AS 'Revenue per Day'n 
 , Margin/WORKDAYS format = dollar15. AS  'GM per Day'n 

 , MAX_REQUESTS format = comma8.  AS 'Max Request Day'n 
 , MAX_ORDERS format = comma8.  AS 'Max Order Day'n 
 , MAX_MARGIN format = dollar15. AS 'Max GM Day'n 
 , REVENUE/ORDERS format = dollar15. AS 'Revenue per Order'n 
 , MARGIN/ORDERS format = dollar15. AS 'GM per Order'n 
from work.trend2; 
 
quit; 
 
PROC SQL; 
	CREATE table WORK.sorted_trend AS 
		SELECT T.Month, T."Monthly Requests"n, T."Monthly Orders"n, T."Net Revenue"n, T."Net Margin"n, T."GM %"n, T."Requests per Day"n, T."Orders per Day"n, T."Revenue per Day"n, T."GM per Day"n,  T."Max Request Day"n, T."Max Order Day"n, T."Max GM Day"n, T."Revenue per Order"n, T."GM per Order"n, T."Selling Days"n 
	FROM WORK.TREND3 as T 
; 
QUIT; 
PROC TRANSPOSE DATA=WORK.sorted_trend 
	OUT=WORK.SortedTrend_out(LABEL="Transposed WORK.TREND3") 
	PREFIX=Column 
	NAME=Source 
	LABEL=Label 
; 
	VAR Month "Monthly Requests"n "Monthly Orders"n "Net Revenue"n "Net Margin"n "GM %"n "Requests per Day"n "Orders per Day"n 
"Revenue per Day"n "GM per Day"n  "Max Request Day"n "Max Order Day"n  
"Max GM Day"n "Revenue per Order"n "GM per Order"n "Selling Days"n; 
 
RUN; QUIT; 
 
 



*****************************************************************************************************************************
*****************************************************************************************************************************
*****************************************************************************************************************************
*****************************************************************************************************************************
													Compile Email Here
*****************************************************************************************************************************
*****************************************************************************************************************************
*****************************************************************************************************************************
*****************************************************************************************************************************;

*Start Email Setup;
filename sendmail email to=(&email_list)    from=("sas@partssource.com")  sender=("sas@partssource.com")
     type='text/html' subject="&subject";
      ods _all_ close; 
ods html file=sendmail; 

******************************Billing Transactions data output********************************;
title1 'Billing Summary Large Sales & Returns for ' "&date"; 
footnote1  "***CONFIDENTIAL: May not be reproduced, disseminated or distributed without prior written permission of PartsSource, Inc. executive management.  ";
 
proc print data=work.t1 noobs; 
run; 

title;

********************************Summary Statistics data output*****************************;
proc report data=work.BFA_output style(header)=[background=darkblue color=white] style(column)=[cellwidth=1in] style(column)=[background=white];
title 'Summary Statistics Report';
columns 
customer_segment 
metric 
MTD_ACTUAL 
('MTD Variance to Budget' MTD_VAR MTD_VAR_PCT) 
('MTD Variance to Prior Year' MTD_VAR_PRI_MTD MTD_VAR_PRI_MTD_PCT) 
YTD_ACTUAL 
('YTD Variance to Budget' YTD_VAR YTD_VAR_PCT) 
('YTD Variance to Prior Year' YTD_VAR_PRI_YTD YTD_VAR_PRI_YTD_PCT)
;

	define customer_segment / order format=$15. order=data 'Customer Segment' LEFT style(column)=[cellwidth=1.2in];
	define metric / order format=$15. order=data 'Metric' LEFT ;
	define MTD_ACTUAL / display 'MTD Actual' format=mydlr. style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];
	define MTD_VAR / display '($)' format=mydlr. style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];
	define MTD_VAR_PCT / display '(%)' format=percent8.1 style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];
	define MTD_VAR_PRI_MTD / display '($)' format=mydlr. style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];;
	define MTD_VAR_PRI_MTD_PCT / display '(%)' format=percent8.1 style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];
	define YTD_ACTUAL / display 'YTD Actual' format=mydlr. style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];;
	define YTD_VAR / display '($)' format=mydlr. style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];;
	define YTD_VAR_PCT / display '(%)' format=percent8.1 style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];
	define YTD_VAR_PRI_YTD / display '($)' format=mydlr. style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];;
	define YTD_VAR_PRI_YTD_PCT / display '(%)' format=percent8.1 style=[foreground=negfmt.] ;*style(header)=[background=#003F87 color=white];
*break after customer_segment / ol;

compute customer_segment;
   count+1; /*Provide a row count*/
   if count in (5,6,7,8) then /*Highlight Rows 5-8, the Biomed section of the output*/
	call define(_row_,"style","style=[background=lightgray]"); 
endcomp;


compute MTD_ACTUAL;
   if index(metric,'GM %') then call define(_col_,'format','percent8.1');
endcomp;
compute MTD_VAR;
   if index(metric,'GM %') then call define(_col_,'format','percent8.1');
endcomp;
compute MTD_VAR_PCT;
   if index(metric,'GM %') then call define(_col_,'style','style=[foreground=white]');
endcomp;
compute MTD_VAR_PRI_MTD;
   if index(metric,'GM %') then call define(_col_,'format','percent8.1');
endcomp;
compute MTD_VAR_PRI_MTD_PCT;
   if index(metric,'GM %') then call define(_col_,'style','style=[foreground=white]');
endcomp;
compute YTD_ACTUAL;
   if index(metric,'GM %') then call define(_col_,'format','percent8.1');
endcomp;
compute YTD_VAR; 
   if index(metric,'GM %') then call define(_col_,'format','percent8.1');
endcomp;
compute YTD_VAR_PCT;
   if index(metric,'GM %') then call define(_col_,'style','style=[foreground=white]');
endcomp;
compute YTD_VAR_PRI_YTD;
   if index(metric,'GM %') then call define(_col_,'format','percent8.1');
endcomp;
compute YTD_VAR_PRI_YTD_PCT;
   if index(metric,'GM %') then call define(_col_,'style','style=[foreground=white]');
endcomp;
run;
title;



********************************Daily Budget Values data output*****************************;

*
Format Rules:
>=98% to budget: Green
>92% to budget: Yellow
<=92% to budget: Red
;

options missing='';
*Build Report - Revenue;
proc report data=work.Combined_Data nowd center style(header)=[background=darkblue color=white] style(column)=[background=white]; 
title 'Daily Revenue Report';
column
Segment 
Actual_Revenue_Day  
Actual_Revenue_Week_Avg 
Actual_Revenue_Month_Avg 
Budget_Revenue_Day
gap
Actual_Revenue_Year
Budget_Revenue_Year
;
define Segment / display "Segment" style(column)=[cellwidth=2.5in];

define Actual_Revenue_Day / display "Daily Per Day Revenue" style(column)=[cellwidth=1.7in];
define Actual_Revenue_Week_Avg / display "Weekly Per Day Revenue" style(column)=[cellwidth=1.7in]; 
define Actual_Revenue_Month_Avg / display "Monthly Per Day Revenue" style(column)=[cellwidth=1.7in]; 
define Budget_Revenue_Day / display "Budget Per Day Revenue" style(column)=[cellwidth=1.7in background=lightgrey];

define gap / ' ' style(column)=[cellwidth=1] style(header)=[background=white];
define Actual_Revenue_Year / display "YtD Revenue" style(column)=[cellwidth=1.7in];
define Budget_Revenue_Year / display "YtD Budget Revenue" style(column)=[cellwidth=1.7in background=lightgrey];


COMPUTE Budget_Revenue_Day;  
if Actual_Revenue_Day/Budget_Revenue_Day >= .98 or segment='Contingency'  then do;
  call define('Actual_Revenue_Day',"style","style=[foreground=green]");  
end;  
else if Actual_Revenue_Day/Budget_Revenue_Day > .92 then do;
  call define('Actual_Revenue_Day',"style","style=[foreground=cxffc000]");  
end;  
else if Actual_Revenue_Day/Budget_Revenue_Day <= .92 then do;
  call define('Actual_Revenue_Day',"style","style=[foreground=red]");  
end;  

if Actual_Revenue_Week_Avg/Budget_Revenue_Day >= .98 or segment='Contingency'  then do;
  call define('Actual_Revenue_Week_Avg',"style","style=[foreground=green]");  
end;  
else if Actual_Revenue_Week_Avg/Budget_Revenue_Day > .92 then do;
  call define('Actual_Revenue_Week_Avg',"style","style=[foreground=cxffc000]");  
end;  
else if Actual_Revenue_Week_Avg/Budget_Revenue_Day <= .92 then do;
  call define('Actual_Revenue_Week_Avg',"style","style=[foreground=red]");  
end;  

if Actual_Revenue_Month_Avg/Budget_Revenue_Day >= .98 or segment='Contingency'  then do;
  call define('Actual_Revenue_Month_Avg',"style","style=[foreground=green]");  
end;  
else if Actual_Revenue_Month_Avg/Budget_Revenue_Day > .92 then do;
  call define('Actual_Revenue_Month_Avg',"style","style=[foreground=cxffc000]");  
end;  
else if Actual_Revenue_Month_Avg/Budget_Revenue_Day <= .92 then do;
  call define('Actual_Revenue_Month_Avg',"style","style=[foreground=red]");  
end;
endcomp;

compute Budget_Revenue_Year;
if Actual_Revenue_Year/Budget_Revenue_Year >= .98 or segment='Contingency'  then do;
  call define('Actual_Revenue_Year',"style","style=[foreground=green]");  
end;  
else if Actual_Revenue_Year/Budget_Revenue_Year > .92 then do;
  call define('Actual_Revenue_Year',"style","style=[foreground=cxffc000]");  
end;  
else if Actual_Revenue_Year/Budget_Revenue_Year <= .92 then do;
  call define('Actual_Revenue_Year',"style","style=[foreground=red]");  
end;
endcomp;
run;


*Build Report - Margin;
proc report data=work.Combined_Data nowd center style(header)=[background=darkblue color=white] style(column)=[background=white]; 
title 'Daily Margin Report';
column
Segment 
Actual_Margin_Day
Actual_Margin_Week_Avg
Actual_Margin_Month_Avg
Budget_Margin_Day

gap 
Actual_Margin_Year
Budget_Margin_Year
;
define Segment / display "Segment" style(column)=[cellwidth=2.5in];

define Actual_Margin_Day / display "Daily Per Day Margin" style(column)=[cellwidth=1.7in];
define Actual_Margin_Week_Avg / display "Weekly Per Day Margin" style(column)=[cellwidth=1.7in]; 
define Actual_Margin_Month_Avg / display "Monthly Per Day Margin" style(column)=[cellwidth=1.7in]; 
define Budget_Margin_Day / display "Budget Per Day Margin" style(column)=[cellwidth=1.7in background=lightgrey];

define gap / ' ' style(column)=[cellwidth=1] style(header)=[background=white];
define Actual_Margin_Year / display "YtD Margin" style(column)=[cellwidth=1.7in];
define Budget_Margin_Year / display "YtD Budget Margin" style(column)=[cellwidth=1.7in background=lightgrey];

COMPUTE Budget_Margin_Day;  
if Actual_Margin_Day/Budget_Margin_Day >= .98 or segment='Contingency' then do;
  call define('Actual_Margin_Day',"style","style=[foreground=green]");  
end;  
else if Actual_Margin_Day/Budget_Margin_Day > .92 then do;
  call define('Actual_Margin_Day',"style","style=[foreground=cxffc000]");  
end;  
else if Actual_Margin_Day/Budget_Margin_Day <= .92 then do;
  call define('Actual_Margin_Day',"style","style=[foreground=red]");  
end;  

if Actual_Margin_Week_Avg/Budget_Margin_Day >= .98 or segment='Contingency'  then do;
  call define('Actual_Margin_Week_Avg',"style","style=[foreground=green]");  
end;  
else if Actual_Margin_Week_Avg/Budget_Margin_Day > .92 then do;
  call define('Actual_Margin_Week_Avg',"style","style=[foreground=cxffc000]");  
end;  
else if Actual_Margin_Week_Avg/Budget_Margin_Day <= .92 then do;
  call define('Actual_Margin_Week_Avg',"style","style=[foreground=red]");  
end;  

if Actual_Margin_Month_Avg/Budget_Margin_Day >= .98 or segment='Contingency'  then do;
  call define('Actual_Margin_Month_Avg',"style","style=[foreground=green]");  
end;  
else if Actual_Margin_Month_Avg/Budget_Margin_Day > .92 then do;
  call define('Actual_Margin_Month_Avg',"style","style=[foreground=cxffc000]");  
end;  
else if Actual_Margin_Month_Avg/Budget_Margin_Day <= .92 then do;
  call define('Actual_Margin_Month_Avg',"style","style=[foreground=red]");  
end;  
endcomp;

compute Budget_Margin_Year;
if Actual_Margin_Year/Budget_Margin_Year >= .98 or segment='Contingency'  then do;
  call define('Actual_Margin_Year',"style","style=[foreground=green]");  
end;  
else if Actual_Margin_Year/Budget_Margin_Year > .92 then do;
  call define('Actual_Margin_Year',"style","style=[foreground=cxffc000]");  
end;  
else if Actual_Margin_Year/Budget_Margin_Year <= .92 then do;
  call define('Actual_Margin_Year',"style","style=[foreground=red]");  
end;
endcomp;
run;

***************************Monthly Trend Report data output***********************************;
TITLE; 
TITLE1 "Monthly Trend Report"; 
 
 
proc report data=work.SortedTrend_out style(column)=[background=white]; 
 
columns  Source column1 column2 column3 column4 column5 column6 column7 column8 column9 column10 column11 column12 column13; 
 
	define Source/display ''; 
	define column1/display  '' right ; 
	define column2/display  '' right; 
	define column3/display  '' right; 
	define column4/display  '' right; 
	define column5/display  '' right; 
	define column6/display  '' right; 
	define column7/display  '' right; 
	define column8/display  '' right; 
	define column9/display  '' right; 
	define column10/display '' right ; 
	define column11/display '' right ; 
	define column12/display '' right ; 
	define column13/display '' right ; 
 
 
COMPUTE Source;  
 IF Source = 'Month' then do; 
	call define(_row_,"style","style=[background=darkblue foreground=white font_weight=bold just=left]"); 
	end; 
 IF Source = 'Requests per Day' then do; 
	call define(_row_,"style","style=[background=lightgray]"); 
	end; 
 IF Source = 'Orders per Day' then do; 
	call define(_row_,"style","style=[background=lightgray]"); 
	end; 
 IF Source = 'Revenue per Day' then do; 
	call define(_row_,"style","style=[background=lightgray]"); 
	end; 
 IF Source = 'Margin per Day' then do; 
	call define(_row_,"style","style=[background=lightgray]"); 
	end; 
IF Source = 'GM per Day' then do; 
	call define(_row_,"style","style=[background=lightgray]"); 
	end; 
 IF Source = 'Revenue per Order' then do; 
	call define(_row_,"style","style=[background=lightgray]"); 
	end; 
 IF Source = 'GM per Order' then do; 
	call define(_row_,"style","style=[background=lightgray]"); 
	end; 
ENDCOMP; 
	run; 
	title; 


******************Daily Statistics by Category Section*********************************;
/* Create Report Total */ 
proc report data=DB_Group_Totals nowd center style(column)=[cellwidth=.9in] style(header)=[background=darkblue color=white] style(column)=[background=white]; 
options missing=' '; 
Title "Daily Statistic By Category"; 
Title2 "Through &date."; 
Title3 " "; 
Title4 "Total"; 
 
column DATE_KEY 
 
	    
	   ('Actual' Actual_Requests Actual_Orders Actual_Close_Rate Actual_Revenue Actual_Sales_PO Actual_Margin Actual_GM_Percent Actual_GM_PO) 
         ('Budget' Budget_Revenue Budget_Margin Budget_GM_Percent ) 
	   ('Variance' Rev_Variance  Margin_Variance GM_Percent_Variance  ) 
	 
	 
       ; 
      ; 
Define DATE_KEY / group 'Date' /*style(header)=[background=grey color=white]*/ style(column)=[cellwidth=1in]; 
Define Actual_Requests / group 'PRs' format=comma15. ; 
Define Actual_Orders / group 'POs' format=comma15.; 
Define Actual_Close_Rate / computed 'Close Rate' format=percent8.1; 
Define Actual_Revenue/ group 'Revenue' format=dollar15.; 
Define Budget_Revenue / group 'Revenue' format=dollar15.  style (column)=[background=lightgrey color=Black];; 
Define Rev_Variance / group 'Revenue' format=mydlr. style(column)=[foreground=negfmt.]; 
Define Actual_Margin / group 'Margin' format=dollar15.; 
Define Budget_Margin / group 'Margin' format=dollar15.  style (column)=[background=lightgrey color=Black];; 
Define Margin_Variance / group 'Margin' format=mydlr. style (column)=[foreground=negfmt.]; 
Define Actual_GM_Percent / computed 'GM%' format=percent8.1; 
Define Budget_GM_Percent / computed 'GM%' format=percent8.1  style (column)=[background=lightgrey color=Black];; 
Define GM_Percent_Variance/ computed 'GM%' format=percent8.1 style(column)=[foreground=negfmt.]; 
Define Actual_Sales_PO / computed 'Avg. Rev/ PO' format=dollar15.; 
Define Actual_GM_PO / computed 'Avg. GM / PO' format=dollar15.; 
 
 
/***** REVENUE *****/ 
compute Actual_Revenue; 
       if Actual_Revenue=0 then do; 
	      Actual_Revenue=' '; 
	   end; 
endcomp; 
 
compute Budget_Revenue; 
       if Budget_Revenue=0 then do; 
	      Budget_Revenue=' '; 
	   end; 
endcomp; 
 
/***** MARGIN *****/ 
compute Actual_Margin; 
       if Actual_Margin=0 then do; 
	      Actual_Margin=' '; 
	   end; 
endcomp; 
compute Budget_Margin; 
       if Budget_Margin=0 then do; 
	      Budget_Margin=' '; 
	   end; 
endcomp; 
 
/***** REQUESTS *****/ 
compute Actual_Requests; 
       if Actual_Requests=0 then do; 
	      Actual_Requests=' '; 
	   end; 
endcomp; 
/***** ORDERS *****/ 
compute Actual_Orders; 
       if Actual_Orders=0 then do; 
	      Actual_Orders=' '; 
	   end; 
endcomp; 

 
/***** CLOSE RATE *****/ 
compute Actual_Close_Rate; 
	Actual_Close_Rate = Actual_Orders / Actual_Requests; 
	if Actual_Close_Rate=0 then do; 
	   Actual_Close_Rate=' '; 
	end; 
endcomp; 
 

 
/***** SALES PO *****/ 
compute Actual_Sales_PO; 
	Actual_Sales_PO = Actual_Revenue / Actual_Orders; 
	if Actual_Sales_PO=0 then do; 
	   Actual_Sales_PO=' '; 
	end; 
endcomp; 

 
/*****GM PO *****/ 
compute Actual_GM_PO; 
	Actual_GM_PO = Actual_Margin / Actual_Orders; 
	if Actual_GM_PO=0 then do; 
	   Actual_GM_PO=' '; 
	end; 
endcomp; 

 
/*****GM Percent *****/ 
compute Actual_GM_Percent; 
	Actual_GM_Percent = Actual_Margin / Actual_Revenue; 
	if Actual_GM_Percent=0 then do; 
	   Actual_GM_PO=' '; 
	end; 
endcomp; 
compute Budget_GM_Percent; 
	Budget_GM_Percent = Budget_Margin / Budget_Revenue; 
	if Budget_GM_Percent=0 then do; 
	   Budget_GM_Percent=' '; 
	end; 
endcomp; 
 
/***** Variance OF SALES *****/ 
compute Rev_Variance;  
	if Rev_Variance=0 then do; 
	   Rev_Variance=' '; 
	end; 
endcomp; 
compute Margin_Variance; 
	if Margin_Variance=0 then do; 
	   Margin_Variance=' '; 
	end; 
endcomp; 

compute GM_Percent_Variance; 
	GM_Percent_Variance= Actual_GM_Percent-Budget_GM_Percent; 
	if GM_Percent_Variance=0 then do; 
	   GM_Percent_Variance=' '; 
	end; 
endcomp; 

run; 


/* Create Report Total */ 
proc report data=Biomed nowd center style(column)=[cellwidth=.9in] style(header)=[background=darkblue color=white] style(column)=[background=white]; 
options missing=' '; 
Title "Biomed"; 
 
column DATE_KEY 
 
	   	   ('Actual' Actual_Requests Actual_Orders Actual_Close_Rate Actual_Revenue Actual_Sales_PO Actual_Margin Actual_GM_Percent Actual_GM_PO) 
       ('Budget' Budget_Revenue Budget_Margin Budget_GM_Percent) 
	   ('Variance'  Rev_Variance Margin_Variance GM_Percent_Variance   ) 
	 
       ; 
Define DATE_KEY / group 'Date' /*style(header)=[background=grey color=white]*/ style(column)=[cellwidth=1in]; 
Define Actual_Requests / group 'PRs' format=comma15. ; 
Define Actual_Orders / group 'POs' format=comma15.; 
Define Actual_Close_Rate / computed 'Close Rate' format=percent8.1; 
Define Actual_Revenue/ group 'Revenue' format=dollar15.; 
Define Budget_Revenue / group 'Revenue' format=dollar15.  style (column)=[background=lightgrey color=Black];; 
Define Rev_Variance / group 'Revenue' format=mydlr. style(column)=[foreground=negfmt.]; 
Define Actual_Margin / group 'Margin' format=dollar15.; 
Define Budget_Margin / group 'Margin' format=dollar15.  style (column)=[background=lightgrey color=Black];; 
Define Margin_Variance / group 'Margin' format=mydlr. style (column)=[foreground=negfmt.]; 
Define Actual_GM_Percent / computed 'GM%' format=percent8.1; 
Define Budget_GM_Percent / computed 'GM%' format=percent8.1  style (column)=[background=lightgrey color=Black];; 
Define GM_Percent_Variance/ computed 'GM%' format=percent8.1 style(column)=[foreground=negfmt.]; 
Define Actual_Sales_PO / computed 'Avg. Rev/ PO' format=dollar15.; 
Define Actual_GM_PO / computed 'Avg. GM / PO' format=dollar15.; 
 
 
/***** REVENUE *****/ 
compute Actual_Revenue; 
       if Actual_Revenue=0 then do; 
	      Actual_Revenue=' '; 
	   end; 
endcomp; 
 
compute Budget_Revenue; 
       if Budget_Revenue=0 then do; 
	      Budget_Revenue=' '; 
	   end; 
endcomp; 
 
/***** MARGIN *****/ 
compute Actual_Margin; 
       if Actual_Margin=0 then do; 
	      Actual_Margin=' '; 
	   end; 
endcomp; 
compute Budget_Margin; 
       if Budget_Margin=0 then do; 
	      Budget_Margin=' '; 
	   end; 
endcomp; 
 
/***** REQUESTS *****/ 
compute Actual_Requests; 
       if Actual_Requests=0 then do; 
	      Actual_Requests=' '; 
	   end; 
endcomp; 
/***** ORDERS *****/ 
compute Actual_Orders; 
       if Actual_Orders=0 then do; 
	      Actual_Orders=' '; 
	   end; 
endcomp; 
 
/***** CLOSE RATE *****/ 
compute Actual_Close_Rate; 
	Actual_Close_Rate = Actual_Orders / Actual_Requests; 
	if Actual_Close_Rate=0 then do; 
	   Actual_Close_Rate=' '; 
	end; 
endcomp; 
 
/***** SALES PO *****/ 
compute Actual_Sales_PO; 
	Actual_Sales_PO = Actual_Revenue / Actual_Orders; 
	if Actual_Sales_PO=0 then do; 
	   Actual_Sales_PO=' '; 
	end; 
endcomp; 
 
/*****GM PO *****/ 
compute Actual_GM_PO; 
	Actual_GM_PO = Actual_Margin / Actual_Orders; 
	if Actual_GM_PO=0 then do; 
	   Actual_GM_PO=' '; 
	end; 
endcomp; 
 
/*****GM Percent *****/ 
compute Actual_GM_Percent; 
	Actual_GM_Percent = Actual_Margin / Actual_Revenue; 
	if Actual_GM_Percent=0 then do; 
	   Actual_GM_PO=' '; 
	end; 
endcomp; 
compute Budget_GM_Percent; 
	Budget_GM_Percent = Budget_Margin / Budget_Revenue; 
	if Budget_GM_Percent=0 then do; 
	   Budget_GM_Percent=' '; 
	end; 
endcomp; 
 
/***** Variance OF SALES *****/ 
compute Rev_Variance;  
	if Rev_Variance=0 then do; 
	   Rev_Variance=' '; 
	end; 
endcomp; 
compute Margin_Variance; 
	if Margin_Variance=0 then do; 
	   Margin_Variance=' '; 
	end; 
endcomp; 
compute GM_Percent_Variance; 
	GM_Percent_Variance= Actual_GM_Percent-Budget_GM_Percent; 
	if GM_Percent_Variance=0 then do; 
	   GM_Percent_Variance=' '; 
	end; 
endcomp; 
run;
 

 
/* Create Report Total */ 
proc report data=DI nowd center style(column)=[cellwidth=.9in] style(header)=[background=darkblue color=white] style(column)=[background=white]; 
options missing=' '; 
Title "Imaging"; 
 
column DATE_KEY 
 
	    
	   
	   	   ('Actual' Actual_Requests Actual_Orders Actual_Close_Rate Actual_Revenue Actual_Sales_PO Actual_Margin Actual_GM_Percent Actual_GM_PO) 
       ('Budget' Budget_Revenue  Budget_Margin Budget_GM_Percent ) 
	   ('Variance'  Rev_Variance  Margin_Variance GM_Percent_Variance  ) 
	 
       ; 
Define DATE_KEY / group 'Date' /*style(header)=[background=grey color=white]*/ style(column)=[cellwidth=1in]; 
Define Actual_Requests / group 'PRs' format=comma15. ; 
Define Actual_Orders / group 'POs' format=comma15.; 
Define Actual_Close_Rate / computed 'Close Rate' format=percent8.1; 
Define Actual_Revenue/ group 'Revenue' format=dollar15.; 
Define Budget_Revenue / group 'Revenue' format=dollar15.  style (column)=[background=lightgrey color=Black];; 
Define Rev_Variance / group 'Revenue' format=mydlr. style(column)=[foreground=negfmt.]; 
Define Actual_Margin / group 'Margin' format=dollar15.; 
Define Budget_Margin / group 'Margin' format=dollar15.  style (column)=[background=lightgrey color=Black];; 
Define Margin_Variance / group 'Margin' format=mydlr. style (column)=[foreground=negfmt.]; 
Define Actual_GM_Percent / computed 'GM%' format=percent8.1; 
Define Budget_GM_Percent / computed 'GM%' format=percent8.1  style (column)=[background=lightgrey color=Black];; 
Define GM_Percent_Variance/ computed 'GM%' format=percent8.1 style(column)=[foreground=negfmt.]; 
Define Actual_Sales_PO / computed 'Avg. Rev/ PO' format=dollar15.; 
Define Actual_GM_PO / computed 'Avg. GM / PO' format=dollar15.; 
 
 
/***** REVENUE *****/ 
compute Actual_Revenue; 
       if Actual_Revenue=0 then do; 
	      Actual_Revenue=' '; 
	   end; 
endcomp; 
 
compute Budget_Revenue; 
       if Budget_Revenue=0 then do; 
	      Budget_Revenue=' '; 
	   end; 
endcomp; 
 
/***** MARGIN *****/ 
compute Actual_Margin; 
       if Actual_Margin=0 then do; 
	      Actual_Margin=' '; 
	   end; 
endcomp; 
compute Budget_Margin; 
       if Budget_Margin=0 then do; 
	      Budget_Margin=' '; 
	   end; 
endcomp; 
 
/***** REQUESTS *****/ 
compute Actual_Requests; 
       if Actual_Requests=0 then do; 
	      Actual_Requests=' '; 
	   end; 
endcomp; 
/***** ORDERS *****/ 
compute Actual_Orders; 
       if Actual_Orders=0 then do; 
	      Actual_Orders=' '; 
	   end; 
endcomp; 
 
/***** CLOSE RATE *****/ 
compute Actual_Close_Rate; 
	Actual_Close_Rate = Actual_Orders / Actual_Requests; 
	if Actual_Close_Rate=0 then do; 
	   Actual_Close_Rate=' '; 
	end; 
endcomp; 
 
 
/***** SALES PO *****/ 
compute Actual_Sales_PO; 
	Actual_Sales_PO = Actual_Revenue / Actual_Orders; 
	if Actual_Sales_PO=0 then do; 
	   Actual_Sales_PO=' '; 
	end; 
endcomp; 

/*****GM PO *****/ 
compute Actual_GM_PO; 
	Actual_GM_PO = Actual_Margin / Actual_Orders; 
	if Actual_GM_PO=0 then do; 
	   Actual_GM_PO=' '; 
	end; 
endcomp; 

 
/*****GM Percent *****/ 
compute Actual_GM_Percent; 
	Actual_GM_Percent = Actual_Margin / Actual_Revenue; 
	if Actual_GM_Percent=0 then do; 
	   Actual_GM_PO=' '; 
	end; 
endcomp; 
compute Budget_GM_Percent; 
	Budget_GM_Percent = Budget_Margin / Budget_Revenue; 
	if Budget_GM_Percent=0 then do; 
	   Budget_GM_Percent=' '; 
	end; 
endcomp; 
 
/***** Variance OF SALES *****/ 
compute Rev_Variance;  
	if Rev_Variance=0 then do; 
	   Rev_Variance=' '; 
	end; 
endcomp; 
compute Margin_Variance; 
	if Margin_Variance=0 then do; 
	   Margin_Variance=' '; 
	end; 
endcomp; 

compute GM_Percent_Variance; 
	GM_Percent_Variance= Actual_GM_Percent-Budget_GM_Percent; 
	if GM_Percent_Variance=0 then do; 
	   GM_Percent_Variance=' '; 
	end; 
endcomp; 
run;

title;footnote;

*Close out and clear email setup;
ods html close; 
ods listing; 
filename sendmail clear;



*Clean up work tables;
proc sql;
drop table work.bfa;
drop table work.bfa_output;
drop table work.bfa_setup;
drop table work.bill_sum;
drop table work.bill_sum2;
drop table work.biomed;
drop table work.budget_factors;
drop table work.daily_budget_factors;
drop table work.db_group;
drop table work.db_group_totals;
drop table work.db_unions;
drop table work.di;
drop table work.prior_year;
drop table work.py_sales;
drop table work.py_sales_calc;
drop table work.t1;
drop table work.sorted_trend;
drop table work.sortedtrend_out;
drop table work.trend;
drop table work.trend2;
drop table work.trend3;
drop table work.salvages;
drop table work.calendar2020;
drop table work.combined_data;
drop table work.gather_data;
drop table work.temp_values;
quit;
