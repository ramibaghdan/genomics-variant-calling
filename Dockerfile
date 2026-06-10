# ---------------------------------------------------------------------------
# A reproducible image that bundles the genomics tools for this pipeline.
#
# WHY THIS MATTERS: instead of asking every user (or every compute node) to
# install bwa/samtools/bcftools at the right versions, we package them once.
# WDL (miniwdl) and Nextflow both run each step INSIDE this container, so the
# bash pipeline, the WDL workflow, and the Nextflow workflow all use the exact
# same tools. That reproducibility is the whole point of Docker in bioinformatics.
#
# --platform=linux/amd64: bioconda's prebuilt packages target amd64. On an Apple
# Silicon Mac, Docker Desktop runs this under emulation. It is slower, but our
# test data is tiny so it does not matter.
# ---------------------------------------------------------------------------
FROM --platform=linux/amd64 mambaorg/micromamba:1.5.8

# Copy the environment spec (owned by the non-root mamba user the base image uses)
COPY --chown=$MAMBA_USER:$MAMBA_USER env.yaml /tmp/env.yaml

# Install the tools into the base conda environment, then clean caches to slim the image
RUN micromamba install -y -n base -f /tmp/env.yaml && micromamba clean --all --yes

# Activate the env for subsequent RUN steps and make tools available on PATH
ARG MAMBA_DOCKERFILE_ACTIVATE=1
ENV PATH=/opt/conda/bin:$PATH

# Sanity check at build time: fail the build early if a tool is missing
RUN bwa 2>&1 | head -1; samtools --version | head -1; bcftools --version | head -1
