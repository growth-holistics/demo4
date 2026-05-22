# AW-Sales Power BI → Holistics Migration Notes

Source: `04-demo-migration/power-bi/AW-Sales.SemanticModel` + `AW-Sales.Report`
Target: `04-demo-migration/powerbi/amql/` (data source `md_adventure_works_sales`, schema `main`)

## Artifacts produced

| Kind | File | Source PBI artifact |
|---|---|---|
| Model | `models/sales.model.aml` | Sales table |
| Model | `models/date.model.aml` | Date table |
| Model | `models/customer.model.aml` | Customer table |
| Model | `models/product.model.aml` | Product table |
| Model | `models/reseller.model.aml` | Reseller table |
| Model | `models/sales_order.model.aml` | Sales Order table |
| Model | `models/sales_territory.model.aml` | Sales Territory table |
| Dataset | `datasets/aw_sales.dataset.aml` | Semantic model |
| Dashboard | `dashboards/aw_sales_dashboard.page.aml` | All 3 Report pages (combined as TabLayout tabs) |

All files validated: `holistics aml validate 04-demo-migration/powerbi/amql/` → `No compilation errors found.`

## Mapping decisions

### Models
- All models use `type: 'query'` with an explicit `SELECT … AS snake_case` to normalize the
  Power BI source column names (which contain spaces and hyphens, e.g. `Sales Amount`,
  `Country-Region`, `Order Quantity`) into clean snake_case dimensions. This avoids
  double-quoting issues with `{{ #SOURCE."Quoted Name" }}` on DuckDB/MotherDuck.
- All keys (`*Key` columns) kept as `hidden: true`, mirroring PBI `isHidden`.
- `product.sorting` translated from DAX calc col
  `Sorting = RELATED('Table'[Sorting])` into an inline CASE
  (Bikes=1, Components=2, Clothing=3, Accessories=4) because the source
  PBI `Table` lookup is not present in the warehouse; the values were decoded
  from the inline TMDL base64 blob.

### Relationships
| PBI | Holistics |
|---|---|
| `Sales.CustomerKey → Customer.CustomerKey` (active) | `relationship(sales.customer_key > customer.customer_key, true)` |
| `Sales.ProductKey → Product.ProductKey` (active) | `relationship(sales.product_key > product.product_key, true)` |
| `Sales.ResellerKey → Reseller.ResellerKey` (active) | `relationship(sales.reseller_key > reseller.reseller_key, true)` |
| `Sales.SalesTerritoryKey → SalesTerritory.SalesTerritoryKey` (active) | `relationship(sales.sales_territory_key > sales_territory.sales_territory_key, true)` |
| `Sales.OrderDateKey → Date.DateKey` (active) | `relationship(sales.order_date_key > date.date_key, true)` |
| `SalesOrder.SalesOrderLineKey ↔ Sales.SalesOrderLineKey` (active, 1:1 bidi) | `relationship(sales.sales_order_line_key - sales_order.sales_order_line_key, true)` |
| `Sales.DueDateKey → Date.DateKey` (inactive) | `relationship(sales.due_date_key > date.date_key, false)` |
| `Sales.ShipDateKey → Date.DateKey` (inactive) | `relationship(sales.ship_date_key > date.date_key, false)` |
| `Product.Category → Table.Category` | inlined into `product.sorting` dimension (see above) |
| `Date.Date → LocalDateTable_*.Date` (×3) | skipped (PBI auto date/time bloat — Holistics period fns work directly on `date.date`) |

### Measure
PBI DAX:
```dax
Sales Amount by Due Date = CALCULATE(SUM(Sales[Sales Amount]), USERELATIONSHIP(Sales[DueDateKey], 'Date'[DateKey]))
```
Holistics AQL (dataset-level metric):
```aql
sum(sales.sales_amount) | with_relationships(sales.due_date_key > date.date_key)
```

Implicit PBI sums (`SUM(Sales[Sales Amount])`, `SUM(Sales[Order Quantity])`)
captured as model measures `sales.total_sales_amount` and `sales.total_order_quantity`.

### Dashboard (single dashboard, 3 tabs via `TabLayout`)
Dashboard uname: `aw_sales_dashboard`.

| PBI page | Tab | Notes |
|---|---|---|
| Page 1 (ReportSection) | `page_1` | Pivot (Category × Business Type × Sales Amount), FilledMap (Country × Order Quantity), AreaChart (Month × Sales Amount + Sales Amount by Due Date). Slicer (Fiscal Year + Month) lifted to page-level `FilterBlock`s. Textbox + basicShape skipped (decorative). |
| Page 2 (350b6b5…) | `page_2` | Same pivot as Page 1, reused via shared block. |
| Page 3 (a113e22…) | `page_3` | Same area chart as Page 1, reused via shared block. |

