#!/usr/bin/env python3
"""
validate-permissions.py — Audit Chrome extension permissions for over-broadness.

Usage:
  validate-permissions.py path/to/manifest.json

Exit code 1 if any CRITICAL issues; 0 otherwise.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

# Chrome match-pattern grammar (developer.chrome.com/docs/extensions/develop/concepts/match-patterns).
# scheme://host/path, where scheme is * | http | https | file | ftp | urn,
# host is * | *.<labels> | <labels> (a leading "*." or a bare "*" only), and the
# path is required and begins with "/". `<all_urls>` is the documented special case.
_MATCH_SCHEME = r"(?:\*|https?|file|ftp|urn)"
_MATCH_HOST = r"(?:\*|(?:\*\.)?[^/*]+)"
_MATCH_PATTERN_RE = re.compile(rf"^{_MATCH_SCHEME}://{_MATCH_HOST}/.*$")
_FILE_PATTERN_RE = re.compile(r"^file:///.*$")  # file:// has an empty host


def is_valid_match_pattern(pattern: str) -> bool:
    """Heuristic check that a host/match pattern is well-formed. Catches obvious
    garbage (e.g. '**invalid**') without claiming to be a complete Chrome parser."""
    if not isinstance(pattern, str) or not pattern:
        return False
    if pattern == "<all_urls>":
        return True
    if pattern.startswith("file://"):
        return bool(_FILE_PATTERN_RE.match(pattern))
    return bool(_MATCH_PATTERN_RE.match(pattern))

# Permissions that trigger Chrome Web Store manual review and broad user warnings.
HIGH_RISK_PERMISSIONS = {
    "<all_urls>",
    "cookies",
    "debugger",
    "history",
    "management",
    "nativeMessaging",
    "privacy",
    "proxy",
    "tabs",  # grants full tab metadata access; activeTab is usually enough
    "webRequest",
    "webRequestBlocking",  # MV2 only
}

# Permissions deprecated or moved to declarativeNetRequest in MV3
DEPRECATED_PERMISSIONS = {
    "webRequestBlocking": "Use declarativeNetRequest in MV3.",
}


def emit(level: str, key: str, message: str) -> None:
    print(f"{level:<8}  {key}  {message}")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate-permissions.py path/to/manifest.json", file=sys.stderr)
        return 2

    try:
        with open(sys.argv[1]) as f:
            m = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"CRITICAL  <file>  {e}", file=sys.stderr)
        return 2

    critical = 0
    perms = m.get("permissions", []) or []
    host_perms = m.get("host_permissions", []) or []
    optional_host = m.get("optional_host_permissions", []) or []
    optional_perms = m.get("optional_permissions", []) or []

    # Deprecated
    for p in perms:
        if p in DEPRECATED_PERMISSIONS:
            emit("CRITICAL", f"permissions[{p!r}]", DEPRECATED_PERMISSIONS[p])
            critical += 1

    # Broad host permissions
    if "<all_urls>" in host_perms:
        emit("WARNING", "host_permissions",
             "<all_urls> is the broadest possible host permission. Considered manual-review "
             "trigger by Chrome Web Store. Justify in single-purpose statement or narrow.")

    for h in host_perms:
        if h in ("*://*/*", "<all_urls>", "https://*/*", "http://*/*"):
            emit("WARNING", "host_permissions",
                 f"{h!r} matches all sites of a scheme. Narrow if possible.")

    # Malformed host/match patterns — Chrome silently drops these at load time,
    # so a typo means the permission you think you have simply isn't granted.
    for label, patterns in (("host_permissions", host_perms),
                            ("optional_host_permissions", optional_host)):
        for h in patterns:
            if not is_valid_match_pattern(h):
                emit("WARNING", label,
                     f"{h!r} is not a valid match pattern (expected scheme://host/path "
                     "or <all_urls>). Chrome will ignore it at load time.")

    # activeTab vs tabs
    has_active = "activeTab" in perms
    has_tabs = "tabs" in perms
    if has_tabs and not has_active:
        emit("INFO", "permissions",
             "'tabs' grants metadata for all tabs (title, URL). 'activeTab' alone "
             "is enough for user-invoked actions and shows no broad warning.")
    if has_tabs and has_active:
        emit("INFO", "permissions",
             "both 'tabs' and 'activeTab' present. Remove 'tabs' if only acting on user invocation.")

    # Optional permissions
    static_perms_set = set(perms) | set(host_perms)
    if "<all_urls>" in host_perms and "<all_urls>" not in optional_host:
        emit("INFO", "optional_host_permissions",
             "consider moving '<all_urls>' to optional_host_permissions and requesting "
             "at runtime via chrome.permissions.request when the user enables the feature.")

    # High-risk audit
    for p in perms:
        if p in HIGH_RISK_PERMISSIONS:
            emit("WARNING", f"permissions[{p!r}]",
                 "is a high-risk permission. Justify in CWS listing.")

    # Missing optional_permissions for non-core
    non_core_hints = {
        "downloads": "downloads is non-core for most extensions; consider optional_permissions.",
        "notifications": "notifications is often optional; consider asking on first use.",
        "clipboardWrite": "clipboardWrite can be optional; request on the action that needs it.",
        "clipboardRead": "clipboardRead is sensitive; strongly prefer optional_permissions.",
    }
    for p, hint in non_core_hints.items():
        if p in perms and p not in optional_perms:
            emit("INFO", f"permissions[{p!r}]", hint)

    # Content scripts with <all_urls> matches
    cs_list = m.get("content_scripts", [])
    for i, cs in enumerate(cs_list):
        matches = cs.get("matches", []) or []
        if "<all_urls>" in matches or "*://*/*" in matches:
            emit("WARNING", f"content_scripts[{i}].matches",
                 f"{matches!r} runs on every page. Narrow if possible.")
        for mp in matches:
            if not is_valid_match_pattern(mp):
                emit("WARNING", f"content_scripts[{i}].matches",
                     f"{mp!r} is not a valid match pattern; Chrome will reject the "
                     "content script registration.")

    print()
    print(f"── Permissions audit: critical={critical} ──")
    return 1 if critical > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
