# Revenue Reconciliation — Power BI Financial Report

Subscription business analytics project built in **Power BI Desktop** to reconcile revenue and cash across CRM, billing, and subscription service systems.

**Repository:** `sri-yuh/Revenue-Reconcilliation`  
**Assignment:** Assignment 1 — Revenue Reconciliation Exercise  
**Report file:** Power BI financial report package  
**Data sources:** 3 CSV files

---

## 1. Project Objective

The objective of this project is to establish a **single reconciled view of revenue and cash** by combining data from three internal systems:

1. **CRM** — signed customer contracts and committed recurring revenue.
2. **Billing** — invoices, collections, write-offs, and payment status.
3. **Subscription service system** — whether the customer is actually receiving service.

Leadership currently receives conflicting numbers from different systems. This Power BI model resolves those conflicts and produces one trusted view of:

- Current ARR
- Cash collected during the current month
- Monthly churn
- Customers receiving service without payment
- Customers paying without receiving service

---

## 2. Business Context

The company operates on a **subscription model**. A customer may be contractually committed in CRM, invoiced in billing, and either active, paused, or cancelled in the service system.

Because each system captures a different stage of the customer lifecycle, inconsistencies can occur. Examples include:

- A customer marked as active in CRM but not receiving service.
- A customer receiving service despite no recent payment.
- A customer paying invoices while their service is paused or cancelled.
- Cancelled customers still appearing in revenue numbers.

The reconciliation model aligns these sources into a trusted reporting layer.

---

## 3. CSV Tables Used

### 3.1 `crm_contracts.csv`

**Purpose:** Source of contractual revenue commitments and customer contract metadata.  
**Grain:** One row per customer contract.  
**Primary key:** `contract_id`  
**Join key:** `customer_id`

| Column | Description |
|---|---|
| `customer_id` | Unique customer identifier used to join across all three systems. |
| `contract_id` | Unique contract identifier. |
| `service_plan` | Subscription product or service plan, such as VAT, Bookkeeping, or Corporate Tax. |
| `contract_start_date` | Contract start date. |
| `contract_end_date` | Contract end date. |
| `billing_cycle` | Billing frequency: Monthly, Quarterly, or Annual. |
| `contract_value` | Total value of the contract. |
| `mrr` | Monthly recurring revenue used to calculate ARR. |
| `contract_status` | CRM status of the contract, such as Won or Cancelled. |
| `upgrade_downgrade_flag` | Indicates whether the customer had an upgrade or downgrade. |
| `upgrade_date` | Date of upgrade or downgrade, where applicable. |
| `sales_owner` | Sales owner responsible for the account. |

**Dataset size:** 220 rows, 12 columns.

---

### 3.2 `billing_invoices.csv`

**Purpose:** Source of invoices, payment activity, collections, and write-off indicators.  
**Grain:** One row per invoice.  
**Primary key:** `invoice_id`  
**Join key:** `customer_id`

| Column | Description |
|---|---|
| `invoice_id` | Unique invoice identifier. |
| `customer_id` | Customer identifier used to join with CRM and subscription status. |
| `invoice_date` | Date the invoice was issued. |
| `invoice_amount` | Base invoice amount before tax. |
| `tax_amount` | Tax charged on the invoice. |
| `total_amount` | Invoice amount including tax. |
| `payment_status` | Payment status: Paid, Partial, or Unpaid. |
| `amount_paid` | Amount actually collected from the customer. |
| `payment_date` | Date on which payment was received. |
| `write_off_flag` | Indicates whether the invoice was written off. |

**Dataset size:** 670 rows, 10 columns.

---

### 3.3 `subscriptions_status.csv`

**Purpose:** Source of service delivery status and churn indicators.  
**Grain:** One row per customer subscription status.  
**Primary key / join key:** `customer_id`

