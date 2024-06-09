--1: inspecting data
********************
select * from [exp_sales].[dbo].[sales_data_sample]; 

-- Discover collumns names and data types
*****************************************
EXEC sp_help '[exp_sales].[dbo].[sales_data_sample]'; 



-- discover distinct values 
*****************************
select distinct STATUS from [exp_sales].[dbo].[sales_data_sample]; -- my status
select distinct year_id from [exp_sales].[dbo].[sales_data_sample]; -- years, for ploting
select distinct productline from [exp_sales].[dbo].[sales_data_sample]; -- my products lines, for ploting
select distinct country from [exp_sales].[dbo].[sales_data_sample]; -- my countries, for ploting 
select distinct DEALSIZE from [exp_sales].[dbo].[sales_data_sample]; -- my deal sizes, for ploting
select distinct TERRITORY from [exp_sales].[dbo].[sales_data_sample]; -- territories, for ploting


-- fixing data types
**************************
--ALTER TABLE [exp_sales].[dbo].[sales_data_sample]
--ALTER COLUMN sales FLOAT
--ALTER COLUMN priceeach FLOAT
--ALTER COLUMN ORDERLINENUMBER int
--ALTER COLUMN QTR_ID int
--ALTER COLUMN MONTH_ID int;


-- fixe date collumn type
**************************
--ALTER TABLE [exp_sales].[dbo].[sales_data_sample]
--ADD order_date date;

--UPDATE [exp_sales].[dbo].[sales_data_sample]
--SET order_date = CONVERT(date, orderdate, 101); -- 101 is the code for mm/dd/yyyy format

--ALTER TABLE [exp_sales].[dbo].[sales_data_sample]
--DROP COLUMN orderdate;
--EXEC sp_rename 'sales_data_sample.order_date', 'ORDERDATE', 'COLUMN'; --rename the new column to match the old one



-- insure that data types are fixed
*************************************
select * from [exp_sales].[dbo].[sales_data_sample];

EXEC sp_help '[exp_sales].[dbo].[sales_data_sample]'; 



--2: Analysis
****************
-- sales by productline
************************
select productline, sum(sales) as Revenue
from [exp_sales].[dbo].[sales_data_sample]
group by productline
order by SUM(sales) desc;

-- sales by Year
*****************
select Year_id, sum(sales) as Revenue
from [exp_sales].[dbo].[sales_data_sample]
group by Year_id -- 2005 has 5 months stats (select distinct month_id from [dbo].[sales_data_sample] where year_id = 2005)
order by SUM(sales) desc;

select Year_id, round(avg(sales),2) as avgRevenue
from [exp_sales].[dbo].[sales_data_sample]
group by Year_id 
order by avg(sales) desc;

-- Sales by dealsize
***********************
select dealsize, sum(sales) as Revenue
from [exp_sales].[dbo].[sales_data_sample]
group by dealsize 
order by sum(sales) desc;

-- what's the best mounth for sales for a specific year and how much was earned? 
*********************************************************************************
with revenue as
(
select year_id, month_id, sum(sales) as Revenue, count(ordernumber) as Frequency
from [exp_sales].[dbo].[sales_data_sample]
group by year_id, month_id
),
max_revenue as
(
select year_id, max(revenue) as max_revenue from revenue
group by YEAR_id
)

select r.year_id, r.month_id, r.revenue, r.Frequency
from revenue r 
join max_revenue m on r.year_id=m.year_id and r.revenue=m.max_revenue
order by r.year_id

-- November seems to be the best month, what product the sell in november?
******************************************************************************
select year_id,productline , sum(sales) as Revenue 
from [exp_sales].[dbo].[sales_data_sample]
where month_id = 11
group by year_id, productline
order by 3 desc



--RFM (Recency-Frenquency-Monetary) ANALYSIS 
***********************************************
--what's our best customer (this could be best answered using RFM)
drop table if exists #rfm;
with RFM as
(
select customername,
	sum(sales) as Monetary,
	round(avg(sales),2) as AvgMonetary,
	count(*) as Frequency,
	max(orderdate) as last_order_date,
	(select max(orderdate) from [exp_sales].[dbo].[sales_data_sample]) as max_order_date,
	datediff(dd,max(orderdate),(select max(orderdate) from [exp_sales].[dbo].[sales_data_sample])) as Recency

from [exp_sales].[dbo].[sales_data_sample]
group by customername
),

RFM_calc as
(
select r.*,
	ntile(4) over(order by recency desc) as rfm_recency,
	ntile(4) over(order by frequency ) as rfm_frequency,
	ntile(4) over(order by monetary ) as rfm_monetary
from rfm r
)
select c.*,
	rfm_recency+rfm_frequency+rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar)+cast(rfm_frequency as varchar)+cast(rfm_monetary as varchar) as rfm_cell_string

into #rfm
from rfm_calc c

select customername, rfm_recency, rfm_frequency, rfm_monetary,rfm_cell_string,
	case 
		when rfm_cell_string in (111,112,121,122,123,132,211,212,114,141) then 'lost customers'
		when rfm_cell_string in (133,134,143,244,343,344,144) then 'slliping awayn canot lose'
		when rfm_cell_string in (311,411,331) then 'new customers'
		when rfm_cell_string in (222,223,233,322) then 'potential charners'
		when rfm_cell_string in (323,333,321,422,332,432) then 'active'
		when rfm_cell_string in (433,434,443,444) then 'loyal'
	end rfm_segment
from #rfm



--what's products are most often sold together?
*************************************************
--step4: using stuff to remove the first coma',' and covert the path  to a string then extract the order number and products that have solded together
select distinct(ordernumber), stuff(
(
--step3: iextracting the product codes where we have two products that have solded together and add those product codes in one line using an xml path
select concat(',',productcode) from [exp_sales].[dbo].[sales_data_sample] p
where ordernumber in
(
--step2 : extract the number order where we have two products that have solded together that's mean rn=2
select ordernumber from
(
-- step1: indiquate the number of shiped products by cosutomer number
select ordernumber, count(*) as rn
from [exp_sales].[dbo].[sales_data_sample]
where status='shipped'
group by ordernumber
) as m
where rn=2 and p.ordernumber = s.ordernumber
) for xml path('')
),
1--starting position
,1--number of carachters to remove
,''--replace by 
) as products_code from [exp_sales].[dbo].[sales_data_sample] s
order by 2 desc
