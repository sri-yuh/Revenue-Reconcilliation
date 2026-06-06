-- Revenue Reconciliation Model
-- Reporting period: May 2026 ("current month")
-- Source tables loaded from data/crm_contracts.csv, data/billing_invoices.csv, data/subscriptions_status.csv

-- =====================================================================
-- 1. CURRENT ARR
-- Trusted source: CRM (contractual commitment), filtered to contracts
-- that are Active AND have no end date on/before the reporting month.
-- =====================================================================
SELECT
    SUM(monthly_contract_value) * 12 AS current_arr
FROM crm_contracts
WHERE contract_status = 'Active'
  AND (contract_end_date IS NULL OR contract_end_date > '2026-05-31');

-- =====================================================================
-- 2. CASH COLLECTED DURING CURRENT MONTH
-- Trusted source: Billing (only realized cash, not invoiced amounts).
-- Only invoices with payment_status = 'Paid' AND payment_date inside
-- the reporting month count as cash collected. 'Partial' payments are
-- excluded from full collection and flagged separately for follow-up.
-- =====================================================================
SELECT
    SUM(invoice_amount) AS cash_collected_may_2026
FROM billing_invoices
WHERE payment_status = 'Paid'
  AND payment_date BETWEEN '2026-05-01' AND '2026-05-31';

-- Partial payments needing follow-up (visibility only, not counted as collected)
SELECT customer_id, invoice_amount, payment_status
FROM billing_invoices
WHERE payment_status = 'Partial';

-- =====================================================================
-- 3. MONTHLY CHURN
-- Trusted source: CRM contract_status / contract_end_date.
-- Churned = contracts whose status changed to 'Cancelled' with an
-- end_date falling inside the reporting month.
-- Churn rate = churned customers / customers active at start of month.
-- =====================================================================
SELECT
    (SELECT COUNT(*) FROM crm_contracts
       WHERE contract_status = 'Cancelled'
         AND contract_end_date BETWEEN '2026-05-01' AND '2026-05-31')
    AS churned_customers,

    (SELECT COUNT(*) FROM crm_contracts
       WHERE contract_start_date < '2026-05-01'
         AND (contract_end_date IS NULL OR contract_end_date >= '2026-05-01'))
    AS active_at_start_of_month,

    1.0 *
    (SELECT COUNT(*) FROM crm_contracts
       WHERE contract_status = 'Cancelled'
         AND contract_end_date BETWEEN '2026-05-01' AND '2026-05-31')
    /
    (SELECT COUNT(*) FROM crm_contracts
       WHERE contract_start_date < '2026-05-01'
         AND (contract_end_date IS NULL OR contract_end_date >= '2026-05-01'))
    AS monthly_churn_rate;

-- =====================================================================
-- 4. CUSTOMERS RECEIVING SERVICE WITHOUT PAYMENT
-- Cross-system check: Service shows Active/delivering, but Billing
-- shows the current-month invoice as not Paid.
-- =====================================================================
SELECT s.customer_id, c.customer_name, s.service_status, b.payment_status, b.invoice_amount
FROM subscriptions_status s
JOIN crm_contracts c ON c.customer_id = s.customer_id
JOIN billing_invoices b ON b.customer_id = s.customer_id
WHERE s.month = '2026-05'
  AND s.service_status = 'Active'
  AND b.payment_status IN ('Unpaid', 'Partial');

-- =====================================================================
-- 5. CUSTOMERS PAYING WITHOUT RECEIVING SERVICE
-- Cross-system check: Billing shows the current-month invoice as Paid,
-- but Service shows the customer as Inactive/Suspended (not delivering).
-- =====================================================================
SELECT b.customer_id, c.customer_name, b.payment_status, s.service_status
FROM billing_invoices b
JOIN crm_contracts c ON c.customer_id = b.customer_id
JOIN subscriptions_status s ON s.customer_id = b.customer_id
WHERE s.month = '2026-05'
  AND b.payment_status = 'Paid'
  AND s.service_status IN ('Inactive', 'Suspended');
