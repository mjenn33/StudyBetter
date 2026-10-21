"""Add every `roadmap` issue to a GitHub Project (Kanban board), oldest first.

Safe to re-run: issues already on the board are skipped.

    python scripts/github/add_to_project.py --owner <project-owner> --project <number>

The project number is the last part of the project URL, e.g.
https://github.com/users/mjenn33/projects/1 -> --owner mjenn33 --project 1.
Needs the `project` scope: gh auth refresh -s project
"""

import argparse
import json
import subprocess
import sys

DEFAULT_REPO = "mjenn33/StudyBetter"


def gh(*args: str) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        sys.exit(f"gh {' '.join(args)} failed:\n{result.stderr}")
    return result.stdout


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--owner", required=True, help="user or org that owns the project")
    parser.add_argument("--project", required=True, help="project number")
    parser.add_argument("--repo", default=DEFAULT_REPO)
    args = parser.parse_args()

    items = json.loads(gh("project", "item-list", args.project, "--owner", args.owner,
                          "--limit", "1000", "--format", "json"))["items"]
    on_board = {item.get("content", {}).get("url") for item in items}

    issues = json.loads(gh("issue", "list", "--repo", args.repo, "--label", "roadmap",
                           "--state", "all", "--limit", "1000", "--json", "number,title,url"))
    for issue in sorted(issues, key=lambda i: i["number"]):
        if issue["url"] in on_board:
            continue
        gh("project", "item-add", args.project, "--owner", args.owner, "--url", issue["url"])
        print(f"added #{issue['number']} {issue['title']}")


if __name__ == "__main__":
    main()
