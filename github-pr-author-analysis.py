#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
import time
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

API_ROOT = "https://api.github.com"
PER_PAGE = 100
MAX_RETRIES = 8
REQUEST_TIMEOUT = 60
USER_AGENT = "util-scripts-github-pr-author-analysis"
COAUTHOR_RE = re.compile(r"(?im)^co-authored-by:\s*(.+)$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Collect pull requests by a GitHub author over a date range, inspect commit metadata "
            "for involvement by another identity, and emit JSON/CSV plus an SVG stacked bar chart."
        )
    )
    parser.add_argument("--author", required=True, help="GitHub username to analyze, e.g. neubig")
    parser.add_argument("--start", required=True, help="Start date in YYYY-MM-DD format")
    parser.add_argument("--end", required=True, help="End date in YYYY-MM-DD format")
    parser.add_argument(
        "--output-dir",
        default="analysis_output",
        help="Directory for generated files (default: analysis_output)",
    )
    parser.add_argument(
        "--match-keyword",
        default="openhands",
        help="Case-insensitive keyword indicating involvement (default: openhands)",
    )
    parser.add_argument(
        "--match-email-domain",
        default="all-hands.dev",
        help="Case-insensitive email domain indicating involvement (default: all-hands.dev)",
    )
    parser.add_argument(
        "--match-label",
        default="OpenHands",
        help="Human-readable label used in chart and summaries (default: OpenHands)",
    )
    parser.add_argument(
        "--token-env",
        default="GITHUB_TOKEN",
        help="Environment variable containing the GitHub token (default: GITHUB_TOKEN)",
    )
    return parser.parse_args()


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9._-]+", "-", value.lower()).strip("-") or "value"


def parse_iso_date(value: str) -> date:
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError as exc:
        raise SystemExit(f"Invalid date {value!r}; expected YYYY-MM-DD") from exc


def log(message: str) -> None:
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{timestamp}] {message}", flush=True)


def contains_target(value: Optional[str], keyword: str, email_domain: str) -> bool:
    if not value:
        return False
    lowered = value.lower()
    return keyword in lowered or email_domain in lowered


def month_windows(start: date, end: date) -> Iterable[Tuple[date, date]]:
    cursor = date(start.year, start.month, 1)
    while cursor <= end:
        if cursor.month == 12:
            next_month = date(cursor.year + 1, 1, 1)
        else:
            next_month = date(cursor.year, cursor.month + 1, 1)
        window_end = min(end, next_month - timedelta(days=1))
        yield cursor, window_end
        cursor = next_month


def parse_link_header(value: Optional[str]) -> Dict[str, str]:
    links: Dict[str, str] = {}
    if not value:
        return links
    for part in value.split(","):
        section = part.strip().split(";")
        if len(section) < 2:
            continue
        url_part = section[0].strip()
        if not (url_part.startswith("<") and url_part.endswith(">")):
            continue
        url = url_part[1:-1]
        rel = None
        for piece in section[1:]:
            piece = piece.strip()
            if piece.startswith("rel="):
                rel = piece.split("=", 1)[1].strip('"')
                break
        if rel:
            links[rel] = url
    return links


def sleep_for_rate_limit(headers: Dict[str, str]) -> bool:
    remaining = headers.get("x-ratelimit-remaining")
    reset = headers.get("x-ratelimit-reset")
    if remaining == "0" and reset:
        reset_at = datetime.fromtimestamp(int(reset), tz=timezone.utc)
        wait_seconds = max(1, int((reset_at - datetime.now(timezone.utc)).total_seconds()) + 2)
        log(
            f"Rate limit reached for resource {headers.get('x-ratelimit-resource', 'unknown')}; sleeping {wait_seconds}s until {reset_at.isoformat()}"
        )
        time.sleep(wait_seconds)
        return True
    return False