| Column | Description |
|---|---|
| `customer_id` | Customer identifier used to join across all three systems. |
| `service_plan` | Service plan being delivered. |
| `service_status` | Current delivery status: Active, Paused, or Cancelled. |
| `activation_date` | Date service was activated. |
| `cancellation_date` | Date service was cancelled or scheduled for cancellation. |
| `cancellation_reason` | Reason for cancellation, such as Non payment, Customer left, or Internal. |
| `delivery_owner` | Operations owner responsible for service delivery. |
| `last_service_date` | Most recent date on which service activity was recorded. |

**Dataset size:** 220 rows, 8 columns.

---

## 4. Data Model

The Power BI model uses `customer_id` as the common reconciliation key across all three datasets.

Recommended relationship structure:

```text
crm_contracts[customer_id] 1 ─── * billing_invoices[customer_id]
crm_contracts[customer_id] 1 ─── 1 subscriptions_status[customer_id]
```

Recommended supporting date fields:

- `contract_start_date`
- `contract_end_date`
- `invoice_date`
- `payment_date`
- `activation_date`
- `cancellation_date`
- `last_service_date`

For the uploaded dataset, the latest reporting month is **January 2026** based on the latest invoice and payment activity.

---

## 5. Key Metrics Produced

### 5.1 Current ARR

**Definition:** Annual recurring revenue from customers that are contractually valid and actually receiving service.

**Logic:**

```text
Current ARR = SUM(crm_contracts[mrr]) × 12
```

Include only customers where:

- `contract_status = "Won"`
- Contract is active during the reporting month
- `service_status = "Active"`

This prevents cancelled, paused, or non-delivered customers from inflating ARR.

**January 2026 result from dataset:** `4,227,852`

---

### 5.2 Cash Collected During Current Month

**Definition:** Actual cash collected during the current reporting month.

**Logic:**

```text
Cash Collected = SUM(billing_invoices[amount_paid])
```

Include only invoices where:

- `payment_date` falls within the current reporting month
- `amount_paid > 0`

Unpaid invoices are not counted as cash. Write-offs are not treated as cash unless there is an actual `amount_paid` value.

**January 2026 result from dataset:** `269,550.50`

---

### 5.3 Monthly Churn

**Definition:** Customers whose service was cancelled in the current reporting month.

**Logic:**

```text
Monthly Churn MRR = SUM(crm_contracts[mrr]) for customers with cancellation_date in current month
Monthly Churn ARR = Monthly Churn MRR × 12
```

Churn is primarily determined from the service system because it confirms whether the customer actually stopped receiving service.

**January 2026 result from dataset:**

- Churned customers: `13`
- Churn MRR: `37,046`
- Churn ARR impact: `444,552`

---

### 5.4 Customers Receiving Service Without Payment

**Definition:** Customers whose service is active but who have not made a payment in the current reporting month.

**Logic:**

```text
Service Without Payment = Active service customers - Customers with current-month payment
```

Include customers where:

- `service_status = "Active"`
- No invoice payment exists in the current reporting month

This helps identify leakage where the company is delivering service without matching current cash collection.

**January 2026 result from dataset:** `112 customers`

---

### 5.5 Customers Paying Without Receiving Service

**Definition:** Customers who made a payment in the current reporting month but are not actively receiving service.

**Logic:**

```text
Paying Without Service = Customers with current-month payment AND service_status <> "Active"
```

Include customers where:

- `amount_paid > 0`
- `payment_date` falls within the current reporting month
- `service_status` is Paused or Cancelled

This helps identify billing and service delivery mismatches.

**January 2026 result from dataset:** `18 customers`

---

## 6. Reconciliation Rules

The model resolves conflicts between systems using the following hierarchy:

| Conflict Scenario | Resolution Rule |
|---|---|
| CRM says contract is active, but service is paused or cancelled | Exclude from trusted Current ARR until service is active. |
| Service is active, but there is no current-month payment | Flag as receiving service without payment. |
| Billing shows payment, but service is paused or cancelled | Flag as paying without receiving service. |
| Invoice is unpaid | Exclude from cash collected. |
| Invoice is partially paid | Count only the `amount_paid`, not the full invoice amount. |
| Invoice is written off | Do not treat write-off as cash; only count actual payment received. |
| Customer has cancellation date in the reporting month | Count as monthly churn. |

