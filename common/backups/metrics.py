"""Bounded Prometheus gauges and counters for persisted machine-backup state."""

from datetime import datetime
import math


def render(config, state, now):
    lines = []
    declared = set()
    host = config["host"]

    def emit(name, value, description, labels=None, kind="gauge"):
        if not math.isfinite(value):
            raise ValueError("Backup metric must be finite")
        name = "machine_backup_" + name
        if name not in declared:
            lines.extend(["# HELP " + name + " " + description, "# TYPE " + name + " " + kind])
            declared.add(name)
        def escape(value):
            return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')
        fields = {"job": "machine-backups", "host": host, **(labels or {})}
        labels_text = ",".join(key + '="' + escape(value) + '"' for key, value in fields.items())
        lines.append(name + "{" + labels_text + "} " + str(value))

    def timestamp(value):
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() if value else 0

    emit("telemetry_timestamp_seconds", now, "Time this state was pushed; independent of backup freshness.")
    emit("metrics_push_failures_total", state.get("metricsDelivery", {}).get("failures", 0),
         "Failed telemetry pushes since local state was created.", kind="counter")
    for scope in sorted(config["scopes"]):
        complete = state.get("lastComplete", {}).get(scope, {})
        labels = {"scope": scope}
        emit("complete_timestamp_seconds", timestamp(complete.get("capturedAt")),
             "Capture time of the last locally completed restore point; zero means none.", labels)
        emit("upload_timestamp_seconds", timestamp(complete.get("uploadedAt")),
             "Upload completion time of the last complete restore point; zero means none.", labels)
        emit("freshness_limit_seconds", 7200 if scope == "services" else 43200,
             "Maximum complete restore point age used by the backup monitor.", labels)
        for field, metric, description in [
            ("total_bytes_processed", "source_bytes", "Bytes scanned for the last complete backup."),
            ("data_added_packed", "added_bytes", "Packed repository bytes added by the last complete backup."),
            ("total_files_processed", "source_files", "Files scanned for the last complete backup."),
        ]:
            if field in complete.get("summary", {}):
                emit(metric, complete["summary"][field], description, labels)

    # Peer observations retain their observer's host label. Two machines must not
    # overwrite one another's assessment of repository freshness.
    hosts = {host, config.get("peerHost") or host}
    for source in sorted(hosts):
        emit("enrolled_host_info", 1, "Backup clients expected by this observer's configured peer relationship.",
             {"source_host": source})
        for scope in ["home", "services"]:
            observed = timestamp(state.get("observedComplete", {}).get(source + ":" + scope))
            if source == host:
                observed = max(observed, timestamp(state.get("lastComplete", {}).get(scope, {}).get("capturedAt")))
            emit("observed_complete_timestamp_seconds", observed,
                 "Latest complete restore point seen by this observer; zero means none.",
                 {"source_host": source, "scope": scope})
    emit("repository_contact_timestamp_seconds", timestamp(state.get("lastRepositoryContact")),
         "Last successful repository freshness check; zero means none.")

    for key, run in sorted(state.get("lastRun", {}).items()):
        operation, scope = key.split(":", 1)
        if operation not in ["backup", "monitor", "maintain", "restore-test"] or scope not in ["home", "services", "repository"]:
            continue
        labels = {"operation": operation, "scope": scope}
        emit("run_timestamp_seconds", timestamp(run["finishedAt"]), "Last operation completion time.", labels)
        emit("run_success", int(run["success"]), "Whether the last operation succeeded.", labels)
        emit("run_duration_seconds", run["seconds"], "Duration of the last finished operation.", labels)
        for outcome, count in state.get("runs", {}).get(key, {}).items():
            if outcome in ["success", "failure"]:
                emit("runs_total", count, "Finished operations since local state was created.",
                     {**labels, "outcome": outcome}, kind="counter")

    for key, health in sorted(state.get("health", {}).items()):
        parts = key.split(":")
        check = parts[0]
        labels = {"check": check}
        if check == "freshness" and len(parts) == 3 and parts[1] in hosts and parts[2] in ["home", "services"]:
            labels.update(source_host=parts[1], scope=parts[2])
        elif check in ["backup", "restore-test", "maintain"] and len(parts) == 2 and parts[1] in ["home", "services", "repository"]:
            labels["scope"] = parts[1]
        elif key not in ["repository", "capacity", "inventory"]:
            continue
        emit("health_status", {"ok": 0, "warning": 1, "critical": 2}.get(health["level"], 3),
             "Recorded health: 0 ok, 1 warning, 2 critical, 3 unknown. Unchecked components are absent.", labels)

    capacity = state.get("capacity", {})
    emit("capacity_check_timestamp_seconds", timestamp(capacity.get("checkedAt")),
         "Last successful Storage Box quota measurement; zero means none.")
    for field, metric in [("freeBytes", "quota_free_bytes"), ("quotaBytes", "quota_bytes"), ("percent", "quota_used_percent")]:
        if field in capacity:
            emit(metric, capacity[field], "Storage Box purchased quota and free-quota usage estimate.")
    emit("integrity_check_timestamp_seconds", timestamp(state.get("lastIntegrityCheck", {}).get("at")),
         "Last successful repository check with a rotating quarter data read; zero means none.")
    emit("maintenance_timestamp_seconds", timestamp(state.get("lastMaintenance")),
         "Last successful retention, prune and integrity check; zero means none.")
    if "inventory" in state:
        inventory = state["inventory"]
        emit("inventory_check_timestamp_seconds", timestamp(inventory.get("checkedAt")), "Last service coverage inspection.")
        emit("inventory_uncovered_paths", len(inventory.get("uncoveredPaths", [])), "Unclassified persistent state paths.")
        emit("inventory_inspection_issues", len(inventory.get("issues", [])), "Service coverage inspection failures.")
    emit("notifications_pending", len(state.get("notifications", [])), "Queued backup health notifications.")
    if "notificationDelivery" in state:
        emit("notification_delivery_success", int(state["notificationDelivery"]["level"] == "ok"),
             "Whether the last Gotify delivery check succeeded.")
    for rehearsal in state.get("restoreRehearsals", {}).values():
        labels = {"source_host": rehearsal["host"], "scope": rehearsal["scope"]}
        emit("restore_rehearsal_timestamp_seconds", timestamp(rehearsal["verifiedAt"]),
             "Verification time of the last successful rehearsal; not the restored snapshot time.", labels)
        emit("restore_rehearsal_duration_seconds", rehearsal["seconds"], "Last successful restore verification duration.", labels)
        emit("restore_rehearsal_partial", int(rehearsal["partialSelection"]), "Whether only selected files were rehearsed.", labels)
        emit("restore_rehearsal_application_verified", int(rehearsal["applicationStartupVerified"]),
             "Whether application startup was verified; file checks alone do not establish this.", labels)
    return "\n".join(lines) + "\n"
