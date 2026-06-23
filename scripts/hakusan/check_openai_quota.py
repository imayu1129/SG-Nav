#!/usr/bin/env python3
import json
import os
import sys
import time
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
    retries = int(os.getenv("OPENAI_CHECK_RETRIES", "5"))
    retry_codes = {408, 409, 429, 500, 502, 503, 504}
    last_error = None

    for attempt in range(1, retries + 1):
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
            last_error = f"OpenAI API HTTP {error.code}: {body}"
            if error.code not in retry_codes:
                break
        except urllib.error.URLError as error:
            last_error = f"OpenAI connection error: {error}"

        if attempt < retries:
            wait_seconds = min(2 ** (attempt - 1), 30)
            print(
                f"Retrying OpenAI API check after transient error "
                f"({attempt}/{retries}): {last_error}",
                file=sys.stderr,
            )
            time.sleep(wait_seconds)

    print(f"ERROR: {last_error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
