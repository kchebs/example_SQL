"""Deterministic keyword/template mapper: natural language → SQL.

No API keys. Templates target Docker-seeded schemas:
  - healthcare: accounts, telehealth_reg
  - ecommerce: fact_order, fact_order_line, fact_refund, dims
  - sports: Person, Sport, History
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class MappedQuery:
    sql: str
    domain: str
    template_id: str


# Ordered rules: first matching keyword set wins.
_RULES: list[tuple[str, frozenset[str], str, str]] = [
    # (domain, keywords, template_id, sql)
    (
        "healthcare",
        frozenset({"eligible", "registration", "rate"}),
        "hc_eligible_reg_rate",
        """
SELECT
  COUNT(tr.account_id)::float / NULLIF(COUNT(*), 0) AS eligible_reg_rate
FROM accounts a
LEFT JOIN telehealth_reg tr ON tr.account_id = a.account_id
WHERE a.telehealth_eligible = TRUE
  AND a.account_created_date < DATE '2019-01-01'
""".strip(),
    ),
    (
        "healthcare",
        frozenset({"median", "latency"}),
        "hc_median_latency",
        """
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (
  ORDER BY (tr.telehealth_reg_date - a.account_created_date)
) AS median_latency_days
FROM accounts a
JOIN telehealth_reg tr ON tr.account_id = a.account_id
WHERE a.account_created_date < DATE '2019-01-01'
""".strip(),
    ),
    (
        "healthcare",
        frozenset({"accounts", "prior", "year"}),
        "hc_prior_year_accounts",
        """
SELECT COUNT(*) AS prior_year_accounts
FROM accounts
WHERE account_created_date >= DATE '2018-01-01'
  AND account_created_date < DATE '2019-01-01'
""".strip(),
    ),
    (
        "healthcare",
        frozenset({"telehealth", "eligible"}),
        "hc_eligible_count",
        """
SELECT COUNT(*) AS eligible_accounts
FROM accounts
WHERE telehealth_eligible = TRUE
""".strip(),
    ),
    (
        "ecommerce",
        frozenset({"refund", "cash"}),
        "ecom_cash_refund_total",
        """
SELECT SUM(r.total_refund) AS cash_refund_total
FROM fact_refund r
JOIN dim_refund_type rt ON rt.refund_type_id = r.refund_type_id
WHERE rt.refund_type_label = 'cash'
""".strip(),
    ),
    (
        "ecommerce",
        frozenset({"order", "line", "meal"}),
        "ecom_meal_kit_lines",
        """
SELECT COUNT(*) AS meal_kit_lines
FROM fact_order_line ol
JOIN fact_order o ON o.order_id = ol.order_id
JOIN dim_product_type pt ON pt.product_type_id = ol.product_type_id
WHERE pt.product_type_label ILIKE '%meal%'
  AND o.datetime_shipped::date = DATE '2022-06-15'
""".strip(),
    ),
    (
        "ecommerce",
        frozenset({"monthly", "order"}),
        "ecom_monthly_orders",
        """
SELECT DATE_TRUNC('month', datetime_shipped) AS month,
       COUNT(*) AS order_count
FROM fact_order
GROUP BY 1
ORDER BY 1
""".strip(),
    ),
    (
        "ecommerce",
        frozenset({"shipped", "orders"}),
        "ecom_shipped_count",
        """
SELECT COUNT(*) AS shipped_orders
FROM fact_order
WHERE statuscode = 1
""".strip(),
    ),
    (
        "sports",
        frozenset({"multi", "sport"}),
        "sports_multi_sport",
        """
SELECT p.PersonID, p.FirstName, p.LastName, COUNT(DISTINCT h.SportID) AS sport_count
FROM Person p
JOIN History h ON h.PersonID = p.PersonID
GROUP BY p.PersonID, p.FirstName, p.LastName
HAVING COUNT(DISTINCT h.SportID) > 1
ORDER BY sport_count DESC
""".strip(),
    ),
    (
        "sports",
        frozenset({"average", "score"}),
        "sports_avg_score",
        """
SELECT s.SportName, AVG(h.Score)::float AS avg_score
FROM History h
JOIN Sport s ON s.SportID = h.SportID
GROUP BY s.SportName
ORDER BY avg_score DESC
""".strip(),
    ),
    (
        "sports",
        frozenset({"how many", "people"}),
        "sports_person_count",
        """
SELECT COUNT(*) AS person_count
FROM Person
""".strip(),
    ),
    (
        "sports",
        frozenset({"list", "sports"}),
        "sports_list",
        """
SELECT SportID, SportType, SportName
FROM Sport
ORDER BY SportID
""".strip(),
    ),
]


def map_question_to_sql(question: str, domain: Optional[str] = None) -> MappedQuery:
    """Map a natural-language question to SQL via keyword templates.

    Raises ValueError if no template matches.
    """
    q = (question or "").strip().lower()
    if not q:
        raise ValueError("empty question")

    for rule_domain, keywords, template_id, sql in _RULES:
        if domain is not None and rule_domain != domain:
            continue
        if all(k in q for k in keywords):
            return MappedQuery(sql=sql, domain=rule_domain, template_id=template_id)

    raise ValueError(f"no template matched for question: {question!r}")
