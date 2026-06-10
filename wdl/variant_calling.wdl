version 1.0

# ===========================================================================
# The same align -> sort -> call-variants pipeline, written in WDL.
#
# WDL concepts to notice:
#   - `workflow`   : the orchestration; how tasks connect via inputs/outputs.
#   - `task`       : one containerized step. Each runs in the `runtime.docker` image.
#   - `input {}`   : typed inputs (File, String, Int...). Files are auto-localized
#                    into the task's working directory by the engine.
#   - `command <<< >>>` : the shell that actually runs inside the container.
#   - `~{var}`     : WDL placeholder substituted into the command.
#   - `output {}`  : files/values the engine collects and passes downstream.
#
# Run with miniwdl (it executes each task in Docker):
#   miniwdl run wdl/variant_calling.wdl -i wdl/inputs.json
# ===========================================================================

workflow VariantCalling {
  input {
    File reference
    File reads1
    File reads2
    String sample_name = "demo"
    String docker_image = "variant-calling:latest"
  }

  # Step 1: index reference, align reads, sort + index the BAM
  call AlignAndSort {
    input:
      reference = reference,
      reads1 = reads1,
      reads2 = reads2,
      sample_name = sample_name,
      docker_image = docker_image
  }

  # Step 2: call variants from the sorted BAM (depends on step 1's outputs)
  call CallVariants {
    input:
      reference = reference,
      sorted_bam = AlignAndSort.sorted_bam,
      sorted_bai = AlignAndSort.sorted_bai,
      docker_image = docker_image
  }

  output {
    File aligned_bam = AlignAndSort.sorted_bam
    File variants_vcf = CallVariants.vcf
  }
}

task AlignAndSort {
  input {
    File reference
    File reads1
    File reads2
    String sample_name
    String docker_image
  }
  command <<<
    set -euo pipefail
    # Copy the reference locally so bwa's index files land beside it
    cp ~{reference} reference.fasta
    bwa index reference.fasta
    samtools faidx reference.fasta

    bwa mem -R "@RG\tID:~{sample_name}\tSM:~{sample_name}\tPL:ILLUMINA" \
      reference.fasta ~{reads1} ~{reads2} > aligned.sam
    samtools sort -o ~{sample_name}.sorted.bam aligned.sam
    samtools index ~{sample_name}.sorted.bam
  >>>
  output {
    File sorted_bam = "~{sample_name}.sorted.bam"
    File sorted_bai = "~{sample_name}.sorted.bam.bai"
  }
  runtime {
    docker: docker_image
  }
}

task CallVariants {
  input {
    File reference
    File sorted_bam
    File sorted_bai
    String docker_image
  }
  command <<<
    set -euo pipefail
    cp ~{reference} reference.fasta
    samtools faidx reference.fasta
    bcftools mpileup -f reference.fasta ~{sorted_bam} \
      | bcftools call -mv -Oz -o variants.vcf.gz
    bcftools index variants.vcf.gz
  >>>
  output {
    File vcf = "variants.vcf.gz"
  }
  runtime {
    docker: docker_image
  }
}
