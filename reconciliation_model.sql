-- Revenue Reconciliation Model
-- Reporting period: January 2026 ("current month" — latest fully-populated month in the data)
-- Source tables loaded from data/crm_contracts.csv, data/billing_invoices.csv, data/subscriptions_status.csv
--
-- Actual source schemas:
--   crm_contracts:        contract_status = 'Won' (currently active contract) | 'Cancelled' (churned); mrr = monthly recurring revenue
--   billing_invoices:     payment_status = 'Paid' | 'Partial' | 'Unpaid'; amount_paid = actual cash received; write_off_flag = 'Yes'/'No'
--   subscriptions_status: service_status = 'Active' | 'Paused' | 'Cancelled'; cancellation_date = date service actually stopped

-- =====================================================================
-- 1. CURRENT ARR
-- Trusted source: CRM (contractual commitment).
-- Only contracts currently in force (status = 'Won') count — the signed,
-- uncancelled commitment is the cleanest definition of recurring revenue,
-- independent of billing lag or service-activation lag.
-- =====================================================================
SELECT
    SUM(mrr) * 12 AS current_arr
FROM crm_contracts
WHERE contract_status = 'Won';

-- =====================================================================
-- 2. CASH COLLECTED DURING CURRENT MONTH (January 2026)
-- Trusted source: Billing — the only system that records money actually
-- received. We sum amount_paid (the real cash figure, not invoice_amount)
-- for invoices with a payment_date in the reporting month, including
-- partials, since amount_paid already reflects exactly how much cash
-- came in. Written-off invoices are excluded — no cash is expected.
-- =====================================================================
SELECT
    SUM(amount_paid) AS cash_collected_jan_2026
FROM billing_invoices
WHERE payment_date BETWEEN '2026-01-01' AND '2026-01-31'
  AND write_off_flag = 'No';

-- Visibility: invoices still fully outstanding for the period (collections follow-up list)
SELECT customer_id, invoice_id, total_amount, payment_status
FROM billing_invoices
WHERE payment_status = 'Unpaid'
  AND invoice_date BETWEEN '2026-01-01' AND '2026-01-31'
  AND write_off_flag = 'No';

-- =====================================================================
-- 3. MONTHLY CHURN
-- Trusted source: CRM confirms the contract was actually terminated
-- (contract_status = 'Cancelled'); Service supplies the missing
-- cancellation DATE (CRM has no such field). A customer counts as
-- churned this month only when both systems agree — contract cancelled
-- AND service cancellation_date falls in the reporting month. This is
-- exactly how the conflict between "is it cancelled" (CRM) and
-- "when did it stop" (Service) gets resolved.
-- =====================================================================
SELECT
    (SELECT COUNT(*)
       FROM crm_contracts c
       JOIN subscriptions_status s ON s.customer_id = c.customer_id
       WHERE c.contract_status = 'Cancelled'
         AND s.service_status = 'Cancelled'
         AND s.cancellation_date BETWEEN '2026-01-01' AND '2026-01-31')
    AS churned_customers,

    (SELECT COUNT(*) FROM crm_contracts WHERE contract_status IN ('Won', 'Cancelled'))
    AS customers_under_contract_start_of_month,

    1.0 *
    (SELECT COUNT(*)
       FROM crm_contracts c
       JOIN subscriptions_status s ON s.customer_id = c.customer_id
       WHERE c.contract_status = 'Cancelled'
         AND s.service_status = 'Cancelled'
         AND s.cancellation_date BETWEEN '2026-01-01' AND '2026-01-31')
    /
    (SELECT COUNT(*) FROM crm_contracts WHERE contract_status IN ('Won', 'Cancelled'))
    AS monthly_churn_rate;

-- =====================================================================
-- 4. CUSTOMERS RECEIVING SERVICE WITHOUT PAYMENT
-- Cross-system check: Service shows the customer as currently 'Active'
-- (still being delivered to), but their latest invoice for the
-- reporting month is Unpaid or Partial in Billing.
-- =====================================================================
SELECT s.customer_id, s.service_status, b.invoice_id, b.payment_status, b.total_amount, b.amount_paid
FROM subscriptions_status s
JOIN billing_invoices b ON b.customer_id = s.customer_id
WHERE s.service_status = 'Active'
  AND b.invoice_date BETWEEN '2026-01-01' AND '2026-01-31'
  AND b.payment_status IN ('Unpaid', 'Partial')
  AND b.write_off_flag = 'No';

-- =====================================================================
-- 5. CUSTOMERS PAYING WITHOUT RECEIVING SERVICE
-- Cross-system check: Billing shows a fully 'Paid' invoice in the
-- reporting month, but Service shows the customer as 'Paused' or
-- 'Cancelled' — i.e. money came in for a service that isn't being
-- delivered right now.
-- =====================================================================
SELECT b.customer_id, b.invoice_id, b.payment_status, b.payment_date, s.service_status, s.last_service_date
FROM billing_invoices b
JOIN subscriptions_status s ON s.customer_id = b.customer_id
WHERE b.payment_status = 'Paid'
  AND b.payment_date BETWEEN '2026-01-01' AND '2026-01-31'
  AND s.service_status IN ('Paused', 'Cancelled');
