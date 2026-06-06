# Revenue Reconciliation — Calculation Logic
**Reporting period:** May 2026

## 1. Current ARR
**Source of truth: CRM** (`crm_contracts.csv`) — the contract is the legal commitment to pay, regardless of whether billing or service has caught up yet.

`ARR = SUM(monthly_contract_value) × 12` for every contract where `contract_status = Active` **and** (`contract_end_date` is blank or later than the reporting month-end).

Billing and service data are *not* used for ARR — invoices can lag a new signing, and service activation can lag both, so neither reflects the committed value as accurately as the signed contract.

## 2. Cash Collected (current month)
**Source of truth: Billing** (`billing_invoices.csv`) — this is the only system that records actual money received.

`Cash collected = SUM(invoice_amount)` where `payment_status = Paid` **and** `payment_date` falls within the reporting month.

`Partial` payments are deliberately excluded from the collected total (only the realized cash counts) and are listed separately as an AR follow-up item so leadership can see the gap between invoiced and collected.

## 3. Monthly Churn
**Source of truth: CRM** — churn is a contractual event (cancellation), not a billing or service event.

A customer is **churned** if `contract_status = Cancelled` and `contract_end_date` falls inside the reporting month.

`Churn rate = churned customers ÷ customers active at the start of the month`
("active at start of month" = contract started before the 1st and not yet ended as of the 1st).

Service status is intentionally not used to define churn — a customer can show as "Inactive" for operational reasons (e.g., suspension) while their contract is still live, which is not the same as having actually left.

## 4. Customers Receiving Service Without Payment
Cross-check between **Service** (`subscriptions_status.csv`) and **Billing** (`billing_invoices.csv`):
flag any customer whose service is `Active` for the month but whose current-month invoice is `Unpaid` or `Partial`.
This represents revenue leakage / collections risk — the company is delivering value it hasn't been paid for.

## 5. Customers Paying Without Receiving Service
Cross-check between **Billing** and **Service**:
flag any customer whose current-month invoice is `Paid` but whose service status is `Inactive` or `Suspended`.
This represents a customer-experience / refund risk — the company has collected cash for a service it isn't currently delivering (commonly seen right after a cancellation date when the final invoice was issued before service was switched off).

## How Conflicts Between Systems Are Resolved
Each metric is anchored to the *one* system best positioned to know that fact, rather than averaging or guessing across systems:

| Metric | Trusted system | Why |
|---|---|---|
| ARR | CRM | Defines the contractual commitment |
| Cash collected | Billing | Only system that records money actually received |
| Churn | CRM | Cancellation is a contractual event |
| Service-without-payment / Payment-without-service | Cross-check (Billing × Service) | These are *defined* as disagreements between the two systems, surfaced explicitly rather than resolved away |

Where systems disagree on facts that *should* agree (e.g., a customer marked Active in CRM but with no current invoice in Billing), the discrepancy is surfaced as an exception list rather than silently picking one side — this is what drives the "service without payment" / "payment without service" reconciliation views and gives leadership a single, explainable number instead of three competing ones.
