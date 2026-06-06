# Revenue Reconciliation — Calculation Logic
**Reporting period:** January 2026 (latest fully-populated month in the source data)

## Source systems & key fields
- **CRM** (`crm_contracts.csv`): `contract_status` = `Won` (currently active/in force) or `Cancelled` (terminated); `mrr` = monthly recurring revenue per the signed contract.
- **Billing** (`billing_invoices.csv`): `payment_status` = `Paid` / `Partial` / `Unpaid`; `amount_paid` = actual cash received (the figure that matters for collections, as opposed to `invoice_amount`/`total_amount` which is what was billed); `write_off_flag` marks invoices no longer expected to be collected.
- **Service** (`subscriptions_status.csv`): `service_status` = `Active` / `Paused` / `Cancelled`; `cancellation_date` = the date delivery actually stopped; `last_service_date` = most recent date service was delivered.

## 1. Current ARR
**Source of truth: CRM.** `ARR = SUM(mrr) × 12` over every contract where `contract_status = Won`.
The signed, uncancelled contract is the cleanest definition of committed recurring revenue — billing can lag a new signing, and service activation can lag both, so neither reflects the committed value as accurately as the contract record.

## 2. Cash Collected (current month)
**Source of truth: Billing.** `Cash collected = SUM(amount_paid)` for invoices where `payment_date` falls in January 2026 and `write_off_flag = No`.
We use `amount_paid` rather than `invoice_amount`/`total_amount` because it is the only field that reflects money that has actually landed — a `Partial` invoice still contributes its real, partial cash amount. Written-off invoices are excluded since no further cash is expected. Fully `Unpaid` invoices for the period are listed separately as a collections follow-up, not counted as cash.

## 3. Monthly Churn
**Source of truth: CRM confirms *that* a customer churned; Service supplies *when*.**
CRM's `contract_status = Cancelled` is the authoritative signal that a customer has actually left (a contractual fact), but CRM has no cancellation date. Service's `cancellation_date` supplies that date. A customer is counted as **churned this month** only when both agree: `contract_status = Cancelled` **and** `cancellation_date` falls within January 2026.

`Churn rate = churned customers ÷ all customers under contract at the start of the period` (every `Won` or `Cancelled` contract — i.e. everyone who had an active relationship going into the month).

## 4. Customers Receiving Service Without Payment
Cross-check between **Service** and **Billing**: customers whose `service_status = Active` (still being delivered to) but whose January invoice is `Unpaid` or `Partial` (and not written off).
This is revenue leakage / collections risk — the company is delivering value it hasn't been paid for.

## 5. Customers Paying Without Receiving Service
Cross-check between **Billing** and **Service**: customers with a fully `Paid` January invoice whose `service_status` is `Paused` or `Cancelled`.
This is a refund / customer-experience risk — cash has been collected for a service that isn't currently being delivered (often seen when a final invoice is paid just before or just after delivery is switched off).

## How Conflicts Between Systems Are Resolved
No single system is treated as universally "correct" — each metric is anchored to the system best positioned to know that specific fact, and disagreements between systems are *surfaced*, not silently resolved away:

| Metric | Trusted system(s) | Why |
|---|---|---|
| ARR | CRM | The contract is the legal definition of committed revenue |
| Cash collected | Billing (`amount_paid`) | Only system that records money actually received |
| Churn | CRM (fact) + Service (date) | CRM knows the contract ended; Service knows when delivery stopped — combining them avoids relying on either system's blind spot |
| Service-without-payment / Payment-without-service | Cross-check (Service × Billing) | These metrics are *defined* as the disagreement between the two systems — they are the reconciliation output itself, not something to average away |

This gives leadership one explainable number per metric, each traceable to a specific system and rule, plus two explicit exception lists (service-without-payment, payment-without-service) that show exactly where — and for which customers — the systems disagree.
