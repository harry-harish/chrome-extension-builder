#!/usr/bin/env python3
"""
validate-manifest.py — Validate a Chrome extension manifest.json against
Manifest V3 schema and 2026 best practices.

Usage:
  validate-manifest.py path/to/manifest.json

Exit codes:
  0 — clean (no critical, may have warnings)
  1 — critical issues found (blocks Chrome Web Store submission)
  2 — manifest unreadable or invalid JSON

Output format: structured findings to stdout, one per line:
  CRITICAL  <path>:<key>  <message>
  WARNING   <path>:<key>  <message>
  INFO      <path>:<key>  <message>
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any


def emit(level: str, path: str, key: str, message: str) -> None:
    print(f"{level:<8}  {path}:{key}  {message}")


def is_mv2_field(key: str) -> bool:
    return key in {
        "browser_action",
        "page_action",
        "background_page",
        "automation",
    }


def validate(manifest_path: Path) -> int:
    try:
        with manifest_path.open() as f:
            m: dict[str, Any] = json.load(f)
    except FileNotFoundError:
        emit("CRITICAL", str(manifest_path), "<file>", "manifest.json not found")
        return 2
    except json.JSONDecodeError as e:
        emit("CRITICAL", str(manifest_path), f"line {e.lineno}", f"invalid JSON: {e.msg}")
        return 2

    critical = 0
    warnings = 0
    p = str(manifest_path)

    # ── Manifest version ────────────────────────────────────────────
    mv = m.get("manifest_version")
    if mv != 3:
        emit("CRITICAL", p, "manifest_version",
             f"is {mv!r}. MV2 was removed from Chrome 139 on 2025-07-24. "
             "Migrate to MV3 with /chrome-ext:migrate-mv2.")
        critical += 1

    # ── Required fields ─────────────────────────────────────────────
    for field in ("name", "version"):
        if not m.get(field):
            emit("CRITICAL", p, field, f"required field {field!r} is missing or empty.")
            critical += 1

    name = m.get("name", "")
    # Allow __MSG_*__ placeholders
    if name and not name.startswith("__MSG_") and len(name) > 45:
        emit("CRITICAL", p, "name", f"length {len(name)} exceeds CWS limit of 45 chars.")
        critical += 1

    desc = m.get("description", "")
    if desc and not desc.startswith("__MSG_") and len(desc) > 132:
        emit("CRITICAL", p, "description",
             f"length {len(desc)} exceeds CWS limit of 132 chars.")
        critical += 1

    # ── MV2-only fields ─────────────────────────────────────────────
    for k in list(m.keys()):
        if is_mv2_field(k):
            replacement = {
                "browser_action": "action",
                "page_action": "action (with conditional display via chrome.action.disable/enable)",
                "background_page": "background.service_worker",
                "automation": "removed in MV3",
            }.get(k, "MV3 equivalent")
            emit("CRITICAL", p, k, f"is an MV2-only field. Use {replacement}.")
            critical += 1

    # ── Background ──────────────────────────────────────────────────
    bg = m.get("background")
    if bg is not None:
        if "scripts" in bg:
            emit("CRITICAL", p, "background.scripts",
                 "is MV2-only. Use background.service_worker with a single entry file.")
            critical += 1
        if bg.get("persistent") is True:
            emit("CRITICAL", p, "background.persistent",
                 "persistent: true is illegal in MV3 (service workers are ephemeral).")
            critical += 1
        if "service_worker" not in bg and "scripts" not in bg:
            emit("WARNING", p, "background",
                 "background is declared but has no service_worker.")
            warnings += 1

    # ── CSP ─────────────────────────────────────────────────────────
    csp = m.get("content_security_policy")
    if isinstance(csp, str):
        emit("CRITICAL", p, "content_security_policy",
             "string form is MV2-only. Use an object with extension_pages and sandbox keys.")
        critical += 1
    elif isinstance(csp, dict):
        ext = csp.get("extension_pages", "")
        if "unsafe-eval" in ext:
            emit("CRITICAL", p, "content_security_policy.extension_pages",
                 "contains 'unsafe-eval'. Forbidden in MV3 extension pages.")
            critical += 1
        if "unsafe-inline" in ext:
            emit("CRITICAL", p, "content_security_policy.extension_pages",
                 "contains 'unsafe-inline'. Strongly discouraged; refactor inline scripts.")
            critical += 1
        # Look for remote script-src. Strip trailing CSP punctuation (; , ')
        # so "https://evil.example.com;" reports as the URL alone.
        for token in ext.split():
            cleaned = token.rstrip(";,'\"")
            if cleaned.startswith(("http://", "https://")):
                emit("CRITICAL", p, "content_security_policy.extension_pages",
                     f"contains remote source {cleaned!r}. MV3 forbids remote code.")
                critical += 1

    # ── web_accessible_resources ───────────────────────────────────
    war = m.get("web_accessible_resources")
    if isinstance(war, list):
        for i, entry in enumerate(war):
            if isinstance(entry, str):
                emit("CRITICAL", p, f"web_accessible_resources[{i}]",
                     "is a string (MV2 form). Use {resources: [...], matches: [...]}.")
                critical += 1
            elif isinstance(entry, dict):
                if "resources" not in entry:
                    emit("CRITICAL", p, f"web_accessible_resources[{i}].resources",
                         "missing 'resources' key.")
                    critical += 1
                if "matches" not in entry and "extension_ids" not in entry:
                    emit("CRITICAL", p, f"web_accessible_resources[{i}].matches",
                         "missing 'matches' or 'extension_ids' (MV3 requires one).")
                    critical += 1

    # ── Permissions ─────────────────────────────────────────────────
    perms = m.get("permissions", []) or []
    host_perms = m.get("host_permissions", []) or []
    optional_host = m.get("optional_host_permissions", []) or []

    if "<all_urls>" in host_perms:
        emit("WARNING", p, "host_permissions",
             "includes '<all_urls>'. Triggers CWS manual review and the broad "
             "'read all your data on all websites' warning. Consider chrome.activeTab "
             "or moving to optional_host_permissions.")
        warnings += 1

    # MV2-era 'webRequestBlocking' is no longer available without enterprise enrollment
    if "webRequestBlocking" in perms:
        emit("CRITICAL", p, "permissions",
             "'webRequestBlocking' is unavailable in MV3 (enterprise-only). "
             "Use 'declarativeNetRequest' instead.")
        critical += 1

    if "tabs" in perms and "activeTab" in perms:
        emit("INFO", p, "permissions",
             "both 'tabs' and 'activeTab' present. 'activeTab' alone is sufficient "
             "for user-invoked actions; 'tabs' adds the broad warning.")

    # ── Icons ───────────────────────────────────────────────────────
    icons = m.get("icons", {})
    expected_icons = {"16", "32", "48", "128"}
    missing = expected_icons - set(icons.keys())
    if missing:
        emit("WARNING", p, "icons",
             f"missing standard sizes: {', '.join(sorted(missing))}. "
             "CWS requires 128; 48, 32, 16 are strongly recommended.")
        warnings += 1

    # ── default_locale + _locales/ ─────────────────────────────────
    default_locale = m.get("default_locale")
    if default_locale:
        ext_dir = manifest_path.parent
        locales_dir = ext_dir / "_locales"
        if not locales_dir.exists():
            emit("WARNING", p, "default_locale",
                 f"is set to {default_locale!r} but _locales/ directory not found.")
            warnings += 1
        else:
            locale_messages = locales_dir / default_locale / "messages.json"
            if not locale_messages.exists():
                emit("WARNING", p, "default_locale",
                     f"_locales/{default_locale}/messages.json not found.")
                warnings += 1

    # ── File-existence checks for every surface that references a file ──
    # Centralized helper so we don't drift between surface types.
    def check_file(rel_path: str, manifest_key: str) -> None:
        nonlocal critical
        if not rel_path:
            return
        # Manifest paths are forward-slash; allow either form. Strip any leading
        # slash that some authors mistakenly add (manifest paths are always
        # relative to the extension root).
        normalized = rel_path.lstrip("/")
        target = manifest_path.parent / normalized
        if not target.exists():
            emit("CRITICAL", p, manifest_key,
                 f"file {rel_path!r} does not exist on disk.")
            critical += 1

    # action.default_popup
    action = m.get("action")
    if isinstance(action, dict):
        check_file(action.get("default_popup", ""), "action.default_popup")
        # action.default_icon may be a dict {16: "...", 48: "..."} or a string
        di = action.get("default_icon")
        if isinstance(di, dict):
            for size, path in di.items():
                if isinstance(path, str):
                    check_file(path, f"action.default_icon.{size}")
        elif isinstance(di, str):
            check_file(di, "action.default_icon")

    # background.service_worker
    if isinstance(bg, dict):
        check_file(bg.get("service_worker", ""), "background.service_worker")

    # options_page (top-level form)
    check_file(m.get("options_page", ""), "options_page")

    # options_ui.page (object form; preferred for embedded options)
    opt_ui = m.get("options_ui")
    if isinstance(opt_ui, dict):
        check_file(opt_ui.get("page", ""), "options_ui.page")

    # side_panel.default_path (requires sidePanel permission, but the file
    # must still exist regardless)
    sp = m.get("side_panel")
    if isinstance(sp, dict):
        check_file(sp.get("default_path", ""), "side_panel.default_path")

    # devtools_page (top-level)
    check_file(m.get("devtools_page", ""), "devtools_page")

    # chrome_url_overrides.{newtab, bookmarks, history}
    overrides = m.get("chrome_url_overrides")
    if isinstance(overrides, dict):
        for key in ("newtab", "bookmarks", "history"):
            check_file(overrides.get(key, ""), f"chrome_url_overrides.{key}")

    # icons.{16,32,48,128} — top-level (separate from action.default_icon)
    top_icons = m.get("icons")
    if isinstance(top_icons, dict):
        for size, path in top_icons.items():
            if isinstance(path, str):
                check_file(path, f"icons.{size}")

    # ── Content scripts file existence ──────────────────────────────
    cs_list = m.get("content_scripts", [])
    for i, cs in enumerate(cs_list):
        for js_file in cs.get("js", []) or []:
            cs_path = manifest_path.parent / js_file
            if not cs_path.exists():
                emit("CRITICAL", p, f"content_scripts[{i}].js",
                     f"file {js_file!r} does not exist on disk.")
                critical += 1
        for css_file in cs.get("css", []) or []:
            css_path = manifest_path.parent / css_file
            if not css_path.exists():
                emit("CRITICAL", p, f"content_scripts[{i}].css",
                     f"file {css_file!r} does not exist on disk.")
                critical += 1
        if cs.get("matches") and "<all_urls>" in cs["matches"]:
            emit("WARNING", p, f"content_scripts[{i}].matches",
                 "matches '<all_urls>'. Narrow to specific origins if possible.")
            warnings += 1

    # ── Info-level hints ───────────────────────────────────────────
    if not m.get("homepage_url"):
        emit("INFO", p, "homepage_url",
             "not set. Consider adding for the CWS listing.")

    if not m.get("author"):
        emit("INFO", p, "author", "not set. Consider adding for the CWS listing.")

    if not m.get("offline_enabled"):
        emit("INFO", p, "offline_enabled",
             "not set. Set true/false explicitly.")

    # ── Final verdict ───────────────────────────────────────────────
    print()
    print(f"── Summary ─ critical: {critical}, warnings: {warnings} ──")
    return 1 if critical > 0 else 0


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} path/to/manifest.json", file=sys.stderr)
        return 2
    return validate(Path(sys.argv[1]).resolve())


if __name__ == "__main__":
    sys.exit(main())
