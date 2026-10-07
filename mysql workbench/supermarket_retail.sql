/* supermarket retail performance
   public sample: 1000 invoices, 3 branches, jan-mar 2019
   not amazon company data
   do not use gross_margin_percentage as a kpi (constant 5/105)
*/

/* LIMITS
   1000 invoices, 3 branches, Jan-Mar 2019 only.
   Branches and Member/Normal are almost even.
   Small differences are not a national strategy.
*/

create database  supermarket_retail_sales;
use supermarket_retail_sales;

create table sales_transactions (
    invoice_id   varchar(30)  not null primary key,
    branch  varchar(5) not null,
    city varchar(30) not null,
    customer_type varchar(30) not null,
    gender  varchar(10) not null,
    product_line varchar(100) not null,
    unit_price decimal(10,2) not null,
    quantity  int not null,
    vat  decimal(10,4) not null,
    total decimal(10,4) not null,
    date date not null,
    time time not null,
    payment_method  varchar(30) not null,
    cogs  decimal(10,2)  not null,
    gross_margin_percentage  decimal(11,9)  not null,
    gross_income  decimal(10,4)  not null,
    rating  decimal(4,1)   not null
);

/* ---------------------------------------------------------------------------
   LOAD
--------------------------------------------------------------------------- */
load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/supermarket_sales_2019.csv'
into table sales_transactions
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(invoice_id, branch, city, customer_type, gender, product_line,
 unit_price, quantity, vat, total, @date, time, payment_method,
 cogs, gross_margin_percentage, gross_income, rating)
set date = str_to_date(@date, '%Y-%m-%d');

select count(*) as row_count from sales_transactions;          -- expect 1000
select * from sales_transactions limit 5;
show columns from sales_transactions;


/* =============================================================================
   1) DATA QUALITY
   Expected on this file: 0 nulls, 0 duplicate invoices, 0 rule breaks.
============================================================================= */

-- 1.1 Null audit  (expect 0 rows)
select *
from sales_transactions
where invoice_id is null or branch is null or city is null
   or customer_type is null or gender is null or product_line is null
   or unit_price is null or quantity is null or vat is null
   or total is null or date is null or time is null
   or payment_method is null or cogs is null
   or gross_margin_percentage is null or gross_income is null
   or rating is null;

-- 1.2 Duplicate invoice IDs  (expect 0 rows)
select invoice_id, count(*) as duplicate_count
from sales_transactions
group by invoice_id
having count(*) > 1;

-- 1.3 Allowed values
select distinct branch from sales_transactions;   -- A, B, C
select distinct city from sales_transactions;   -- Yangon, Mandalay, Naypyitaw
select distinct customer_type  from sales_transactions;   -- Member, Normal
select distinct gender from sales_transactions;   -- Female, Male
select distinct product_line from sales_transactions;   -- 6 categories
select distinct payment_method from sales_transactions;   -- Ewallet, Cash, Credit card

-- 1.4 Ranges
select
    min(date) as start_date,        -- 2019-01-01
    max(date)  as end_date,          -- 2019-03-30
    min(time)  as earliest_time,
    max(time)  as latest_time,
    min(unit_price) as min_price,
    max(unit_price) as max_price,
    min(quantity) as min_qty,
    max(quantity) as max_qty,
    min(rating) as min_rating,        -- should be >= 4 on this file
    max(rating) as max_rating,        -- 10
    min(total) as min_total,
    max(total)  as max_total
from sales_transactions;

-- 1.5 Business rules
-- vat ≈ 5% of cogs ; total ≈ cogs + vat ; gross_income ≈ vat
select
    count(*) as total_rows,
    sum(case when abs(vat - (cogs * 0.05)) > 0.01 then 1 else 0 end) as vat_mismatch,
    sum(case when abs(total - (cogs + vat)) > 0.01 then 1 else 0 end) as total_mismatch,
    sum(case when abs(gross_income - vat) > 0.01 then 1 else 0 end) as income_mismatch,
    sum(case when rating < 0 or rating > 10 then 1 else 0 end) as rating_out_of_range,
    sum(case when quantity <= 0 then 1 else 0 end) as invalid_qty,
    sum(case when unit_price <= 0 then 1 else 0 end) as invalid_price