def request_json(url: str, token: str, params: Optional[Dict[str, str]] = None) -> Tuple[object, Dict[str, str]]:
    if params:
        query = urlencode(params)
        separator = "&" if "?" in url else "?"
        url = f"{url}{separator}{query}"

    for attempt in range(1, MAX_RETRIES + 1):
        req = Request(
            url,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {token}",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": USER_AGENT,
            },
        )
        try:
            with urlopen(req, timeout=REQUEST_TIMEOUT) as response:
                payload = response.read().decode("utf-8")
                headers = {k.lower(): v for k, v in response.getheaders()}
                if sleep_for_rate_limit(headers):
                    continue
                return json.loads(payload), headers
        except HTTPError as exc:
            headers = {k.lower(): v for k, v in (exc.headers.items() if exc.headers else [])}
            body = exc.read().decode("utf-8", errors="replace")
            if exc.code in (403, 429) and sleep_for_rate_limit(headers):
                continue
            if exc.code in (500, 502, 503, 504, 403, 429):
                wait_seconds = min(60, 2 ** attempt)
                log(f"HTTP {exc.code} on attempt {attempt}/{MAX_RETRIES} for {url}; retrying in {wait_seconds}s")
                time.sleep(wait_seconds)
                continue
            raise RuntimeError(f"HTTP {exc.code} for {url}: {body[:500]}") from exc
        except URLError as exc:
            wait_seconds = min(60, 2 ** attempt)
            log(f"Network error on attempt {attempt}/{MAX_RETRIES} for {url}: {exc}; retrying in {wait_seconds}s")
            time.sleep(wait_seconds)
    raise RuntimeError(f"Failed after {MAX_RETRIES} attempts: {url}")


def iter_paginated(url: str, token: str, params: Optional[Dict[str, str]] = None, item_key: Optional[str] = None):
    next_url = url
    next_params = params.copy() if params else None
    while next_url:
        payload, headers = request_json(next_url, token, next_params)
        next_params = None
        if item_key is None:
            items = payload
        else:
            if not isinstance(payload, dict):
                raise RuntimeError(f"Expected dict payload for {next_url}")
            items = payload.get(item_key, [])
        if not isinstance(items, list):
            raise RuntimeError(f"Expected list items for {next_url}")
        for item in items:
            yield item, headers
        next_url = parse_link_header(headers.get("link")).get("next")


def extract_repo_name(repository_url: str) -> str:
    prefix = f"{API_ROOT}/repos/"
    if repository_url.startswith(prefix):
        return repository_url[len(prefix) :]
    return repository_url


def search_prs_by_month(author: str, start_date: date, end_date: date, token: str) -> List[Dict[str, object]]:
    prs: List[Dict[str, object]] = []
    seen = set()
    for window_start, window_end in month_windows(start_date, end_date):
        month_key = window_start.strftime("%Y-%m")
        query = f"type:pr author:{author} created:{window_start.isoformat()}..{window_end.isoformat()}"
        params = {
            "q": query,
            "sort": "created",
            "order": "asc",
            "per_page": str(PER_PAGE),
        }
        month_count = 0
        log(f"Searching PRs for {month_key} with query: {query}")
        for item, _headers in iter_paginated(f"{API_ROOT}/search/issues", token, params=params, item_key="items"):
            repo = extract_repo_name(item["repository_url"])
            key = f"{repo}#{item['number']}"
            if key in seen:
                continue
            seen.add(key)
            month_count += 1
            prs.append(
                {
                    "key": key,
                    "repository": repo,
                    "number": item["number"],
                    "title": item["title"],
                    "html_url": item["html_url"],
                    "api_url": item["pull_request"]["url"],
                    "created_at": item["created_at"],
                    "state": item["state"],
                    "month": item["created_at"][:7],
                }
            )
        log(f"Collected {month_count} PRs for {month_key}; cumulative total {len(prs)}")
    prs.sort(key=lambda pr: (pr["created_at"], pr["repository"], pr["number"]))
    return prs


