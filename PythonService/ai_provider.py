import json
import urllib.request
import urllib.error
import sys

QUERY_TIMEOUT = 60

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama3-70b-8192"

GEMINI_API_VERSIONS = ["v1", "v1beta"]
GEMINI_MODELS = [
    "gemini-2.0-flash",
    "gemini-2.0-flash-exp",
    "gemini-1.5-flash",
    "gemini-1.5-pro",
    "gemini-1.0-pro",
    "gemini-pro",
]


def log(msg: str):
    print(msg, file=sys.stderr, flush=True)


def _query_groq(prompt: str, api_key: str, system_prompt: str = "", messages: list = None) -> dict:
    if messages:
        msgs = messages
    else:
        msgs = []
        if system_prompt:
            msgs.append({"role": "system", "content": system_prompt})
        msgs.append({"role": "user", "content": prompt})

    payload = {
        "model": GROQ_MODEL,
        "messages": msgs,
        "temperature": 0.3,
        "max_tokens": 1024,
    }

    req = urllib.request.Request(
        GROQ_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=QUERY_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            choices = body.get("choices", [])
            if not choices:
                return {"response": None, "error": None, "status": "error"}
            text = choices[0].get("message", {}).get("content", "")
            if not text:
                return {"response": None, "error": None, "status": "error"}
            return {"response": text, "error": None, "status": "ready"}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        log(f"Groq HTTP {e.code}: {body[:300]}")
        if e.code in (401, 403):
            return {"response": None, "error": None, "status": "invalid_key"}
        if e.code == 429:
            return {"response": None, "error": None, "status": "rate_limited"}
        if "tokens" in body.lower() or "token_limit" in body.lower():
            return {"response": None, "error": "Input too long: token limit reached", "status": "error"}
        return {"response": None, "error": body[:200], "status": "error"}
    except urllib.error.URLError as e:
        log(f"Groq URL error: {e}")
        return {"response": None, "error": f"Network: {e.reason}", "status": "error"}
    except Exception as e:
        log(f"Groq error: {e}")
        return {"response": None, "error": str(e)[:200], "status": "error"}


def _query_gemini(prompt: str, api_key: str, system_prompt: str = "", messages: list = None) -> dict:
    for api_ver in GEMINI_API_VERSIONS:
        for model in GEMINI_MODELS:
            try:
                url = f"https://generativelanguage.googleapis.com/{api_ver}/models/{model}:generateContent?key={api_key}"
                if messages:
                    contents = []
                    for m in messages:
                        if m["role"] in ("user", "assistant"):
                            contents.append({"role": m["role"], "parts": [{"text": m["content"]}]})
                    if not contents:
                        contents = [{"role": "user", "parts": [{"text": prompt}]}]
                else:
                    contents = [{"role": "user", "parts": [{"text": prompt}]}]
                payload = {
                    "contents": contents,
                    "generationConfig": {"temperature": 0.3, "maxOutputTokens": 1024},
                }
                if system_prompt:
                    payload["system_instruction"] = {"parts": [{"text": system_prompt}]}

                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=QUERY_TIMEOUT) as resp:
                    body = json.loads(resp.read().decode("utf-8"))
                    candidates = body.get("candidates", [])
                    if candidates:
                        text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                        if text:
                            log(f"Gemini OK: {api_ver}/{model}")
                            return {"response": text, "error": None, "status": "ready"}
            except urllib.error.HTTPError as e:
                body = e.read().decode("utf-8", errors="replace")
                log(f"Gemini {api_ver}/{model}: HTTP {e.code}")
                if e.code in (400, 403):
                    return {"response": None, "error": None, "status": "invalid_key"}
                if e.code == 429:
                    return {"response": None, "error": None, "status": "rate_limited"}
            except urllib.error.URLError as e:
                log(f"Gemini URL error: {e}")
                return {"response": None, "error": f"Network: {e.reason}", "status": "error"}
            except Exception as e:
                log(f"Gemini error: {e}")
                return {"response": None, "error": str(e)[:200], "status": "error"}

    return {"response": None, "error": None, "status": "error"}