---

## 7. Recommended Power BI Measures

```DAX
Current ARR =
CALCULATE(
    SUM(crm_contracts[mrr]) * 12,
    crm_contracts[contract_status] = "Won",
    subscriptions_status[service_status] = "Active"
)
```

```DAX
Cash Collected Current Month =
CALCULATE(
    SUM(billing_invoices[amount_paid]),
    billing_invoices[amount_paid] > 0
)
```

```DAX
Monthly Churn MRR =
CALCULATE(
    SUM(crm_contracts[mrr]),
    subscriptions_status[service_status] = "Cancelled"
)
```

```DAX
Monthly Churn ARR =
[Monthly Churn MRR] * 12
```

```DAX
Customers Receiving Service Without Payment =
COUNTROWS(
    FILTER(
        subscriptions_status,
        subscriptions_status[service_status] = "Active"
    )
)
-
DISTINCTCOUNT(billing_invoices[customer_id])
```

```DAX
Customers Paying Without Receiving Service =
CALCULATE(
    DISTINCTCOUNT(billing_invoices[customer_id]),
    billing_invoices[amount_paid] > 0,
    subscriptions_status[service_status] <> "Active"
)
```

> Note: In the final Power BI model, the payment and churn measures should be filtered by the selected reporting month using a Date table connected to `payment_date` and `cancellation_date`.

---

## 8. Dashboard Pages

Recommended report pages:

1. **Executive Summary**
   - Current ARR
   - Current-month cash collected
   - Monthly churn
   - Reconciliation exception count

2. **Revenue Reconciliation**
   - CRM ARR vs trusted ARR
   - Active contracts vs active service
   - ARR by service plan
   - ARR by sales owner

3. **Cash Collection**
   - Paid, partial, and unpaid invoices
   - Cash collected by month
   - Write-off flagged invoices
   - Outstanding invoice exposure

4. **Service Exceptions**
   - Customers receiving service without payment
   - Customers paying without receiving service
   - Paused and cancelled service accounts
   - Exception list by customer

5. **Churn Analysis**
   - Churned customers
   - Churn ARR impact
   - Churn by reason
   - Churn by service plan

---

## 9. One-Page Calculation Logic Summary

Revenue is calculated from CRM `mrr`, but it is only treated as trusted ARR when the customer has a won contract and is actively receiving service. ARR is calculated as monthly recurring revenue multiplied by 12.

Cash collected is calculated from the billing system using actual `amount_paid` values where `payment_date` falls in the reporting month. Unpaid invoices are excluded, partial payments count only the amount received, and write-offs are not treated as cash unless a payment amount exists.

Churn is calculated from the subscription service system using customers whose `cancellation_date` falls in the reporting month. The churned customers are joined back to CRM to calculate churned MRR and churned ARR impact.

Conflicts are resolved by using CRM as the source of contractual value, billing as the source of cash truth, and the service system as the source of delivery truth. A customer is counted in trusted ARR only when contract and service data agree. If service is active but no current payment exists, the customer is flagged as receiving service without payment. If payment exists but service is paused or cancelled, the customer is flagged as paying without receiving service.

---

## 10. Submission Checklist

- [x] Power BI working model/report
- [x] CRM contracts CSV connected
- [x] Billing invoices CSV connected
- [x] Subscription status CSV connected
- [x] Reconciled ARR metric
- [x] Current-month cash collection metric
- [x] Monthly churn metric
- [x] Service without payment exception list
- [x] Payment without service exception list
- [x] Calculation logic documented

---

## 11. Files Included

```text
crm_contracts.csv
billing_invoices.csv
subscriptions_status.csv
Power BI report file
README.md
```

---

## 12. Outcome

This report provides a single trusted financial view by reconciling contractual revenue, invoice collection, and service delivery status. It allows leadership to monitor ARR, cash collection, churn, and operational mismatches from one Power BI dashboard instead of relying on conflicting numbers from separate systems.
