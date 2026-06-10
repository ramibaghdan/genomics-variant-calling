nextflow.enable.dsl=2

// ===========================================================================
// The same pipeline a THIRD way, in Nextflow (DSL2).
//
// Nextflow concepts to notice:
//   - `process`     : one step. `container` sets the Docker image it runs in.
//   - `input/output`: declared with types like `path`. Nextflow stages files
//                     into an isolated work/ directory per process execution.
//   - `script`      : the shell that runs (triple-quoted). Note `\\t` to escape
//                     the tab so Groovy + bash both see a literal tab.
//   - `emit:`       : names an output channel so the workflow can wire it onward.
//   - `publishDir`  : copies final outputs out of work/ into a results folder.
//   - `workflow {}` : connects processes; passing one process's .out to another
//                     creates the dependency (Nextflow figures out ordering).
//
// Run from the repo root (Docker enabled via nextflow.config):
//   nextflow run nextflow/main.nf
// ===========================================================================

params.reference = "data/reference.fasta"
params.reads1    = "data/reads_R1.fastq"
params.reads2    = "data/reads_R2.fastq"
params.sample    = "demo"
params.outdir    = "results_nextflow"

process ALIGN_AND_SORT {
  container 'variant-calling:latest'
  publishDir params.outdir, mode: 'copy'

  input:
    path reference
    path reads1
    path reads2

  output:
    path "${params.sample}.sorted.bam",     emit: bam
    path "${params.sample}.sorted.bam.bai", emit: bai

  script:
  """
  REF="${reference}"
  bwa index "\$REF"
  samtools faidx "\$REF"
  bwa mem -R "@RG\\tID:${params.sample}\\tSM:${params.sample}\\tPL:ILLUMINA" \
    "\$REF" ${reads1} ${reads2} > aligned.sam
  samtools sort -o ${params.sample}.sorted.bam aligned.sam
  samtools index ${params.sample}.sorted.bam
  """
}

process CALL_VARIANTS {
  container 'variant-calling:latest'
  publishDir params.outdir, mode: 'copy'

  input:
    path reference
    path bam
    path bai

  output:
    path "variants.vcf.gz"

  script:
  """
  REF="${reference}"
  samtools faidx "\$REF"
  bcftools mpileup -f "\$REF" ${bam} | bcftools call -mv -Oz -o variants.vcf.gz
  bcftools index variants.vcf.gz
  """
}

workflow {
  ref = file(params.reference)
  r1  = file(params.reads1)
  r2  = file(params.reads2)

  ALIGN_AND_SORT(ref, r1, r2)
  CALL_VARIANTS(ref, ALIGN_AND_SORT.out.bam, ALIGN_AND_SORT.out.bai)
}