def analyze_pr_commits(
    pr: Dict[str, object],
    token: str,
    match_keyword: str,
    match_email_domain: str,
) -> Dict[str, object]:
    commits_url = f"{pr['api_url']}/commits"
    params = {"per_page": str(PER_PAGE)}
    matched = False
    has_coauthor_trailer = False
    has_metadata_match = False
    matched_commits = []
    commit_count = 0

    for commit, _headers in iter_paginated(commits_url, token, params=params, item_key=None):
        commit_count += 1
        message = (((commit or {}).get("commit") or {}).get("message")) or ""
        trailer_lines = COAUTHOR_RE.findall(message)
        trailer_match = any(contains_target(line, match_keyword, match_email_domain) for line in trailer_lines)

        author_login = ((commit.get("author") or {}).get("login"))
        committer_login = ((commit.get("committer") or {}).get("login"))
        raw_author = (((commit.get("commit") or {}).get("author")) or {})
        raw_committer = (((commit.get("commit") or {}).get("committer")) or {})
        metadata_values = [
            author_login,
            committer_login,
            raw_author.get("name"),
            raw_author.get("email"),
            raw_committer.get("name"),
            raw_committer.get("email"),
        ]
        metadata_match = any(contains_target(value, match_keyword, match_email_domain) for value in metadata_values)

        if trailer_match or metadata_match:
            matched = True
            has_coauthor_trailer = has_coauthor_trailer or trailer_match
            has_metadata_match = has_metadata_match or metadata_match
            matched_commits.append(
                {
                    "sha": commit.get("sha"),
                    "html_url": commit.get("html_url"),
                    "message_head": message.splitlines()[0] if message else "",
                    "coauthor_trailer_match": trailer_match,
                    "metadata_match": metadata_match,
                    "author_login": author_login,
                    "committer_login": committer_login,
                    "author_name": raw_author.get("name"),
                    "author_email": raw_author.get("email"),
                    "committer_name": raw_committer.get("name"),
                    "committer_email": raw_committer.get("email"),
                }
            )

    return {
        **pr,
        "commit_count": commit_count,
        "matched": matched,
        "has_match_coauthor_trailer": has_coauthor_trailer,
        "has_match_metadata": has_metadata_match,
        "matched_commits": matched_commits,
    }


def empty_month_counts(start_date: date, end_date: date) -> Dict[str, Dict[str, int]]:
    counts = {}
    for window_start, _window_end in month_windows(start_date, end_date):
        counts[window_start.strftime("%Y-%m")] = {"matched": 0, "not_matched": 0}
    return counts


def build_monthly_counts(
    prs: List[Dict[str, object]],
    start_date: date,
    end_date: date,
) -> Dict[str, Dict[str, int]]:
    counts = empty_month_counts(start_date, end_date)
    for pr in prs:
        month = pr["month"]
        bucket = counts.setdefault(month, {"matched": 0, "not_matched": 0})
        if pr["matched"]:
            bucket["matched"] += 1
        else:
            bucket["not_matched"] += 1
    return counts


def write_json(path: Path, payload: object) -> None:
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=False)
        handle.write("\n")


