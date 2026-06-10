#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Make a tiny, self-contained test dataset so the pipeline runs in seconds and
# needs no large downloads.
#
#   1. Generate a random ~100 kb "reference" genome (fixed seed = reproducible).
#   2. Use wgsim to simulate paired-end reads FROM that reference, injecting
#      substitutions and indels. wgsim also writes a "truth" file listing the
#      variants it introduced, which is what our pipeline should rediscover.
#
# Run this INSIDE the Docker image (it has python + wgsim):
#   docker run --rm -v "$PWD":/work -w /work variant-calling:latest \
#     bash scripts/simulate_data.sh
# ---------------------------------------------------------------------------
set -euo pipefail

mkdir -p data

# 1. Random reference genome, deterministic via seed=42
python - <<'PY' > data/reference.fasta
import random
random.seed(42)
print(">chrDemo")
seq = "".join(random.choice("ACGT") for _ in range(100_000))
for i in range(0, len(seq), 70):     # wrap at 70 chars/line (FASTA convention)
    print(seq[i:i+70])
PY

# 2. Simulate paired-end reads with mutations
#    -N 20000  : number of read pairs
#    -1 / -2   : read length for each mate
#    -r 0.010  : base mutation rate (the variants we want to call)
#    -R 0.15   : fraction of mutations that are indels
#    -X 0.30   : probability an indel is extended
#    -S 42     : random seed
wgsim -N 20000 -1 100 -2 100 -r 0.010 -R 0.15 -X 0.30 -S 42 \
  data/reference.fasta data/reads_R1.fastq data/reads_R2.fastq > data/wgsim_truth.txt

echo "Created:"
echo "  data/reference.fasta   (reference genome)"
echo "  data/reads_R1.fastq    (forward reads)"
echo "  data/reads_R2.fastq    (reverse reads)"
echo "  data/wgsim_truth.txt   (the variants wgsim injected = ground truth)"
