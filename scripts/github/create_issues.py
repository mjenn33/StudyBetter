"""Create the roadmap labels, milestones and issues from issues.json.

Safe to re-run: existing milestones and issues (matched by title) are skipped,
labels are created or updated.

    python scripts/github/create_issues.py --dry-run
    python scripts/github/create_issues.py
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

DEFAULT_REPO = "mjenn33/StudyBetter"
DATA = Path(__file__).with_name("issues.json")


def gh(*args: str, stdin: str | None = None) -> str:
    result = subprocess.run(
        ["gh", *args],
        input=stdin,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        sys.exit(f"gh {' '.join(args)} failed:\n{result.stderr}")
    return result.stdout


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--dry-run", action="store_true", help="print what would be created")
    args = parser.parse_args()
    repo = args.repo
    data = json.loads(DATA.read_text(encoding="utf-8"))

    known_milestones = {m["title"] for m in data["milestones"]}
    known_labels = {l["name"] for l in data["labels"]} | {"documentation", "accessibility"}
    for issue in data["issues"]:
        assert issue["milestone"] in known_milestones, issue["title"]
        assert set(issue["labels"]) <= known_labels, issue["title"]

    if args.dry_run:
        for issue in data["issues"]:
            labels = ", ".join(["roadmap", *issue["labels"]])
            print(f"[{issue['milestone']}] {issue['title']}  ({labels})")
        print(f"\n{len(data['issues'])} issues, {len(data['milestones'])} milestones")
        return

    for label in data["labels"]:
        gh("label", "create", label["name"], "--repo", repo, "--force",
           "--color", label["color"], "--description", label["description"])

    existing = json.loads(gh("api", f"repos/{repo}/milestones?state=all&per_page=100"))
    existing_titles = {m["title"] for m in existing}
    for milestone in data["milestones"]:
        if milestone["title"] not in existing_titles:
            gh("api", f"repos/{repo}/milestones", "-f", f"title={milestone['title']}",
               "-f", f"description={milestone['description']}")
            print(f"milestone: {milestone['title']}")

    issues = json.loads(gh("issue", "list", "--repo", repo, "--state", "all",
                           "--limit", "1000", "--json", "title"))
    existing_issues = {i["title"] for i in issues}
    for issue in data["issues"]:
        if issue["title"] in existing_issues:
            print(f"skip (exists): {issue['title']}")
            continue
        cmd = ["issue", "create", "--repo", repo, "--title", issue["title"],
               "--milestone", issue["milestone"], "--body-file", "-"]
        for label in ["roadmap", *issue["labels"]]:
            cmd += ["--label", label]
        url = gh(*cmd, stdin=issue["body"]).strip()
        print(f"{url}  {issue['title']}")


if __name__ == "__main__":
    main()