from sales_transactions;

-- 1.6 Why gross_margin_percentage is NOT a KPI
select
    count(distinct round(gross_margin_percentage, 9)) as distinct_margin_values,
    min(gross_margin_percentage) as min_margin,
    max(gross_margin_percentage) as max_margin
from sales_transactions;
-- Result: 1 distinct value ≈ 4.761904762 = 5 / 105.
-- Action: never put this on an executive card.


/* =============================================================================
   2) FEATURE ENGINEERING
   These columns describe each invoice. The Power BI Date table is separate.
============================================================================= */

set sql_safe_updates = 0;

alter table sales_transactions
    add column time_of_day   varchar(20),
    add column day_name      varchar(20),
    add column month_name    varchar(20),
    add column hour_of_day   int,
    add column weekend_flag  varchar(10),
    add column week_number   int,
    add column qty_bucket    varchar(20),
    add column spend_bucket  varchar(20);

update sales_transactions
set
    time_of_day = case
        when hour(time) >= 0  and hour(time) < 12 then 'Morning'
        when hour(time) >= 12 and hour(time) < 18 then 'Afternoon'
        else 'Evening'
    end,
    day_name = date_format(date, '%a'),
    month_name = date_format(date, '%b'),
    hour_of_day = hour(time),
    weekend_flag = case
        when dayofweek(date) in (1, 7) then 'Weekend'
        else 'Weekday'
    end,
    week_number = week(date, 3),
    qty_bucket = case
        when quantity <= 3 then 'Small basket'
        when quantity <= 7 then 'Medium basket'
        else 'Large basket'
    end;

update sales_transactions as s
join (
    select
        invoice_id,
        case ntile(4) over (order by total)
            when 1 then 'Low spend'
            when 2 then 'Mid-low spend'
            when 3 then 'Mid-high spend'
            else 'High spend'
        end as spend_bucket
    from sales_transactions
) as t
    on s.invoice_id = t.invoice_id
set s.spend_bucket = t.spend_bucket;

set sql_safe_updates = 1;

select invoice_id, date, time, time_of_day, day_name, month_name,
       hour_of_day, weekend_flag, qty_bucket, spend_bucket
from sales_transactions
limit 10;

select * from sales_transactions limit 5;

/* =============================================================================
   3) EXECUTIVE SNAPSHOT
============================================================================= */

select
    count(*)  as invoices,          -- 1000
    sum(quantity) as units_sold,        -- 5510
    round(sum(total), 2)   as revenue,           -- 322966.75
    round(sum(gross_income), 2) as gross_income,      -- 15379.37  (this is the 5% VAT layer)
    round(avg(total), 2) as avg_order_value,   -- 322.97
    round(avg(rating), 2)  as avg_rating         -- 6.97
from sales_transactions;
-- INSIGHT: One quarter, ~$323k revenue, AOV ~$323, rating just under 7/10.
-- ACTION: Use these six numbers as Power BI header cards. Do not add margin %.


/* =============================================================================
   4) BRANCH PERFORMANCE
============================================================================= */

select
    branch,
    city,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(sum(total) * 100 / sum(sum(total)) over (), 2) as revenue_share_pct,
    rank() over (order by sum(total) desc) as revenue_rank,
    round(avg(total), 2) as avg_order_value,
    round(avg(rating), 2) as avg_rating
from sales_transactions
group by branch, city
order by revenue desc;
-- INSIGHT: C-Naypyitaw is only slightly ahead (~34% share, higher AOV ~$337).
--          A and B are almost tied on revenue. B has the weakest rating (~6.82).
-- ACTION: Do not redesign the network. Study C's basket mix and B's experience.


/* =============================================================================
   5) PRODUCT PERFORMANCE
============================================================================= */

select count(distinct product_line) as distinct_product_lines
from sales_transactions;   -- 6

select
    product_line,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(sum(total) * 100 / sum(sum(total)) over (), 2) as revenue_share_pct,
    round(avg(total), 2) as avg_order_value,
    round(avg(rating), 2) as avg_rating,
    rank() over (order by sum(total) desc) as sales_rank
