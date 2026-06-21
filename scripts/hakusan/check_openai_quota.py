#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request


def main():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: OPENAI_API_KEY is not set.", file=sys.stderr)
        return 2

    model = os.getenv("LLM_MODEL") or os.getenv("SG_NAV_LLM_MODEL") or "gpt-4o"
    base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
    payload = {
        "model": model,
        "input": [{
            "role": "user",
            "content": [{"type": "input_text", "text": "Reply with OK."}],
        }],
        "max_output_tokens": 16,
    }
    request = urllib.request.Request(
        f"{base_url}/responses",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read().decode("utf-8"))
        output_text = data.get("output_text", "")
        print(f"OK: OpenAI Responses API is reachable for model={model}. output={output_text!r}")
        return 0
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        print(f"ERROR: OpenAI API HTTP {error.code}: {body}", file=sys.stderr)
        return 1
    except urllib.error.URLError as error:
        print(f"ERROR: OpenAI connection error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
