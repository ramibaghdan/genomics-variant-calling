# Genomics Variant-Calling Pipeline (Docker + WDL + Nextflow)

A small NGS pipeline that takes short sequencing reads and produces called
variants, implemented three ways so the differences between a plain script, a
WDL workflow, and a Nextflow workflow are visible side by side. Every step runs
in the same Docker image.

## Background

Bioinformatics pipelines get written in whatever the local convention is: bash
at one institution, WDL at another, Nextflow at a third. The underlying science
is identical. The differences are all in how work gets declared, how inputs flow
between steps, and what the engine handles for you.

Writing the same four steps three times makes those differences concrete instead
of theoretical.

## Goal

Align reads, call variants, and check the calls against a known answer.

## The pipeline

```
reads (FASTQ)
     |
     v
[ bwa mem ]      align reads to the reference genome
     |
     v
[ samtools ]     sort + index the alignments (BAM)
     |
     v
[ bcftools ]     pileup + call variants
     |
     v
variants (VCF)
```

Read `scripts/run_pipeline.sh` first. It is the science with no workflow-engine
syntax in the way. The WDL and Nextflow versions do the same four steps.

## Test data

`scripts/simulate_data.sh` builds a small random reference and uses `wgsim` to
generate paired-end reads with mutations injected at a known rate. wgsim records
exactly which variants it introduced, so the pipeline has a correct answer to be
measured against, and the whole thing runs in seconds with no downloads.

## Validation

`scripts/check_truth.sh` compares the called VCF against the injected variants:

```
Substitutions in truth : 831
SNVs called            : 829

  true positives  828
  false negatives 3   (injected, not called)
  false positives 1   (called, not injected)

  recall    99.6%
  precision 99.9%
```

Three injected variants missed, one call with nothing behind it.

 The reference is 100 kb of random
sequence with no repeats, no homopolymers, and no mapping ambiguity, covered at
roughly 40x by 20,000 simulated read pairs. Every variant sits in a uniquely
mappable context with plenty of supporting reads, so near-perfect numbers are what is expected. The check confirms the four
steps are connected properly and the tools are doing what they claim.

`simulate_data.sh` uses a fixed seed, so cloning this gets
the same numbers.

Substitutions only. Homozygous and heterozygous sites both count, the latter
carrying an IUPAC code in wgsim's alt column. Indels are excluded: wgsim reports
their position differently from how bcftools normalizes them, and comparing them
properly needs allele-level normalization this project does not attempt.
Positions are compared.

## Prerequisites

- Docker (Docker Desktop on macOS)
- [`miniwdl`](https://github.com/chanzuckerberg/miniwdl) for the WDL run (`pip install miniwdl`)
- [`nextflow`](https://www.nextflow.io/) for the Nextflow run (needs Java 11+)

## Running it

```bash
# 0. Build the tools image (once)
docker build --platform=linux/amd64 -t variant-calling:latest .

# 1. Make the test data
docker run --rm -v "$PWD":/work -w /work variant-calling:latest \
  bash scripts/simulate_data.sh

# 2a. Plain bash version
docker run --rm -v "$PWD":/work -w /work variant-calling:latest \
  bash scripts/run_pipeline.sh
#    -> results_bash/variants.vcf.gz

# 2b. WDL version (miniwdl launches the container for each task)
miniwdl run wdl/variant_calling.wdl -i wdl/inputs.json
#    -> outputs under a timestamped miniwdl run directory

# 2c. Nextflow version (Docker enabled in nextflow.config)
nextflow run nextflow/main.nf
#    -> results_nextflow/variants.vcf.gz

# 3. Check the calls against the injected variants
docker run --rm -v "$PWD":/work -w /work variant-calling:latest \
  bash scripts/check_truth.sh results_bash/variants.vcf.gz
```

## Layout

| Path | What it is |
|---|---|
| `Dockerfile`, `env.yaml` | The tools image (bwa, samtools, bcftools, wgsim) |
| `scripts/simulate_data.sh` | Generates the test dataset and its truth file |
| `scripts/run_pipeline.sh` | The pipeline as a plain bash script (read this first) |
| `scripts/check_truth.sh` | Compares calls against the truth file |
| `wdl/variant_calling.wdl` + `wdl/inputs.json` | The WDL implementation (miniwdl) |
| `nextflow/main.nf` + `nextflow/nextflow.config` | The Nextflow DSL2 implementation |

## Limitations

- Simulated reads on a random reference. Real genomes have repeats,
  homopolymers, and mapping-quality problems this does not reproduce, which is
  why the validation numbers are as high as they are.
- Substitutions only in the validation, for the reason given above.
- `bcftools call -mv` with default filters. No hard filtering, no recalibration.
  At 40x on clean data this costs nothing; on real data it would.
- One sample, no joint calling.
