# Genomics Variant-Calling Pipeline (Docker + WDL + Nextflow)

A small, reproducible NGS pipeline that takes short sequencing reads and produces
a set of called variants. The point of the project is to implement the **same**
workflow three ways, so the differences between a plain script, a **WDL** workflow,
and a **Nextflow** workflow are easy to see. Every step runs inside the **same
Docker image**, so results are reproducible anywhere.

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

The test data is **simulated** by `scripts/simulate_data.sh`: it builds a small
random reference and uses `wgsim` to generate reads with known, injected variants.
That gives us a ground-truth list (`data/wgsim_truth.txt`) the pipeline should
rediscover, and keeps the whole thing fast with no large downloads.

## Repo layout

| Path | What it is |
|---|---|
| `Dockerfile`, `env.yaml` | The reproducible tools image (bwa, samtools, bcftools, wgsim) |
| `scripts/simulate_data.sh` | Generates the tiny test dataset |
| `scripts/run_pipeline.sh` | The pipeline as a plain bash script (read this first) |
| `wdl/variant_calling.wdl` + `wdl/inputs.json` | The WDL implementation (run with miniwdl) |
| `nextflow/main.nf` + `nextflow/nextflow.config` | The Nextflow DSL2 implementation |

## Prerequisites

- Docker (Docker Desktop on macOS)
- [`miniwdl`](https://github.com/chanzuckerberg/miniwdl) for the WDL run (`pip install miniwdl`)
- [`nextflow`](https://www.nextflow.io/) for the Nextflow run (needs Java 11+)

## Run it

```bash
# 0. Build the tools image (once)
docker build --platform=linux/amd64 -t variant-calling:latest .

# 1. Make the test data (runs python + wgsim inside the image)
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
```

