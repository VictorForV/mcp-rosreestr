#!/usr/bin/env python3
"""Small command-line client for an mcp-rosreestr Streamable HTTP endpoint."""

from __future__ import annotations

import argparse
import asyncio
import json
from typing import Any

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client


def _result_payload(result: Any) -> Any:
    if result.structuredContent is not None:
        return result.structuredContent

    texts = [item.text for item in result.content if getattr(item, "type", None) == "text"]
    if len(texts) == 1:
        try:
            return json.loads(texts[0])
        except json.JSONDecodeError:
            return texts[0]
    return texts


async def _run(url: str, tool: str, cadastral_numbers: list[str]) -> int:
    failed = False
    async with streamablehttp_client(url) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            for cadastral_number in cadastral_numbers:
                try:
                    result = await session.call_tool(
                        tool,
                        {"cadastral_number": cadastral_number},
                    )
                    payload = {
                        "cadastral_number": cadastral_number,
                        "ok": not bool(result.isError),
                        "result": _result_payload(result),
                    }
                    failed = failed or bool(result.isError)
                except Exception as exc:
                    failed = True
                    payload = {
                        "cadastral_number": cadastral_number,
                        "ok": False,
                        "error": f"{type(exc).__name__}: {exc}",
                    }
                print(json.dumps(payload, ensure_ascii=False, indent=2, default=str))
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cadastral_numbers", nargs="+", help="One or more cadastral numbers")
    parser.add_argument(
        "--url",
        default="http://127.0.0.1:8000/mcp",
        help="Streamable HTTP MCP endpoint",
    )
    parser.add_argument(
        "--tool",
        choices=("lookup_by_cadastral", "get_cadastral_value"),
        default="lookup_by_cadastral",
    )
    args = parser.parse_args()
    return asyncio.run(_run(args.url, args.tool, args.cadastral_numbers))


if __name__ == "__main__":
    raise SystemExit(main())