def _query_github(prompt: str, api_key: str, system_prompt: str = "", messages: list = None) -> dict:
    msgs = messages if messages else []
    if not msgs:
        if system_prompt:
            msgs.append({"role": "system", "content": system_prompt})
        msgs.append({"role": "user", "content": prompt})

    payload = {
        "model": "gpt-4o-mini",
        "messages": msgs,
        "temperature": 0.3,
        "max_tokens": 1024,
    }

    req = urllib.request.Request(
        "https://models.inference.ai.azure.com/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=QUERY_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            choices = body.get("choices", [])
            if not choices:
                return {"response": None, "error": None, "status": "error"}
            text = choices[0].get("message", {}).get("content", "")
            if not text:
                return {"response": None, "error": None, "status": "error"}
            return {"response": text, "error": None, "status": "ready"}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        log(f"GitHub HTTP {e.code}: {body[:300]}")
        if e.code in (401, 403):
            return {"response": None, "error": None, "status": "invalid_key"}
        if e.code == 429:
            return {"response": None, "error": None, "status": "rate_limited"}
        if "tokens" in body.lower() or "token_limit" in body.lower():
            return {"response": None, "error": "Input too long: token limit reached", "status": "error"}
        return {"response": None, "error": body[:200], "status": "error"}
    except urllib.error.URLError as e:
        log(f"GitHub URL error: {e}")
        return {"response": None, "error": f"Network: {e.reason}", "status": "error"}
    except Exception as e:
        log(f"GitHub error: {e}")
        return {"response": None, "error": str(e)[:200], "status": "error"}


def _query_deepseek(prompt: str, api_key: str, system_prompt: str = "", messages: list = None) -> dict:
    msgs = messages if messages else []
    if not msgs:
        if system_prompt:
            msgs.append({"role": "system", "content": system_prompt})
        msgs.append({"role": "user", "content": prompt})

    payload = {
        "model": "deepseek-chat",
        "messages": msgs,
        "temperature": 0.3,
        "max_tokens": 1024,
    }

    req = urllib.request.Request(
        "https://api.deepseek.com/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=QUERY_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            choices = body.get("choices", [])
            if not choices:
                return {"response": None, "error": None, "status": "error"}
            text = choices[0].get("message", {}).get("content", "")
            if not text:
                return {"response": None, "error": None, "status": "error"}
            return {"response": text, "error": None, "status": "ready"}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        log(f"DeepSeek HTTP {e.code}: {body[:300]}")
        if e.code in (401, 403):
            return {"response": None, "error": None, "status": "invalid_key"}
        if e.code == 429:
            return {"response": None, "error": None, "status": "rate_limited"}
        if "tokens" in body.lower() or "token_limit" in body.lower():
            return {"response": None, "error": "Input too long: token limit reached", "status": "error"}
        return {"response": None, "error": body[:200], "status": "error"}
    except urllib.error.URLError as e:
        log(f"DeepSeek URL error: {e}")
        return {"response": None, "error": f"Network: {e.reason}", "status": "error"}
    except Exception as e:
        log(f"DeepSeek error: {e}")
        return {"response": None, "error": str(e)[:200], "status": "error"}


def _query_openai(prompt: str, api_key: str, system_prompt: str = "", messages: list = None) -> dict:
    msgs = messages if messages else []
    if not msgs:
        if system_prompt:
            msgs.append({"role": "system", "content": system_prompt})
        msgs.append({"role": "user", "content": prompt})

    payload = {
        "model": "gpt-3.5-turbo",
        "messages": msgs,
        "temperature": 0.3,
        "max_tokens": 1024,
    }

    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=QUERY_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            choices = body.get("choices", [])
            if not choices:
                return {"response": None, "error": None, "status": "error"}
            text = choices[0].get("message", {}).get("content", "")
            if not text:
                return {"response": None, "error": None, "status": "error"}
            return {"response": text, "error": None, "status": "ready"}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        log(f"OpenAI HTTP {e.code}: {body[:300]}")
        if e.code in (401, 403):
            return {"response": None, "error": None, "status": "invalid_key"}
        if e.code == 429:
            return {"response": None, "error": None, "status": "rate_limited"}
        if e.code == 400:
            return {"response": None, "error": None, "status": "invalid_key"}
        return {"response": None, "error": body[:200], "status": "error"}
    except urllib.error.URLError as e:
        log(f"OpenAI URL error: {e}")
        return {"response": None, "error": f"Network: {e.reason}", "status": "error"}
    except Exception as e:
        log(f"OpenAI error: {e}")
        return {"response": None, "error": str(e)[:200], "status": "error"}


def _query_openrouter(prompt: str, api_key: str, system_prompt: str = "", messages: list = None) -> dict:
    msgs = messages if messages else []
    if not msgs:
        if system_prompt:
            msgs.append({"role": "system", "content": system_prompt})
        msgs.append({"role": "user", "content": prompt})

    payload = {
        "model": "google/gemini-2.0-flash-exp:free",
        "messages": msgs,
        "temperature": 0.3,
        "max_tokens": 1024,
        "extra_headers": {"HTTP-Referer": "https://github.com/K-boop-design/code-visualizer", "X-Title": "Code Visualizer"},
    }

    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=QUERY_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            choices = body.get("choices", [])
            if not choices:
                return {"response": None, "error": None, "status": "error"}
            text = choices[0].get("message", {}).get("content", "")
            if not text:
                return {"response": None, "error": None, "status": "error"}
            return {"response": text, "error": None, "status": "ready"}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        log(f"OpenRouter HTTP {e.code}: {body[:300]}")
        if e.code in (401, 403):
            return {"response": None, "error": None, "status": "invalid_key"}
        if e.code == 429:
            return {"response": None, "error": None, "status": "rate_limited"}
        if "tokens" in body.lower() or "token_limit" in body.lower():
            return {"response": None, "error": "Input too long: token limit reached", "status": "error"}
        return {"response": None, "error": body[:200], "status": "error"}
    except urllib.error.URLError as e:
        log(f"OpenRouter URL error: {e}")
        return {"response": None, "error": f"Network: {e.reason}", "status": "error"}
    except Exception as e:
        log(f"OpenRouter error: {e}")
        return {"response": None, "error": str(e)[:200], "status": "error"}


def query_ai(prompt: str, api_key: str, provider: str = "openai",
             context: str = "", system_prompt: str = "", messages: list = None) -> dict:
    if not api_key:
        return {"response": None, "error": None, "status": "no_key"}

    if messages:
        full_prompt = prompt
        msgs = messages
    else:
        full_prompt = prompt
        if context:
            full_prompt = f"{context}\n\n{prompt}"
        msgs = None

    if provider == "gemini":
        return _query_gemini(full_prompt, api_key, system_prompt, messages=msgs)
    elif provider == "groq":
        return _query_groq(full_prompt, api_key, system_prompt, messages=msgs)
    elif provider == "deepseek":
        return _query_deepseek(full_prompt, api_key, system_prompt, messages=msgs)
    elif provider == "github":
        return _query_github(full_prompt, api_key, system_prompt, messages=msgs)
    elif provider == "openrouter":
        return _query_openrouter(full_prompt, api_key, system_prompt, messages=msgs)
    else:
        return _query_openai(full_prompt, api_key, system_prompt, messages=msgs)
