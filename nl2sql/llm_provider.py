"""Optional LLM provider stub for future NL2SQL backends.

Default eval path never calls this. When NL2SQL_PROVIDER is set without a key,
raises a clear skipped_no_key error so callers can skip without failing.
"""

from __future__ import annotations

import os
from typing import Optional


class SkippedNoKey(RuntimeError):
    """Raised when an LLM provider is requested but no API key is configured."""

    code = "skipped_no_key"


def get_provider():
    """Return a provider instance if configured; otherwise raise SkippedNoKey.

    Env:
      NL2SQL_PROVIDER — e.g. openai, anthropic (stub only; not implemented)
      OPENAI_API_KEY / ANTHROPIC_API_KEY — required when provider is set
    """
    provider = (os.environ.get("NL2SQL_PROVIDER") or "").strip().lower()
    if not provider:
        raise SkippedNoKey(
            "skipped_no_key: NL2SQL_PROVIDER unset; using deterministic mapper"
        )

    if provider in ("openai", "gpt"):
        if not os.environ.get("OPENAI_API_KEY"):
            raise SkippedNoKey(
                "skipped_no_key: NL2SQL_PROVIDER=openai but OPENAI_API_KEY is missing"
            )
        raise NotImplementedError(
            f"provider {provider!r} stub only; set no NL2SQL_PROVIDER to use mapper"
        )

    if provider in ("anthropic", "claude"):
        if not os.environ.get("ANTHROPIC_API_KEY"):
            raise SkippedNoKey(
                "skipped_no_key: NL2SQL_PROVIDER=anthropic but ANTHROPIC_API_KEY is missing"
            )
        raise NotImplementedError(
            f"provider {provider!r} stub only; set no NL2SQL_PROVIDER to use mapper"
        )

    raise SkippedNoKey(
        f"skipped_no_key: unknown NL2SQL_PROVIDER={provider!r}; no API key path used"
    )


def generate_sql(question: str, domain: Optional[str] = None) -> str:
    """Stub: would call an LLM. Always skipped without a key / implementation."""
    _ = (question, domain, get_provider())
    raise NotImplementedError("LLM generate_sql is not implemented")