from sales_transactions
group by product_line
order by revenue desc;
-- INSIGHT: Food and beverages leads revenue and rating (~7.11).
--          Health and beauty is last on revenue. Spread across lines is modest.
-- ACTION: Protect Food and beverages. Do not cut Health and beauty without a
--         4-week promo/placement test first.


-- High sales + below-average rating  (priority watch list)
select
    product_line,
    round(sum(total), 2) as revenue,
    round(avg(rating), 2) as avg_rating
from sales_transactions
group by product_line
having avg(rating) < (select avg(rating) from sales_transactions)
order by revenue desc;
-- INSIGHT: Sports and travel, Electronic accessories, Home and lifestyle
--          sit below the 6.97 average rating.
-- ACTION: Start with Home and lifestyle (lowest rating ~6.84): stock quality,
--         delivery/wait, and evening staffing — not a price war.


-- Good / Bad vs average PRODUCT-LINE revenue  (summary, not a fact-table column)
select
    product_line,
    round(sum(total), 2) as revenue,
    case
        when sum(total) > (
            select avg(pl_sales)
            from (
                select sum(total) as pl_sales
                from sales_transactions
                group by product_line
            ) as avg_tbl
        ) then 'Good'
        else 'Bad'
    end as vs_avg_product_sales
from sales_transactions
group by product_line
order by revenue desc;

-- INSIGHT: "Good" means that product line's total revenue is above the
--          average of the 6 lines. "Bad" means it is below that average.
--          On this file the spread is small, so "Bad" is not a failed category.
--          Health and beauty is usually the one below average on revenue.
-- ACTION: Treat "Bad" as "below average in this tiny sample", not as a
--         failing SKU. Do not delist it. Run a 4-week placement or promo
--         test first. Prefer the rating watch list over this Good/Bad label.

/* =============================================================================
   6) TIME AND OPERATIONS
============================================================================= */

select
    month_name,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(sum(cogs), 2) as cogs
from sales_transactions
group by month_name
order by field(month_name, 'Jan', 'Feb', 'Mar');
-- INSIGHT: February is the soft month (fewer invoices and lower revenue).
-- ACTION: Check Feb stock-outs, local holidays, and promo calendar before assuming demand permanently fell.

select
    date,
    round(sum(total), 2) as daily_revenue,
    round(sum(sum(total)) over (order by date), 2) as running_revenue,
    round(sum(total) - lag(sum(total)) over (order by date), 2) as vs_previous_day
from sales_transactions
group by date
order by date;
-- INSIGHT: Daily sales jump around. Running total should rise more slowly  through February than through January.
-- ACTION: Use this as the Power BI daily trend. Flag large down days in Feb.

select
    weekend_flag,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(avg(total), 2) as avg_order_value,
    round(avg(rating), 2) as avg_rating
from sales_transactions
group by weekend_flag;
-- INSIGHT: Weekdays win total revenue because there are more weekdays.
--          Weekend AOV is higher (~$339 vs ~$316).
-- ACTION: Report both volume and AOV. Do not say "weekdays are better" from
--         revenue alone.

select
    hour_of_day,
    time_of_day,
    count(*) as invoices,
    round(sum(total), 2) as revenue
from sales_transactions
group by hour_of_day, time_of_day
order by hour_of_day;
-- INSIGHT: 19:00 is the revenue peak. 20:00 drops.
-- ACTION: Staff queues and restock fast-moving lines before 19:00.

select
    branch,
    hour_of_day,
    revenue
from (
    select
        branch,
        hour_of_day,
        round(sum(total), 2) as revenue,
        rank() over (partition by branch order by sum(total) desc) as rnk
    from sales_transactions
    group by branch, hour_of_day
) as t
where rnk = 1;
-- INSIGHT: Each branch has one peak hour. It is usually evening, but
--          the exact hour can differ by store.
-- ACTION: Put the extra cashier on that branch's peak hour. Do not copy
--         one timetable onto all three stores without checking this result.