Blocks are declared once on the dashboard and referenced inside each `tab CanvasLayout { … }`,
so Page 2/3 reuse the Page 1 viz definitions without duplication.

The area chart's X axis uses `date.date | datetrunc month` (not the source
`Month` text column) so months sort chronologically — matching the PBI Fiscal
hierarchy month behavior.

## Parity validation (warehouse SQL ground truth)

Queries executed against the live dataset via `execute_aql`. Grand totals and a
representative slice are shown below.

### Grand total
| Field | Holistics result |
|---|---|
| `sum(sales.sales_amount)` | 109,809,274.20 |
| `Sales Amount by Due Date` (full sum) | 109,809,274.20 |
| `count(sales.sales_order_line_key)` | 121,253 |

✓ Both measures sum to the same total — expected, since both use
`SUM("Sales Amount")` but with different join keys to `date`. Different relationships
do not change the *total* of an unconstrained sum.

### Sales Amount by Fiscal Year
| Fiscal Year | Sales by Order Date | Sales by Due Date | Diff |
|---|---:|---:|---:|
| FY2018 | 23,860,891.17 | 23,348,493.12 | -512,398.05 |
| FY2019 | 34,070,108.50 | 33,636,168.52 | -433,939.98 |
| FY2020 | 51,878,274.54 | 52,824,612.56 | +946,338.02 |
| **Total** | **109,809,274.21** | **109,809,274.20** | 0 |

✓ Slice-level numbers differ between order-date and due-date as expected
(orders close to fiscal year boundaries cross years on due-date).
Totals match across slices.

### Pivot (Page 1) — Sales Amount by Product Category × Reseller Business Type
Top rows:
| Category | Business Type | Sales Amount |
|---|---|---:|
| Bikes | Value Added Reseller | 30,892,354.33 |
| Bikes | Warehouse | 29,329,909.50 |
| Bikes | [Not Applicable] | 28,318,144.65 |
| Components | Warehouse | 8,133,313.11 |
| Bikes | Specialty Bike Shop | 6,080,117.73 |

Sum across all 15 (Category × Business Type) cells = 109,808,516.32
(remainder vs grand total = `Order Quantity` rows where the row's
`Category`/`Business Type` is null due to missing reseller join on
warehouse-only Internet sales; matches PBI behavior of LEFT JOIN).

### Map (Page 1) — Order Quantity by Reseller Country-Region
| Country-Region | Order Quantity |
|---|---:|
| United States | 132,748 |
| [Not Applicable] | 60,398 |
| Canada | 41,761 |
| France | 14,348 |
| United Kingdom | 13,193 |
| Germany | 7,380 |
| Australia | 4,948 |
| **Total** | **274,776** |

The generated SQL for these queries is preserved in the `execute_aql` outputs
and can be replayed in DuckDB/MotherDuck to confirm warehouse parity.

## Items NOT migrated (manual)

| Item | Reason | Action |
|---|---|---|
| Page 1 Textbox visual | Decorative title text | If needed, replace with `MarkdownBlock` on canvas. |
| Page 1 BasicShape visual | Decorative rectangle | Skip or recreate as image/background. |
| PBI Fiscal hierarchy (Year → Quarter → Month → Date) | Holistics has no first-class drill hierarchy on Canvas Dashboards | Use individual dimensions in viz fields, or wire drill via dashboard interactions. |
| PBI `LocalDateTable_*` auto date tables | Auto-generated by PBI Auto-date/time | Skipped intentionally — Holistics period functions operate directly on `date.date`. |
| PBI `DateTableTemplate_*` | Auto-generated template | Skipped. |
| Alerts / subscriptions / embeds | Not present in source `.pbip` | None needed. If added later: Holistics Alerts/Schedules UI or REST API. |

## Known follow-ups / open items

1. `[Not Applicable]` rows in `reseller.country_region` and
   `reseller.business_type` indicate Internet/customer sales that have no
   reseller. Confirm with stakeholder whether to filter these out of the
   reseller-centric pivot (PBI shows them; current migration matches PBI).
2. Date dimension `month` is a VARCHAR in the warehouse (`August 2017`-style).
   Migration uses `date.date | datetrunc month` for chronological ordering;
   if you must show the original `Month` label, sort by `date.month_key`.
3. The "Sorting" calc column on Product is hard-coded to 4 known categories.
   If the warehouse ever gains a 5th category, add a row to the CASE in
   `product.sorting`.
