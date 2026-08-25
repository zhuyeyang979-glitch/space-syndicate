#!/usr/bin/env python3
"""Render the human views from the sole product-continuity authority."""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json"
GENERATED = "GENERATED_FROM=SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json\n"


def load() -> dict:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    required = {"project_identity", "versions", "capabilities", "product_surfaces", "assets", "current_work_items", "future_backlog", "retired_goals", "cancelled_goals", "supersession_links", "known_gaps", "release_requirements"}
    missing = required - data.keys()
    if missing:
        raise ValueError(f"missing registry sections: {sorted(missing)}")
    ids = [x["version_id"] for x in data["versions"]]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate version id")
    for version in data["versions"][1:]:
        if version["parent_version_id"] not in ids:
            raise ValueError(f"unknown version parent: {version['version_id']}")
    for name in ("capabilities", "product_surfaces", "assets", "current_work_items", "future_backlog", "retired_goals", "cancelled_goals"):
        if not isinstance(data[name], list):
            raise ValueError(f"{name} must be a list")
    return data


def table(headers: list[str], rows: list[list[str]]) -> str:
    return "| " + " | ".join(headers) + " |\n| " + " | ".join(["---"] * len(headers)) + " |\n" + "\n".join("| " + " | ".join(row) + " |" for row in rows) + "\n"


def write(name: str, title: str, body: str) -> None:
    (HERE / name).write_text(f"# {title}\n\n{GENERATED}\n\n{body}", encoding="utf-8")


def render(data: dict) -> None:
    versions = data["versions"]
    write("SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.md", "Space Syndicate Product Continuity Registry", "\n".join([
        "This is a generated index. The JSON file is the only continuity authority; existing Owner, reuse, green-ledger, Golden-scenario, and card-certification records remain their own authorities.",
        "\n## Current identity\n",
        table(["Field", "Value"], [["Current version", data["project_identity"]["current_version_id"]], ["Activation head", data["activation"]["activation_head_sha"]], ["Production entry", data["project_identity"]["production_entry_scene"]], ["Product task interrupted", str(data["activation"]["current_product_task_interrupted"]).lower()]]),
        "\n## Registry counts\n",
        table(["Section", "Count"], [[k, str(len(data[k]))] for k in ["versions", "capabilities", "product_surfaces", "assets", "current_work_items", "future_backlog", "retired_goals", "cancelled_goals"]]),
        "\n## Product surface reachability\n",
        table(["Surface", "Current status", "Production reachable", "Path / evidence"], [[x["surface_id"], x["current_status"], str(x["production_reachable"]).lower(), x["production_reachability_path"]] for x in data["product_surfaces"]]),
        "\n## Known gaps\n" + "\n".join(f"- `{x['gap_id']}` — {x['summary']}" for x in data["known_gaps"]),
    ]))
    write("SPACE_SYNDICATE_VERSION_HISTORY.md", "Space Syndicate Version History", "\n".join([
        "## Version lineage\n",
        table(["Version", "Parent", "Base commit", "Final/current commit", "Release status", "Human play"], [[x["version_id"], x.get("parent_version_id") or "ROOT", x["base_commit_sha"], x.get("final_commit_sha") or "OPEN", x["release_status"], x["human_play_status"]] for x in versions]),
        "\n## Version deltas\n",
        "\n".join(f"### {x['version_delta_id']}\n\n- Inherited: {', '.join(x['inherited_capability_ids']) or 'none'}\n- Added: {', '.join(x['added_capability_ids']) or 'none'}\n- Changed: {', '.join(x['changed_capability_ids']) or 'none'}\n- Fixed: {', '.join(x.get('fixed_capability_ids', [])) or 'none separately registered; see changed'}\n- Migrated: {', '.join(x.get('migrated_capability_ids', [])) or 'none separately registered; see inherited/changed'}\n- Superseded: {', '.join(x.get('superseded_capability_ids', [])) or 'none'}\n- Retired: {', '.join(x.get('retired_capability_ids', [])) or 'none'}\n- Cancelled goals: {', '.join(x.get('cancelled_goal_ids', [])) or 'none'}\n- Deferred: {', '.join(x['deferred_capability_ids']) or 'none'}\n- Known gaps: {', '.join(x['known_gap_ids']) or 'none'}\n" for x in versions),
    ]))
    write("SPACE_SYNDICATE_CURRENT_DEVELOPMENT_STATUS.md", "Current Development Status", "\n".join([
        "The current V0.7.6 candidate is not Human Green. Golden STEP13 remains pending; STEP14 and STEP15 have not started.",
        "\n## Active work\n",
        table(["ID", "Status", "Priority", "Next task", "Dependencies"], [[x["work_item_id"], x["status"], x["priority"], x["next_task"], ", ".join(x["dependencies"])] for x in data["current_work_items"]]),
        "\n## Release requirements\n" + "\n".join(f"- `{x}`" for x in data["release_requirements"]["required_before_ready_merge_tag"]),
    ]))
    write("SPACE_SYNDICATE_FUTURE_ROADMAP.md", "Space Syndicate Future Roadmap", "\n".join([
        "## Registered backlog\n",
        table(["ID", "Target", "Priority", "Design", "Implementation", "Production", "Human play"], [[x["backlog_id"], x["target_version"], x["priority"], x["design_status"], x["implementation_status"], x["production_status"], x["human_play_status"]] for x in data["future_backlog"]]),
        "\n## Rationale\n" + "\n".join(f"- `{x['backlog_id']}` — {x['reason']}" for x in data["future_backlog"]),
    ]))
    all_goals = [("Retired", x) for x in data["retired_goals"]] + [("Cancelled", x) for x in data["cancelled_goals"]]
    write("SPACE_SYNDICATE_RETIRED_AND_CANCELLED_GOALS.md", "Space Syndicate Retired and Cancelled Goals", "\n".join([
        "Historical decisions are preserved here; they are not permission to revive retired mechanics.",
        "\n## Decisions\n",
        table(["Class", "Goal", "Original version", "Final status", "Reason", "Superseded by"], [[kind, x["goal_id"], x["introduced_version"], x["final_status"], x["decision_reason"], x.get("superseded_by") or "—"] for kind, x in all_goals]),
    ]))


if __name__ == "__main__":
    render(load())