select
    day_name,
    time_of_day,
    count(*) as sales_occurrences
from sales_transactions
group by day_name, time_of_day
order by field(day_name, 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'),
         field(time_of_day, 'Morning', 'Afternoon', 'Evening');
-- INSIGHT: This is a traffic grid. Evenings are generally busier than mornings.
--          Some weekday mornings will look light.
-- ACTION: Build the Power BI heatmap from this query. Move short-staffed
--         slots off the darkest evening cells
select
    qty_bucket,
    count(*) as invoices,
    round(avg(total), 2) as avg_order_value,
    round(sum(total), 2) as revenue
from sales_transactions
group by qty_bucket
order by revenue desc;
-- INSIGHT: Large baskets contribute more revenue per ticket. Small baskets
--          add traffic but less value.
-- ACTION: Test a simple add-on prompt at checkout for 4 weeks and watch AOV.
--         Do not force large baskets if rating falls.


/* =============================================================================
   7) CUSTOMERS AND PAYMENTS
============================================================================= */

select
    customer_type,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(avg(total), 2) as avg_order_value,
    round(sum(gross_income), 2) as gross_income,
    round(avg(rating), 2) as avg_rating
from sales_transactions
group by customer_type;
-- INSIGHT: Member vs Normal is almost even (501 vs 499). Member AOV is only
--          a little higher (~$328 vs ~$318). Rating is not better for Members.
-- ACTION: Do not pitch "loyalty is transforming sales" from this sample.
--         Ask for a true customer ID before building a retention story.

select
    customer_type,
    month_name,
    round(sum(total), 2) as revenue
from sales_transactions
group by customer_type, month_name
order by customer_type, field(month_name, 'Jan', 'Feb', 'Mar');
-- INSIGHT: Both Member and Normal follow the same shape: January stronger,
--          February weaker. Membership does not remove the Feb dip.
-- ACTION: Treat February as a store-wide demand issue, not a loyalty issue.

select
    payment_method,
    count(*) as invoices,
    round(sum(total), 2) as revenue
from sales_transactions
group by payment_method
order by revenue desc;
-- INSIGHT: Cash leads revenue; Ewallet leads ticket count; Credit card is third.
-- ACTION: Keep all three tenders. No evidence here to drop one.

select
    branch,
    payment_method,
    count(*) as invoices,
    round(count(*) * 100 / sum(count(*)) over (partition by branch), 2) as pct_of_branch
from sales_transactions
group by branch, payment_method
order by branch, invoices desc;
-- INSIGHT: Every branch uses Cash, Ewallet, and Credit card. Mix differs a
--          little by store, but no branch is locked to one method.
-- ACTION: Do not design a "cash-only" or "wallet-only" store from this table.
--         Use it only to check that terminals work in every branch.

/* =============================================================================
   8) BUSINESS QUESTIONS 
============================================================================= */

-- ---------------------------------------------------------------------------
-- Q1. Is the data trustworthy?
-- ---------------------------------------------------------------------------
select
    count(*) as total_rows,
    sum(case when invoice_id is null then 1 else 0 end) as null_invoice_id,
    sum(invoice_id is null or branch is null or city is null
        or customer_type is null or gender is null or product_line is null
        or unit_price is null or quantity is null or vat is null
        or total is null or date is null or time is null
        or payment_method is null or cogs is null
        or gross_income is null or rating is null) as rows_with_any_null,
    sum(case when abs(vat - (cogs * 0.05)) > 0.01 then 1 else 0 end) as vat_mismatch,
    sum(case when abs(total - (cogs + vat)) > 0.01 then 1 else 0 end) as total_mismatch,
    sum(case when abs(gross_income - vat) > 0.01 then 1 else 0 end) as income_mismatch,
    sum(case when rating < 0 or rating > 10 then 1 else 0 end) as bad_rating,
    sum(case when quantity <= 0 or unit_price <= 0 then 1 else 0 end) as bad_qty_or_price
from sales_transactions;

select invoice_id, count(*) as duplicate_count
from sales_transactions
group by invoice_id
having count(*) > 1;
-- INSIGHT: 1,000 rows, no duplicates, no nulls, math holds.
-- ACTION: Safe to analyse. Say this first in an interview.


-- ---------------------------------------------------------------------------
-- Q2. Which column looks like a KPI but is not?
-- ---------------------------------------------------------------------------
select
    count(distinct round(gross_margin_percentage, 9)) as distinct_margin_values,
    min(gross_margin_percentage) as min_margin,
    max(gross_margin_percentage) as max_margin,
    round(5 / 105, 9) as five_over_one_oh_five
from sales_transactions;
-- INSIGHT: Margin % is one constant ≈ 4.7619% = 5/105.
-- ACTION: Do not put it on a dashboard card. Use revenue, AOV, rating.


-- ---------------------------------------------------------------------------
-- Q3. What is the quarter snapshot?
-- ---------------------------------------------------------------------------
select
    count(*)                    as invoices,
    sum(quantity)               as units,
    round(sum(total), 2)        as revenue,
    round(sum(gross_income), 2) as gross_income,
    round(avg(total), 2)        as aov,
    round(avg(rating), 2)       as avg_rating,
    min(date)                   as start_date,
    max(date)                   as end_date
from sales_transactions;
-- INSIGHT: 1,000 invoices, 5,510 units, ~$322,967 revenue, AOV ~$323, rating ~6.97.
-- ACTION: These six numbers are the Power BI header.


-- ---------------------------------------------------------------------------
-- Q4. Which branch wins revenue vs AOV vs rating?
-- ---------------------------------------------------------------------------
select
    branch,
    city,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(sum(total) * 100 / sum(sum(total)) over (), 2) as revenue_share_pct,
    round(avg(total), 2) as aov,
    round(avg(rating), 2) as avg_rating,
    sum(quantity) as units
from sales_transactions
group by branch, city
order by revenue desc;
-- INSIGHT: C-Naypyitaw is slightly ahead on revenue and AOV.
--          A and B are almost tied on revenue. B is weakest on rating.
-- ACTION: Study C's basket, not "expand C / close B". Check B's service.


-- ---------------------------------------------------------------------------
-- Q5. Which product line makes money but rates below average?
-- ---------------------------------------------------------------------------
select
    product_line,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(avg(total), 2) as aov,
    round(avg(rating), 2) as avg_rating,
    case
        when avg(rating) < (select avg(rating) from sales_transactions)
            then 'Below avg rating'
        else 'At or above avg rating'
    end as rating_flag
from sales_transactions
group by product_line
order by revenue desc;
-- INSIGHT: Food and beverages is strong on money and rating.
--          Home and lifestyle / Sports / Electronics sit below ~6.97 rating.
-- ACTION: Quality watch list starts with Home and lifestyle (lowest rating).


-- ---------------------------------------------------------------------------
-- Q6. Why is February weaker — fewer invoices, smaller baskets, or both?
-- ---------------------------------------------------------------------------
select
    month_name,
    count(*) as invoices,
    sum(quantity) as units,
    round(sum(total), 2) as revenue,
    round(avg(total), 2) as aov,
    round(avg(quantity), 2) as avg_units_per_invoice,
    round(avg(rating), 2) as avg_rating
from sales_transactions
group by month_name
order by field(month_name, 'Jan', 'Feb', 'Mar');
-- INSIGHT: February has fewer invoices and slightly lower AOV than January.
--          It is mainly a volume dip, not a collapse in ticket size.
-- ACTION: Check Feb holidays, stock-outs, and promos before changing strategy.


-- ---------------------------------------------------------------------------
-- Q7. Which hour makes the most money in each branch,
--     and is rating worse at that hour?
-- ---------------------------------------------------------------------------
with hour_stats as (
    select
        branch,
        hour_of_day,
        count(*) as invoices,
        round(sum(total), 2) as revenue,
        round(avg(rating), 2) as avg_rating,
        rank() over (partition by branch order by sum(total) desc) as rev_rank
    from sales_transactions
    group by branch, hour_of_day
),
branch_avg as (
    select branch, round(avg(rating), 2) as branch_avg_rating
    from sales_transactions
    group by branch
)
select
    h.branch,
    h.hour_of_day as peak_hour,
    h.invoices,
    h.revenue as peak_hour_revenue,
    h.avg_rating as peak_hour_rating,
    b.branch_avg_rating,
    round(h.avg_rating - b.branch_avg_rating, 2) as rating_vs_branch
from hour_stats as h
join branch_avg as b
    on h.branch = b.branch
where h.rev_rank = 1
order by h.branch;
-- INSIGHT: Revenue peaks in the evening (often 19:00). If peak-hour rating
--          is below the branch average, the issue is load / queues.
-- ACTION: This answers "where does one extra staff member go?"


-- ---------------------------------------------------------------------------
-- Q8. Do weekends bring fewer tickets but higher AOV?
-- ---------------------------------------------------------------------------
select
    weekend_flag,
    count(*) as invoices,
    round(count(*) * 100 / sum(count(*)) over (), 2) as invoice_share_pct,
    round(sum(total), 2) as revenue,
    round(avg(total), 2) as aov,
    round(avg(quantity), 2) as avg_units,
    round(avg(rating), 2) as avg_rating
from sales_transactions
group by weekend_flag;
-- INSIGHT: Weekdays win total revenue because there are more weekdays.
--          Weekend AOV is higher.
-- ACTION: Never compare weekend vs weekday on revenue alone.


-- ---------------------------------------------------------------------------
-- Q9. Is Member actually better than Normal?
-- ---------------------------------------------------------------------------
select
    customer_type,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(avg(total), 2) as aov,
    round(sum(gross_income), 2) as gross_income,
    round(avg(rating), 2) as avg_rating
from sales_transactions
group by customer_type;
-- INSIGHT: 501 vs 499 invoices. Member AOV is only a little higher.
--          Member rating is not better.
-- ACTION: Do not build a "loyalty is winning" story from this file.


-- ---------------------------------------------------------------------------
-- Q10. If each store gets only one extra person, which hour do we cover?
-- ---------------------------------------------------------------------------
select
    hour_of_day,
    time_of_day,
    count(*) as invoices,
    round(sum(total), 2) as revenue,
    round(avg(rating), 2) as avg_rating
from sales_transactions
group by hour_of_day, time_of_day
order by revenue desc;
-- INSIGHT: 19:00 is the network peak. 20:00 drops.
-- ACTION: Cover 18:00–20:00 first. Confirm with Q7 per branch.


-- ---------------------------------------------------------------------------
-- Q11. If we can fix only one product line’s experience, which one?
-- ---------------------------------------------------------------------------
select
    product_line,
    round(sum(total), 2) as revenue,
    round(sum(total) * 100 / (select sum(total) from sales_transactions), 2) as revenue_share_pct,
    round(avg(rating), 2) as avg_rating,
    round(avg(rating) - (select avg(rating) from sales_transactions), 2) as rating_vs_overall
from sales_transactions
group by product_line
order by avg_rating asc, revenue desc;
-- INSIGHT: Lowest rating with meaningful sales is the first fix.
--          On this file that is Home and lifestyle (~6.84).
-- ACTION: Check stock quality, evening wait time, and returns for that line
--         for 4 weeks. Do not start with a price cut.


-- ---------------------------------------------------------------------------
-- Q12. What can this dataset not answer?
-- ---------------------------------------------------------------------------
select
    count(*) as invoices,
    count(distinct invoice_id) as distinct_invoices,
    count(distinct concat(branch, '-', city)) as stores,
    count(distinct date) as days_with_sales,
    datediff(max(date), min(date)) + 1 as calendar_days_in_span,
    count(distinct round(gross_margin_percentage, 9)) as distinct_margin_values
from sales_transactions;
-- INSIGHT / LIMITS:
--   1. No customer_id → cannot measure repeat purchase or true loyalty.
--   2. Margin % is constant → cannot compare real profitability by product.
--   3. Only Jan–Mar 2019 → no seasonality or year-on-year.
--   4. 3 stores, 1,000 rows → small gaps are not national strategy.
-- ACTION: State these limits in the README and on the last Power BI page.


