{pkgs}:
pkgs.runCommand "metrics-dashboards-check" {
  nativeBuildInputs = with pkgs; [python3 victoriametrics];
} ''
  python3 -B ${./metrics-dashboards.py} ${../servers/loem/metrics/dashboards}
  touch $out
''
