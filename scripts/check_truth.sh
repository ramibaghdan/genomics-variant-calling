#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Compare the called variants against the ones wgsim injected.
#
# simulate_data.sh writes a truth file, so the pipeline can be checked instead
# of just counting how many records came out. Counting records tells you the
# tools ran. This tells you whether they were right.
#
# wgsim truth columns: chromosome, position, ref_base, alt_base, haplotype.
# Only substitutions are compared. wgsim writes indels with a '-' in the base
# columns and reports the position differently from how bcftools normalizes
# them, so matching them by position alone gives false mismatches.
#
# Run INSIDE the Docker image, from the repo root:
#   docker run --rm -v "$PWD":/work -w /work variant-calling:latest \
#     bash scripts/check_truth.sh results_bash/variants.vcf.gz
# ---------------------------------------------------------------------------
set -euo pipefail

VCF=${1:-results_bash/variants.vcf.gz}
TRUTH=${2:-data/wgsim_truth.txt}

[ -f "$VCF" ]   || { echo "No VCF at $VCF. Run the pipeline first."; exit 1; }
[ -f "$TRUTH" ] || { echo "No truth file at $TRUTH. Run scripts/simulate_data.sh."; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Substitutions only: both base columns must be a single ACGT character.
awk '$3 ~ /^[ACGTacgt]$/ && $4 ~ /^[ACGTacgt]$/ {print $1"\t"$2}' "$TRUTH" \
  | sort -u > "$TMP/truth.pos"

bcftools view -H -v snps "$VCF" \
  | awk '{print $1"\t"$2}' \
  | sort -u > "$TMP/called.pos"

TP=$(comm -12 "$TMP/truth.pos" "$TMP/called.pos" | wc -l | tr -d ' ')
FN=$(comm -23 "$TMP/truth.pos" "$TMP/called.pos" | wc -l | tr -d ' ')
FP=$(comm -13 "$TMP/truth.pos" "$TMP/called.pos" | wc -l | tr -d ' ')
TRUTH_N=$(wc -l < "$TMP/truth.pos" | tr -d ' ')
CALLED_N=$(wc -l < "$TMP/called.pos" | tr -d ' ')

pct () { [ "$2" -eq 0 ] && echo "n/a" || awk -v a="$1" -v b="$2" 'BEGIN{printf "%.1f%%", 100*a/b}'; }

echo "Substitutions in truth : $TRUTH_N"
echo "SNVs called            : $CALLED_N"
echo
echo "  true positives  $TP"
echo "  false negatives $FN   (injected, not called)"
echo "  false positives $FP   (called, not injected)"
echo
echo "  recall    $(pct "$TP" "$TRUTH_N")"
echo "  precision $(pct "$TP" "$CALLED_N")"
echo
echo "Positions are compared, not alleles. At this coverage and mutation rate a"
echo "handful of misses is expected: low-depth positions and reads spanning an"
echo "indel both cost sensitivity."
