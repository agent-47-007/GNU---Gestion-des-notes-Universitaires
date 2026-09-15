#!/usr/bin/env bash
set -euo pipefail

base="${API_BASE:-http://127.0.0.1:8080/api}"
echo "[1/4] health"
curl --fail --silent "$base/health" | tee /dev/stderr
echo
echo "[2/4] dashboard"
curl --fail --silent "$base/dashboard" | tee /dev/stderr
echo
echo "[3/4] classes"
curl --fail --silent "$base/classes" | tee /dev/stderr
echo
echo "[4/4] bulletin"
curl --fail --silent "$base/students/21T2355/bulletin?period=S1" | tee /dev/stderr
echo
echo "Contrôles API réussis."
