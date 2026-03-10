#!/usr/bin/env python3
"""Upload a file to Tencent COS via Signature v5."""

from __future__ import annotations

import argparse
import hashlib
import hmac
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


def _percent_encode(value: str) -> str:
    return urllib.parse.quote(value, safe="-_.~")


def _canonical_kv(items: dict[str, str]) -> tuple[str, str]:
    normalized = {
        _percent_encode(str(key).lower()): _percent_encode(str(value).strip())
        for key, value in items.items()
    }
    ordered = sorted(normalized.items())
    names = ";".join(key for key, _ in ordered)
    content = "&".join(f"{key}={value}" for key, value in ordered)
    return names, content


def _build_auth(
    *,
    secret_id: str,
    secret_key: str,
    method: str,
    path: str,
    query: dict[str, str],
    headers: dict[str, str],
    expires: int = 1800,
) -> str:
    start = int(time.time()) - 5
    end = start + expires
    sign_time = f"{start};{end}"

    header_list, http_headers = _canonical_kv(headers)
    param_list, http_parameters = _canonical_kv(query)
    format_string = (
        f"{method.lower()}\n"
        f"{path}\n"
        f"{http_parameters}\n"
        f"{http_headers}\n"
    )
    hashed_format = hashlib.sha1(format_string.encode("utf-8")).hexdigest()
    string_to_sign = f"sha1\n{sign_time}\n{hashed_format}\n"
    sign_key = hmac.new(
        secret_key.encode("utf-8"),
        sign_time.encode("utf-8"),
        hashlib.sha1,
    ).hexdigest()
    signature = hmac.new(
        sign_key.encode("utf-8"),
        string_to_sign.encode("utf-8"),
        hashlib.sha1,
    ).hexdigest()
    return (
        f"q-sign-algorithm=sha1&q-ak={secret_id}&q-sign-time={sign_time}"
        f"&q-key-time={sign_time}&q-header-list={header_list}"
        f"&q-url-param-list={param_list}&q-signature={signature}"
    )


def _request(
    *,
    secret_id: str,
    secret_key: str,
    bucket: str,
    region: str,
    method: str,
    object_key: str,
    body: bytes | None = None,
    timeout: int = 300,
) -> tuple[int, bytes]:
    host = f"{bucket}.cos.{region}.myqcloud.com"
    path = "/" + object_key.lstrip("/")
    url = f"https://{host}{path}"
    headers = {"Host": host}
    authorization = _build_auth(
        secret_id=secret_id,
        secret_key=secret_key,
        method=method,
        path=path,
        query={},
        headers=headers,
    )

    request = urllib.request.Request(url=url, method=method, data=body)
    request.add_header("Host", host)
    request.add_header("Authorization", authorization)
    if body is not None:
        request.add_header("Content-Length", str(len(body)))

    # Force direct connection; do not inherit proxy env vars.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(request, timeout=timeout) as response:
        return response.status, response.read()


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Upload one file to Tencent COS")
    parser.add_argument("--secret-id", required=True)
    parser.add_argument("--secret-key", required=True)
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--file", required=True, dest="local_file")
    parser.add_argument("--object-key", required=True)
    parser.add_argument("--timeout", type=int, default=300)
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    if not os.path.isfile(args.local_file):
        print(f"Local file not found: {args.local_file}", file=sys.stderr)
        return 2

    with open(args.local_file, "rb") as file:
        payload = file.read()

    try:
        put_status, _ = _request(
            secret_id=args.secret_id,
            secret_key=args.secret_key,
            bucket=args.bucket,
            region=args.region,
            method="PUT",
            object_key=args.object_key,
            body=payload,
            timeout=args.timeout,
        )
        head_status, _ = _request(
            secret_id=args.secret_id,
            secret_key=args.secret_key,
            bucket=args.bucket,
            region=args.region,
            method="HEAD",
            object_key=args.object_key,
            timeout=min(args.timeout, 60),
        )
    except urllib.error.HTTPError as error:
        error_body = error.read().decode("utf-8", errors="replace")
        print(f"HTTP error: {error.code}", file=sys.stderr)
        print(error_body[:1000], file=sys.stderr)
        return 3
    except Exception as error:  # pragma: no cover - CI diagnostics
        print(f"Upload failed: {error}", file=sys.stderr)
        return 4

    print(f"PUT ok: HTTP {put_status}")
    print(f"HEAD ok: HTTP {head_status}")
    print(f"cos://{args.bucket}/{args.object_key}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
