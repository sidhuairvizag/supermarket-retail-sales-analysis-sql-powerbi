# Supermarket Retail Sales Analysis (MySQL + Power BI)

End-to-end retail sales analysis for a Junior Data Analyst / Data Analyst apprenticeship portfolio.

Stack: MySQL 8 · Power BI
Data: 1,000 public supermarket invoices · 3 branches · 1 Jan 2019 – 30 Mar 2019
Scope note: This is a public sample, not Amazon (or any company) production data.

---

## 1. Project overview

This project follows a full analyst workflow:

1. Load and validate transaction data in MySQL
2. Run data quality checks (nulls, duplicates, business rules)
3. Build features (time of day, weekday/weekend, hour, baskets)
4. Answer business questions with SQL (insights + actions)
5. Build a 5-page Power BI dashboard for executives and operations
6. State dataset limits clearly so recommendations stay honest

Business questions covered:
- Is the data trustworthy?
- Which branch and product lines drive revenue vs rating?
- Is Member clearly better than Normal?
- When is peak demand, and where should extra staff go?
- What can this sample not support?

---

## 2. Tech stack

| Tool | Use |
|---|---|
| MySQL 8 | Load, quality checks, feature engineering, analysis queries |
| Power BI | Star-style model (fact + Date table), measures, 5 dashboard pages |
| CSV | Source extract: supermarket_sales_2019.csv |

---

## 3. Repository structure

```text
supermarket-retail-sales-analysis-sql-powerbi/
├── README.md
├── data/
│   └── supermarket_sales_2019.csv
├── sql/
│   └── supermarket_retail.sql
├── power-bi/
│   └── supermarket_retail.pbix
└── dashboard-images/
    ├── Dashboard 1 Supermarket Retail Performance.jpg
    ├── Dashboard 2 Product Performance and Rating.jpg
    ├── Dashboard 3 Customers and Payments.jpg
    ├── Dashboard 4 Time and Operations.jpg
    └── Dashboard 5 Data Quality and Limits.jpg
```

If your local folders still use older names (mysql workbench, bi analysis, etc.), rename them to match the layout above before sharing the repo.

---

## 4. Dataset

| Field / fact | Detail |
|---|---|
| Rows | 1,000 invoices |
| Branches | A (Yangon), B (Mandalay), C (Naypyitaw) |
| Date range | 2019-01-01 to 2019-03-30 |
| Product lines | 6 |
| Customer types | Member, Normal |
| Payment methods | Cash, Ewallet, Credit card |

Important limits:
1. No customer_id → no true loyalty, retention, or repeat-purchase analysis
2. gross_margin_percentage is constant (~4.76% = 5/105) → not a real product/branch margin KPI
3. Only 3 months → no seasonality or year-on-year
4. 3 stores / 1,000 rows → small gaps are not a national strategy

---

## 5. What was done in MySQL

File: sql/supermarket_retail.sql

Data quality:
- Null audit
- Duplicate invoice check
- Allowed-value checks (branch, city, customer type, payment, product line)
- Range checks (dates, prices, quantities, ratings)
- Business rules:
  - VAT ≈ 5% of COGS
  - Total ≈ COGS + VAT
  - Gross income ≈ VAT
- Proof that margin % is a constant, not a KPI

Feature engineering:
- time_of_day (Morning / Afternoon / Evening)
- day_name, month_name, hour_of_day
- weekend_flag
- qty_bucket, spend_bucket

Analysis sections:
- Executive snapshot (invoices, units, revenue, AOV, rating)
- Branch performance
- Product performance + rating watch list
- Time and operations (month, hour, weekend)
- Customers and payments
- Portfolio questions with INSIGHT and ACTION comments

---

## 6. What was done in Power BI

File: power-bi/supermarket_retail.pbix

Model:
- Fact table: sales_transactions
- Date table (DAX CALENDAR) related to sales dates
- Core measures: Invoices, Units, Revenue, Gross Income, AOV, Avg Rating
- Comparison measures: Member/Normal and Weekday/Weekend splits
- Gross margin % hidden from executive cards

Dashboard pages:

| Page | Purpose |
|---|---|
| 1. Executive | KPI header, revenue by month/city/product/payment, top decisions |
| 2. Product & rating | Revenue vs rating, watch list, product × city matrix |
| 3. Customers & payments | Member vs Normal near-tie, monthly pattern, payment mix |
| 4. Time & operations | Peak hour (~19:00), weekday vs weekend, day × time traffic |
| 5. Data quality & limits | Quality checklist, margin warning, explicit cannot-answer limits |

---

## 7. Key findings (sample)

1. ~1,000 invoices, ~$323K revenue, AOV ~$323, avg rating ~6.97 for the quarter.
2. February is weaker on volume, not proof of permanent demand collapse.
3. Naypyitaw is slightly ahead on revenue/AOV; gaps between branches are small.
4. Food and beverages is strong on revenue and rating; Home and lifestyle needs a quality watch (lowest rating with meaningful sales).
5. Member vs Normal is almost even (501 vs 499). Do not claim loyalty is transforming sales.
6. Revenue peaks around 19:00; staff and restock for 18:00–20:00 first.
7. Weekdays drive volume; weekends show higher AOV — do not compare on revenue alone.

---

## 8. Dashboard previews

### Page 1 — Executive
![Dashboard 1](dashboard-images/Dashboard%201%20Supermarket%20Retail%20Performance.jpg)

### Page 2 — Product and rating
![Dashboard 2](dashboard-images/Dashboard%202%20Product%20Performance%20and%20Rating.jpg)

### Page 3 — Customers and payments
![Dashboard 3](dashboard-images/Dashboard%203%20Customers%20and%20Payments.jpg)

### Page 4 — Time and operations
![Dashboard 4](dashboard-images/Dashboard%204%20Time%20and%20Operations.jpg)

### Page 5 — Data quality and limits
![Dashboard 5](dashboard-images/Dashboard%205%20Data%20Quality%20and%20Limits.jpg)

---

## 9. How to run

### MySQL
1. Install MySQL 8 and MySQL Workbench.
2. Copy data/supermarket_sales_2019.csv to your server upload folder (or adjust the path).
3. Open sql/supermarket_retail.sql.
4. Update the LOAD DATA INFILE path to your machine.
5. Run the script section by section (create → load → quality → features → analysis).

### Power BI
1. Open power-bi/supermarket_retail.pbix in Power BI Desktop.
2. If needed, retarget the data source to your MySQL instance or a local copy of the CSV/table.
3. Refresh and review the five report pages.

---

## 10. Skills demonstrated

- SQL data profiling and business-rule validation
- Feature engineering for time and basket analysis
- Clear KPI design (and rejection of misleading metrics)
- Power BI modeling (Date table, measures, relationships)
- Executive storytelling with decisions, not only charts
- Explicit communication of data limits and risk

---

## 11. Disclaimer

This project uses a public supermarket transaction sample.
It is intended to demonstrate analysis process and communication quality for entry-level / apprenticeship data roles.
Findings apply only to this 3-month, 3-branch sample and should not be treated as company strategy recommendations.

---

## 12. Author

GitHub: https://github.com/sidhuairvizag
Repo: https://github.com/sidhuairvizag/supermarket-retail-sales-analysis-sql-powerbi
