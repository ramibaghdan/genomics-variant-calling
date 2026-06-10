#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# The pipeline written as a plain bash script. Read this FIRST: it is the
# science, with no workflow-engine syntax in the way. The WDL and Nextflow
# versions do exactly these same steps, just expressed in those languages.
#
# Run INSIDE the Docker image, from the repo root:
#   docker run --rm -v "$PWD":/work -w /work variant-calling:latest \
#     bash scripts/run_pipeline.sh
# ---------------------------------------------------------------------------
set -euo pipefail

REF=${1:-data/reference.fasta}
R1=${2:-data/reads_R1.fastq}
R2=${3:-data/reads_R2.fastq}
SAMPLE=${4:-demo}
OUT=${5:-results_bash}
mkdir -p "$OUT"

echo "[1/4] Indexing the reference"
# bwa needs an index to align against; samtools faidx makes a .fai used by bcftools
bwa index "$REF"
samtools faidx "$REF"

echo "[2/4] Aligning reads with bwa mem"
# -R adds a read group (sample metadata) that downstream tools expect
bwa mem -R "@RG\tID:${SAMPLE}\tSM:${SAMPLE}\tPL:ILLUMINA" \
  "$REF" "$R1" "$R2" > "$OUT/aligned.sam"

echo "[3/4] Sorting + indexing the alignments"
# Variant callers need coordinate-sorted, indexed BAM files
samtools sort -o "$OUT/${SAMPLE}.sorted.bam" "$OUT/aligned.sam"
samtools index "$OUT/${SAMPLE}.sorted.bam"

echo "[4/4] Calling variants with bcftools"
# mpileup summarizes per-position evidence; call -mv emits variant sites only
bcftools mpileup -f "$REF" "$OUT/${SAMPLE}.sorted.bam" \
  | bcftools call -mv -Oz -o "$OUT/variants.vcf.gz"
bcftools index "$OUT/variants.vcf.gz"

echo
echo "Done. Outputs in $OUT/"
echo -n "Variant records called: "
bcftools view -H "$OUT/variants.vcf.gz" | wc -l
