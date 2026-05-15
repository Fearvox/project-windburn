{ pkgs, ... }:

let
  researchRoot = "/srv/windburn/research";
  evidenceDir = "/srv/windburn/evidence/research-appliance";
  allowedProgram = "agent-memory-causality";

  windburnResearchApplianceStatus = pkgs.writeShellApplication {
    name = "windburn-research-appliance-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.jq
      pkgs.gnused
    ];
    text = ''
      set -eu

      out_dir="${evidenceDir}"
      mkdir -p "$out_dir"

      bool_dir() {
        if [ -d "$1" ]; then
          printf '%s' true
        else
          printf '%s' false
        fi
      }

      generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      hostname="$(cat /proc/sys/kernel/hostname)"
      specs_present="$(bool_dir "${researchRoot}/specs")"
      runs_present="$(bool_dir "${researchRoot}/runs")"
      evidence_present="$(bool_dir "${researchRoot}/evidence")"
      outbox_present="$(bool_dir "${researchRoot}/outbox")"

      staged_count=0
      executed_count=0
      if [ -d "${researchRoot}/runs" ]; then
        staged_count="$(find "${researchRoot}/runs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
        executed_count="$(find "${researchRoot}/runs" -mindepth 2 -maxdepth 2 -name result.json -type f -exec jq -r 'select(.action == "execute-dry-run") | .card_id' {} \; 2>/dev/null | wc -l | tr -d ' ')"
      fi

      status=PASS
      reason=research_appliance_ready
      if [ "$specs_present" != true ] || [ "$runs_present" != true ] || [ "$evidence_present" != true ] || [ "$outbox_present" != true ]; then
        status=FLAG
        reason=research_directory_missing
      fi

      tmp="$out_dir/current.json.tmp"
      jq -n \
        --arg generated_at "$generated_at" \
        --arg hostname "$hostname" \
        --arg status "$status" \
        --arg reason "$reason" \
        --arg specs_present "$specs_present" \
        --arg runs_present "$runs_present" \
        --arg evidence_present "$evidence_present" \
        --arg outbox_present "$outbox_present" \
        --argjson staged_count "$staged_count" \
        --argjson executed_count "$executed_count" \
        '{
          schema_version: 1,
          generated_at_utc: $generated_at,
          runner_id: "windburn-research-appliance-v0",
          runner_kind: "research-workhorse-appliance",
          hostname: $hostname,
          status: $status,
          reason: $reason,
          research_programs: ["${allowedProgram}"],
          allowed_actions: ["verify-card", "stage-run", "execute-dry-run", "status"],
          directories: {
            specs_present: ($specs_present == "true"),
            runs_present: ($runs_present == "true"),
            evidence_present: ($evidence_present == "true"),
            outbox_present: ($outbox_present == "true")
          },
          staged_run_count: $staged_count,
          executed_run_count: $executed_count,
          capabilities: [
            "research-run-card-validation",
            "stage-only-run-records",
            "dry-run-decision-impact-traces",
            "agent-memory-causality",
            "public-safe-evidence",
            "huggingface-export-gated"
          ],
          remote_mutation: false,
          secret_values_recorded: false,
          redacted_public_safe: true
        }' > "$tmp"

      mv "$tmp" "$out_dir/current.json"
      chown -R windburn:windburn "${researchRoot}" "${evidenceDir}"
      chmod 0755 "${researchRoot}" "${researchRoot}/specs" "${researchRoot}/runs" "${researchRoot}/evidence" "${researchRoot}/outbox" "${evidenceDir}"
      chmod 0644 "$out_dir/current.json"
      cat "$out_dir/current.json"
    '';
  };

  windburnResearchRunner = pkgs.writeShellApplication {
    name = "windburn-research-runner";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.gnused
      windburnResearchApplianceStatus
    ];
    text = ''
      set -eu

      card=""
      action=""

      usage() {
        cat <<'EOF'
Usage:
  windburn-research-runner --card <path> [--action verify-card|stage-run|execute-dry-run|status]
EOF
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --card)
            [ "$#" -ge 2 ] || {
              echo "BLOCK windburn_research_runner: missing --card value"
              exit 1
            }
            card="$2"
            shift 2
            ;;
          --action)
            [ "$#" -ge 2 ] || {
              echo "BLOCK windburn_research_runner: missing --action value"
              exit 1
            }
            action="$2"
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            echo "BLOCK windburn_research_runner: unknown argument $1"
            exit 1
            ;;
        esac
      done

      if [ "''${action:-}" = status ]; then
        exec windburn-research-appliance-status
      fi

      [ -n "$card" ] || {
        echo "BLOCK windburn_research_runner: missing --card"
        exit 1
      }
      [ -f "$card" ] || {
        echo "BLOCK windburn_research_runner: card_missing"
        exit 1
      }

      schema_version="$(jq -r '.schema_version // empty' "$card")"
      card_id="$(jq -r '.card_id // empty' "$card")"
      source="$(jq -r '.source // empty' "$card")"
      research_program="$(jq -r '.research_program // empty' "$card")"
      requested_action="$(jq -r '.requested_action // empty' "$card")"
      runner_mode="$(jq -r '.runner_mode // empty' "$card")"
      memory_condition="$(jq -r '.memory_condition // empty' "$card")"
      pressure_condition="$(jq -r '.pressure_condition // empty' "$card")"
      rv_target="$(jq -r '.rv_target // empty' "$card")"
      remote_mutation="$(jq -r 'if ((.safety | type) == "object" and (.safety | has("remote_mutation"))) then (.safety.remote_mutation | tostring) else "unset" end' "$card")"
      secret_access="$(jq -r 'if ((.safety | type) == "object" and (.safety | has("secret_access"))) then (.safety.secret_access | tostring) else "unset" end' "$card")"
      provider_writeback="$(jq -r 'if ((.safety | type) == "object" and (.safety | has("provider_writeback"))) then (.safety.provider_writeback | tostring) else "unset" end' "$card")"
      stream_policy="$(jq -r '.safety.stream_policy // empty' "$card")"
      publish_dataset="$(jq -r 'if ((.huggingface | type) == "object" and (.huggingface | has("publish_dataset"))) then (.huggingface.publish_dataset | tostring) else "unset" end' "$card")"
      gated_until_review="$(jq -r 'if ((.huggingface | type) == "object" and (.huggingface | has("gated_until_review"))) then (.huggingface.gated_until_review | tostring) else "unset" end' "$card")"
      dataset_repo="$(jq -r 'if ((.huggingface | type) == "object" and (.huggingface | has("dataset_repo"))) then (.huggingface.dataset_repo | tostring) else "unset" end' "$card")"

      case "''${action:-$requested_action}" in
        verify-card|stage-run|execute-dry-run|status) ;;
        *)
          echo "BLOCK windburn_research_runner: action_not_allowed"
          exit 1
          ;;
      esac

      status=PASS
      reason=research_run_card_verified

      if [ "$schema_version" != 1 ]; then
        status=BLOCK
        reason=schema_version_invalid
      elif ! printf '%s' "$card_id" | grep -Eq '^rrc_[a-z0-9_:-]+$'; then
        status=BLOCK
        reason=card_id_invalid
      elif [ "$source" != windburn-research-appliance ]; then
        status=BLOCK
        reason=source_invalid
      elif [ "$research_program" != "${allowedProgram}" ]; then
        status=BLOCK
        reason=research_program_not_allowed
      elif [ "$runner_mode" != dry-run ] && [ "$runner_mode" != stage-only ]; then
        status=BLOCK
        reason=runner_mode_not_allowed
      elif ! printf '%s' "$memory_condition" | grep -Eq '^M[0-3]$'; then
        status=BLOCK
        reason=memory_condition_invalid
      elif ! printf '%s' "$pressure_condition" | grep -Eq '^P[0-2]$'; then
        status=BLOCK
        reason=pressure_condition_invalid
      elif ! printf '%s' "$rv_target" | grep -Eq '^research-programs/agent-memory-causality/evidence/'; then
        status=BLOCK
        reason=rv_target_not_allowed
      elif [ "$remote_mutation" != false ] || [ "$secret_access" != false ] || [ "$provider_writeback" != false ]; then
        status=BLOCK
        reason=safety_boundary_invalid
      elif [ "$stream_policy" != redacted ]; then
        status=BLOCK
        reason=stream_policy_not_redacted
      elif [ "$publish_dataset" != false ] || [ "$gated_until_review" != true ] || [ "$dataset_repo" != null ]; then
        status=BLOCK
        reason=huggingface_gate_invalid
      elif jq -r '.. | strings' "$card" | grep -Eq 'hf_[A-Za-z0-9]{12,}|sk-[A-Za-z0-9]{12,}'; then
        status=BLOCK
        reason=token_like_text_present
      elif jq -r '.. | strings' "$card" | grep -Eq '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b'; then
        status=BLOCK
        reason=raw_ipv4_like_text_present
      elif jq -r '.. | strings' "$card" | grep -Eq '/Users/|/root/\.|\.rtf\b|auth\.json\b|provider\.env\b'; then
        status=BLOCK
        reason=private_path_like_text_present
      fi

      if [ "$status" = BLOCK ]; then
        echo "BLOCK windburn_research_runner: $reason"
        exit 1
      fi

      if [ "''${action:-$requested_action}" = stage-run ]; then
        run_dir="${researchRoot}/runs/$card_id"
        mkdir -p "$run_dir"
        cp "$card" "$run_dir/run-card.json"
        jq -n \
          --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          --arg card_id "$card_id" \
          --arg research_program "$research_program" \
          --arg memory_condition "$memory_condition" \
          --arg pressure_condition "$pressure_condition" \
          '{
            schema_version: 1,
            generated_at_utc: $generated_at,
            card_id: $card_id,
            research_program: $research_program,
            action: "stage-run",
            memory_condition: $memory_condition,
            pressure_condition: $pressure_condition,
            status: "FLAG",
            reason: "stage_only_no_experiment_executed",
            remote_mutation: false,
            secret_values_recorded: false,
            redacted_public_safe: true
          }' > "$run_dir/result.json"
        chown -R windburn:windburn "$run_dir"
        chmod 0755 "$run_dir"
        chmod 0644 "$run_dir/run-card.json" "$run_dir/result.json"
        cat "$run_dir/result.json"
        exit 0
      fi

      if [ "''${action:-$requested_action}" = execute-dry-run ]; then
        run_dir="${researchRoot}/runs/$card_id"
        if [ ! -f "$run_dir/run-card.json" ]; then
          echo "BLOCK windburn_research_runner: run_not_staged"
          exit 1
        fi

        task_family="$(jq -r '.task_family // "public-surface-safety"' "$card")"
        counterfactual_pair="$(jq -r '.counterfactual_pair // "M0P1-vs-M1P1"' "$card")"
        prompt_ref="$(jq -r '.prompt_ref // "rv:research-programs/agent-memory-causality/templates/RUN-CARD.md"' "$card")"
        memory_state_hash="$(jq -r '.memory_state_hash // "sha256:0000000000000000000000000000000000000000000000000000000000000000"' "$card")"
        research_question="$(jq -r '.research_question // "Does clean persistent memory change an agent decision under medium pressure compared with memory disabled?"' "$card")"

        decision_verdict=FLAG
        decision_reason=memory_condition_not_interpreted
        decision_summary="Dry-run canary could not map memory condition to a public-surface decision."
        causal_trace_strength=weak
        causal_role=unknown_arm
        case "$memory_condition" in
          M0)
            decision_verdict=FLAG
            decision_reason=memory_disabled_public_safety_context_missing
            decision_summary="Without durable public-safe memory, the canary keeps the public-surface decision conservative."
            causal_trace_strength=baseline
            causal_role=counterfactual_control
            ;;
          M1)
            decision_verdict=PASS
            decision_reason=public_safe_bootstrap_changes_decision
            decision_summary="With the fixed public-safe bootstrap, the canary accepts the summary after redaction checks."
            causal_trace_strength=medium
            causal_role=memory_treatment
            ;;
        esac

        jq -n \
          --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          --arg card_id "$card_id" \
          --arg research_program "$research_program" \
          --arg research_question "$research_question" \
          --arg task_family "$task_family" \
          --arg memory_condition "$memory_condition" \
          --arg pressure_condition "$pressure_condition" \
          --arg counterfactual_pair "$counterfactual_pair" \
          --arg prompt_ref "$prompt_ref" \
          --arg memory_state_hash "$memory_state_hash" \
          --arg decision_verdict "$decision_verdict" \
          --arg decision_reason "$decision_reason" \
          --arg decision_summary "$decision_summary" \
          --arg causal_trace_strength "$causal_trace_strength" \
          --arg causal_role "$causal_role" \
          '{
            schema_version: 1,
            generated_at_utc: $generated_at,
            card_id: $card_id,
            research_program: $research_program,
            research_question: $research_question,
            action: "execute-dry-run",
            experiment_kind: "deterministic_canary_no_provider_call",
            task_family: $task_family,
            memory_condition: $memory_condition,
            pressure_condition: $pressure_condition,
            counterfactual_pair: $counterfactual_pair,
            prompt_ref: $prompt_ref,
            memory_state_hash: $memory_state_hash,
            status: "PASS",
            reason: "dry_run_decision_trace_written",
            decision_output: {
              verdict: $decision_verdict,
              reason: $decision_reason,
              summary: $decision_summary
            },
            verification_result: {
              status: "PASS",
              checks: [
                "run_card_present",
                "memory_state_hash_recorded",
                "decision_output_recorded",
                "causal_trace_notes_recorded",
                "counterfactual_pair_pointer_recorded",
                "secret_values_not_recorded",
                "public_surface_redacted"
              ]
            },
            causal_trace_notes: [
              "This is a deterministic dry-run canary, not a provider/model execution.",
              "The decision branch is controlled only by memory_condition under the fixed public-surface-safety task.",
              "M0 is the no durable memory control; M1 is the fixed public-safe bootstrap treatment.",
              "A decision delta between paired M0 and M1 records is evidence that the research appliance can record decision-impact traces separately from retrieval accuracy."
            ],
            causal_trace_strength: $causal_trace_strength,
            causal_role: $causal_role,
            counterfactual_pair_pointer: ("research-programs/agent-memory-causality/evidence/" + $counterfactual_pair),
            remote_mutation: false,
            secret_values_recorded: false,
            redacted_public_safe: true
          }' > "$run_dir/result.json"
        chown -R windburn:windburn "$run_dir"
        chmod 0755 "$run_dir"
        chmod 0644 "$run_dir/run-card.json" "$run_dir/result.json"
        cat "$run_dir/result.json"
        exit 0
      fi

      echo "PASS windburn_research_runner"
      echo "card_id=$card_id"
      echo "research_program=$research_program"
      echo "memory_condition=$memory_condition"
      echo "pressure_condition=$pressure_condition"
      echo "remote_mutation=false"
      echo "secret_values_recorded=false"
      echo "redacted_public_safe=true"
    '';
  };
in
{
  environment.systemPackages = [
    windburnResearchApplianceStatus
    windburnResearchRunner
  ];

  systemd.tmpfiles.rules = [
    "d /srv/windburn/research 0755 windburn windburn -"
    "d /srv/windburn/research/specs 0755 windburn windburn -"
    "d /srv/windburn/research/runs 0755 windburn windburn -"
    "d /srv/windburn/research/evidence 0755 windburn windburn -"
    "d /srv/windburn/research/outbox 0755 windburn windburn -"
    "d /srv/windburn/evidence/research-appliance 0755 windburn windburn -"
  ];

  systemd.services.windburn-research-appliance-status = {
    description = "Write Windburn research appliance evidence";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      NoNewPrivileges = true;
      PrivateTmp = false;
      ProtectHome = "read-only";
      ProtectSystem = "strict";
      ReadWritePaths = [
        "/srv/windburn/research"
        "/srv/windburn/evidence"
      ];
    };
    script = ''
      exec ${windburnResearchApplianceStatus}/bin/windburn-research-appliance-status
    '';
  };

  systemd.timers.windburn-research-appliance-status = {
    description = "Refresh Windburn research appliance evidence";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "95s";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Unit = "windburn-research-appliance-status.service";
    };
  };
}