def write_pr_csv(path: Path, prs: List[Dict[str, object]]) -> None:
    fieldnames = [
        "month",
        "repository",
        "number",
        "title",
        "created_at",
        "html_url",
        "commit_count",
        "matched",
        "has_match_coauthor_trailer",
        "has_match_metadata",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for pr in prs:
            writer.writerow({name: pr.get(name) for name in fieldnames})


def write_monthly_csv(path: Path, counts: Dict[str, Dict[str, int]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["month", "matched", "not_matched", "total"])
        for month, values in counts.items():
            writer.writerow([month, values["matched"], values["not_matched"], values["matched"] + values["not_matched"]])


def svg_text(x: float, y: float, text: str, extra: str = "") -> str:
    escaped = (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )
    return f'<text x="{x:.2f}" y="{y:.2f}" {extra}>{escaped}</text>'


def create_svg_chart(
    path: Path,
    counts: Dict[str, Dict[str, int]],
    author: str,
    start_date: date,
    end_date: date,
    match_label: str,
) -> None:
    months = list(counts.keys())
    values = [counts[m] for m in months]
    totals = [item["matched"] + item["not_matched"] for item in values]
    max_total = max(totals) if totals else 0
    max_total = max_total if max_total > 0 else 1

    width = 1600
    height = 900
    margin_left = 90
    margin_right = 30
    margin_top = 90
    margin_bottom = 170
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom
    slot_width = plot_width / max(1, len(months))
    bar_width = min(40, slot_width * 0.65)
    blue = "#2563eb"
    red = "#dc2626"
    grid = "#d1d5db"
    axis = "#111827"
    background = "#ffffff"

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="{background}"/>',
        svg_text(
            width / 2,
            40,
            f"{author} PRs by month ({start_date.strftime('%Y-%m')} to {end_date.strftime('%Y-%m')})",
            'text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#111827"',
        ),
        svg_text(
            width / 2,
            68,
            f"Red = {match_label} involved in PR commits; Blue = no {match_label} involvement detected",
            'text-anchor="middle" font-family="Arial, sans-serif" font-size="16" fill="#374151"',
        ),
    ]

    tick_count = min(6, max_total + 1)
    if tick_count < 2:
        tick_count = 2
    for i in range(tick_count):
        ratio = i / (tick_count - 1)
        value = round(max_total * (1 - ratio))
        y = margin_top + plot_height * ratio
        svg.append(
            f'<line x1="{margin_left}" y1="{y:.2f}" x2="{width - margin_right}" y2="{y:.2f}" stroke="{grid}" stroke-width="1"/>'
        )
        svg.append(
            svg_text(
                margin_left - 10,
                y + 5,
                str(value),
                'text-anchor="end" font-family="Arial, sans-serif" font-size="14" fill="#4b5563"',
            )
        )

    svg.append(
        f'<line x1="{margin_left}" y1="{margin_top}" x2="{margin_left}" y2="{margin_top + plot_height}" stroke="{axis}" stroke-width="2"/>'
    )
    svg.append(
        f'<line x1="{margin_left}" y1="{margin_top + plot_height}" x2="{width - margin_right}" y2="{margin_top + plot_height}" stroke="{axis}" stroke-width="2"/>'
    )

    for index, month in enumerate(months):
        values_for_month = counts[month]
        matched_count = values_for_month["matched"]
        other_count = values_for_month["not_matched"]
        total = matched_count + other_count
        x_center = margin_left + slot_width * index + slot_width / 2
        x = x_center - bar_width / 2
        other_height = 0 if max_total == 0 else (other_count / max_total) * plot_height
        matched_height = 0 if max_total == 0 else (matched_count / max_total) * plot_height
        base_y = margin_top + plot_height
        other_y = base_y - other_height
        matched_y = other_y - matched_height

        if other_height > 0:
            svg.append(
                f'<rect x="{x:.2f}" y="{other_y:.2f}" width="{bar_width:.2f}" height="{other_height:.2f}" fill="{blue}" rx="3" ry="3"/>'
            )
        if matched_height > 0:
            svg.append(
                f'<rect x="{x:.2f}" y="{matched_y:.2f}" width="{bar_width:.2f}" height="{matched_height:.2f}" fill="{red}" rx="3" ry="3"/>'
            )
        svg.append(
            svg_text(
                x_center,
                margin_top + plot_height + 55,
                month,
                f'text-anchor="end" transform="rotate(-45 {x_center:.2f} {margin_top + plot_height + 55:.2f})" font-family="Arial, sans-serif" font-size="13" fill="#374151"',
            )
        )
        if total > 0:
            svg.append(
                svg_text(
                    x_center,
                    matched_y - 8,
                    str(total),
                    'text-anchor="middle" font-family="Arial, sans-serif" font-size="12" fill="#111827"',
                )
            )

    legend_x = width - margin_right - 330
    legend_y = 85
    svg.append(f'<rect x="{legend_x}" y="{legend_y}" width="18" height="18" fill="{red}" rx="3" ry="3"/>')
    svg.append(svg_text(legend_x + 28, legend_y + 14, f"{match_label} involved", 'font-family="Arial, sans-serif" font-size="15" fill="#111827"'))
    svg.append(f'<rect x="{legend_x + 170}" y="{legend_y}" width="18" height="18" fill="{blue}" rx="3" ry="3"/>')
    svg.append(svg_text(legend_x + 198, legend_y + 14, f"No {match_label} involvement", 'font-family="Arial, sans-serif" font-size="15" fill="#111827"'))

    svg.append(
        svg_text(
            20,
            24,
            f"Generated {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
            'font-family="Arial, sans-serif" font-size="12" fill="#6b7280"',
        )
    )
    svg.append("</svg>")

    with path.open("w", encoding="utf-8") as handle:
        handle.write("\n".join(svg))


def main() -> None:
    args = parse_args()
    token = os.environ.get(args.token_env)
    if not token:
        raise SystemExit(f"{args.token_env} is required")

    start_date = parse_iso_date(args.start)
    end_date = parse_iso_date(args.end)
    if end_date < start_date:
        raise SystemExit("--end must be on or after --start")

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    prefix = f"{slugify(args.author)}_prs_{start_date.strftime('%Y-%m')}_to_{end_date.strftime('%Y-%m')}"
    prs = search_prs_by_month(args.author, start_date, end_date, token)

    checkpoint_path = output_dir / f"{prefix}_checkpoint.json"
    analyzed = []
    total = len(prs)
    log(f"Beginning commit analysis for {total} PRs")
    for index, pr in enumerate(prs, start=1):
        log(f"Analyzing PR {index}/{total}: {pr['key']}")
        analyzed_pr = analyze_pr_commits(pr, token, args.match_keyword.lower(), args.match_email_domain.lower())
        analyzed.append(analyzed_pr)
        if index % 10 == 0 or index == total:
            write_json(checkpoint_path, {"completed": index, "total": total, "prs": analyzed})
            log(f"Wrote checkpoint after {index}/{total} PRs")

    counts = build_monthly_counts(analyzed, start_date, end_date)
    summary = {
        "query": {
            "author": args.author,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "match_keyword": args.match_keyword,
            "match_email_domain": args.match_email_domain,
            "match_label": args.match_label,
        },
        "totals": {
            "all_prs": len(analyzed),
            "matched_prs": sum(1 for pr in analyzed if pr["matched"]),
            "coauthor_trailer_prs": sum(1 for pr in analyzed if pr["has_match_coauthor_trailer"]),
            "metadata_match_prs": sum(1 for pr in analyzed if pr["has_match_metadata"]),
        },
        "monthly_counts": counts,
    }

    all_json_path = output_dir / f"{prefix}.json"
    summary_json_path = output_dir / f"{prefix}_summary.json"
    pr_csv_path = output_dir / f"{prefix}.csv"
    monthly_csv_path = output_dir / f"{prefix}_monthly_counts.csv"
    chart_svg_path = output_dir / f"{prefix}_monthly_stacked.svg"
    matched_json_path = output_dir / f"{prefix}_with_{slugify(args.match_label)}_coauthor.json"

    write_json(all_json_path, analyzed)
    write_json(summary_json_path, summary)
    write_pr_csv(pr_csv_path, analyzed)
    write_monthly_csv(monthly_csv_path, counts)
    create_svg_chart(chart_svg_path, counts, args.author, start_date, end_date, args.match_label)
    write_json(matched_json_path, [pr for pr in analyzed if pr["has_match_coauthor_trailer"]])

    log(
        "Done. Wrote "
        + ", ".join(
            str(path)
            for path in (
                all_json_path,
                summary_json_path,
                pr_csv_path,
                monthly_csv_path,
                chart_svg_path,
                matched_json_path,
            )
        )
    )


if __name__ == "__main__":
    main()
