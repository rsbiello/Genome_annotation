#!/usr/bin/env bash
#SBATCH --job-name=rnaseq_portcullis
#SBATCH --partition=bigmem
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=160G
#SBATCH --time=500:00:00
#SBATCH --output=slurm.%N.%j.out
#SBATCH --error=slurm.%N.%j.err

set -euo pipefail

# ============================================================
# RNA-seq alignment and Portcullis splice-junction filtering
# ============================================================
#
# This script processes paired-end RNA-seq reads and generates
# splice-junction-filtered BAM files using:
#
#   1. fastp
#   2. HISAT2
#   3. SAMtools
#   4. Portcullis
#
# The workflow is useful for preparing RNA-seq evidence for
# genome annotation and gene prediction pipelines.
#
# The script is designed to be generic and reusable.
# To use it, edit the variables in the "USER SETTINGS" section
# below, then submit the script with:
#
#   sbatch run_rnaseq_portcullis.sh
#
# Requirements:
#   1. A working SLURM environment.
#   2. fastp.
#   3. HISAT2.
#   4. SAMtools.
#   5. Portcullis.
#   6. A repeat-masked genome FASTA file.
#   7. Paired-end RNA-seq FASTQ files.
#   8. A text file containing one sample ID per line.
#
# Input FASTQ naming convention:
#
#   For each sample ID in SAMPLE_LIST, the script expects:
#
#     SAMPLE_ID_1.fastq.gz
#     SAMPLE_ID_2.fastq.gz
#
#   Example:
#
#     sample01_1.fastq.gz
#     sample01_2.fastq.gz
#
# ============================================================


# ============================================================
# USER SETTINGS
# ============================================================
#
# Edit the variables below before submitting the job.
#
# REF_GENOME:
#   Path to the repeat-masked reference genome FASTA file.
#   This genome will be indexed with HISAT2 and used for RNA-seq
#   read alignment.
#
# WORKDIR:
#   Main working directory for this pipeline.
#   HISAT2 index files, filtered reads, BAM files, and Portcullis
#   output directories will be written here.
#
# SAMPLE_LIST:
#   Plain text file containing one sample ID per line.
#   Each ID should match the prefix of the paired FASTQ files.
#
# FASTQ_DIR:
#   Directory containing paired-end RNA-seq FASTQ files.
#
# FASTP_COMMAND:
#   Command or full path used to run fastp.
#   Use "fastp" if fastp is available in your PATH.
#
# HISAT2_INDEX_PREFIX:
#   Prefix for the HISAT2 index files created by hisat2-build.
#
# THREADS:
#   Number of CPU threads to use.
#   This should usually match the SLURM --cpus-per-task value.
#
# OUT_TRIM:
#   Directory for filtered FASTQ files produced by fastp.
#
# OUT_BAM:
#   Directory for SAM, BAM, sorted BAM, and BAM index files.
#
# OUT_PORTCULLIS:
#   Directory for Portcullis output files.
#
# ============================================================

REF_GENOME="/path/to/repeat_masked_genome.fasta"
WORKDIR="/path/to/rnaseq_portcullis_workdir"
SAMPLE_LIST="${WORKDIR}/sample_ids.txt"
FASTQ_DIR="/path/to/rnaseq_fastq"

FASTP_COMMAND="fastp"
HISAT2_INDEX_PREFIX="${WORKDIR}/hisat2_index/genome_index"

THREADS="${SLURM_CPUS_PER_TASK:-8}"

OUT_TRIM="${WORKDIR}/trimmed"
OUT_BAM="${WORKDIR}/BAMs"
OUT_PORTCULLIS="${WORKDIR}/portcullis"


# ============================================================
# SOFTWARE SETUP
# ============================================================
#
# Edit this section depending on how software is installed
# on your system.
#
# Option 1: Conda environment
# Uncomment and edit the following line if using Conda:
#
# source /path/to/miniconda3/bin/activate annotation_env
#
# Option 2: Environment modules
# Uncomment and edit the following lines if using modules:
#
# module load hisat2
# module load samtools
# module load portcullis
# module load fastp
#
# Option 3: Software already available
# If all tools are already available in PATH, no changes are needed.
#
# ============================================================

# source /path/to/miniconda3/bin/activate annotation_env
# module load hisat2
# module load samtools
# module load portcullis
# module load fastp


# ============================================================
# CHECK INPUTS
# ============================================================

if [[ ! -f "${REF_GENOME}" ]]; then
    echo "ERROR: Reference genome FASTA file not found:"
    echo "  ${REF_GENOME}"
    echo
    echo "Please edit REF_GENOME in the USER SETTINGS section."
    exit 1
fi

if [[ ! -f "${SAMPLE_LIST}" ]]; then
    echo "ERROR: Sample list file not found:"
    echo "  ${SAMPLE_LIST}"
    echo
    echo "Please edit SAMPLE_LIST in the USER SETTINGS section."
    exit 1
fi

if [[ ! -d "${FASTQ_DIR}" ]]; then
    echo "ERROR: FASTQ directory not found:"
    echo "  ${FASTQ_DIR}"
    echo
    echo "Please edit FASTQ_DIR in the USER SETTINGS section."
    exit 1
fi


# ============================================================
# CREATE OUTPUT DIRECTORIES
# ============================================================

mkdir -p \
    "${WORKDIR}" \
    "$(dirname "${HISAT2_INDEX_PREFIX}")" \
    "${OUT_TRIM}" \
    "${OUT_BAM}" \
    "${OUT_PORTCULLIS}"


# ============================================================
# PRINT RUN INFORMATION
# ============================================================

echo "============================================================"
echo "RNA-seq alignment and Portcullis pipeline started"
echo "============================================================"
echo "Working directory before pipeline start:"
pwd
echo
echo "Hostname:"
hostname
echo
echo "Start time:"
date
echo
echo "Reference genome:"
echo "  ${REF_GENOME}"
echo
echo "Work directory:"
echo "  ${WORKDIR}"
echo
echo "Sample list:"
echo "  ${SAMPLE_LIST}"
echo
echo "FASTQ directory:"
echo "  ${FASTQ_DIR}"
echo
echo "HISAT2 index prefix:"
echo "  ${HISAT2_INDEX_PREFIX}"
echo
echo "Filtered FASTQ output:"
echo "  ${OUT_TRIM}"
echo
echo "BAM output:"
echo "  ${OUT_BAM}"
echo
echo "Portcullis output:"
echo "  ${OUT_PORTCULLIS}"
echo
echo "Threads:"
echo "  ${THREADS}"
echo "============================================================"


# ============================================================
# SANITY CHECKS
# ============================================================
#
# These commands print software paths and versions into the SLURM
# log file. They are useful for debugging and reproducibility.
#
# ============================================================

echo "==== SANITY CHECKS ===="

echo "fastp:"
which "${FASTP_COMMAND}" || true
"${FASTP_COMMAND}" --version || true

echo
echo "HISAT2:"
which hisat2
hisat2 --version | head -n 1

echo
echo "HISAT2 build:"
which hisat2-build
hisat2-build --version | head -n 1

echo
echo "SAMtools:"
which samtools
samtools --version | head -n 1

echo
echo "Portcullis:"
which portcullis
portcullis --version || true


# ============================================================
# STEP 1: QUALITY FILTERING WITH FASTP
# ============================================================
#
# fastp options used here:
#
# -q 20
#   Minimum base quality threshold.
#
# -l 75
#   Minimum read length after filtering.
#
# -i / -I
#   Input read 1 and read 2 files.
#
# -o / -O
#   Output filtered read 1 and read 2 files.
#
# ============================================================

echo "============================================================"
echo "STEP 1: Quality filtering with fastp"
echo "============================================================"

while read -r SAMPLE_ID; do
    [[ -z "${SAMPLE_ID}" ]] && continue
    [[ "${SAMPLE_ID}" =~ ^# ]] && continue

    R1="${FASTQ_DIR}/${SAMPLE_ID}_1.fastq.gz"
    R2="${FASTQ_DIR}/${SAMPLE_ID}_2.fastq.gz"

    OUT1="${OUT_TRIM}/${SAMPLE_ID}_R1.filt.fq.gz"
    OUT2="${OUT_TRIM}/${SAMPLE_ID}_R2.filt.fq.gz"

    if [[ ! -f "${R1}" ]]; then
        echo "ERROR: Read 1 FASTQ file not found for sample ${SAMPLE_ID}:"
        echo "  ${R1}"
        exit 1
    fi

    if [[ ! -f "${R2}" ]]; then
        echo "ERROR: Read 2 FASTQ file not found for sample ${SAMPLE_ID}:"
        echo "  ${R2}"
        exit 1
    fi

    echo "Processing sample: ${SAMPLE_ID}"

    "${FASTP_COMMAND}" \
        -q 20 \
        -l 75 \
        -i "${R1}" \
        -I "${R2}" \
        -o "${OUT1}" \
        -O "${OUT2}"

done < "${SAMPLE_LIST}"


# ============================================================
# STEP 2: BUILD HISAT2 INDEX
# ============================================================
#
# The HISAT2 index is created from the repeat-masked reference
# genome. The index files are written using HISAT2_INDEX_PREFIX.
#
# ============================================================

echo "============================================================"
echo "STEP 2: Building HISAT2 index"
echo "============================================================"

hisat2-build \
    -p "${THREADS}" \
    "${REF_GENOME}" \
    "${HISAT2_INDEX_PREFIX}"


# ============================================================
# STEP 3: ALIGN READS AND PROCESS BAM FILES
# ============================================================
#
# HISAT2 options used here:
#
# -q
#   Input files are FASTQ format.
#
# --dta-cufflinks
#   Reports alignments tailored for transcript assemblers such as
#   Cufflinks/StringTie. This can be useful for annotation workflows.
#
# -p
#   Number of threads.
#
# -x
#   HISAT2 index prefix.
#
# -1 / -2
#   Paired-end filtered FASTQ files.
#
# SAMtools is then used to:
#   1. Convert SAM to BAM.
#   2. Sort BAM.
#   3. Create a CSI index for the sorted BAM.
#
# ============================================================

echo "============================================================"
echo "STEP 3: Aligning reads with HISAT2 and processing BAM files"
echo "============================================================"

while read -r SAMPLE_ID; do
    [[ -z "${SAMPLE_ID}" ]] && continue
    [[ "${SAMPLE_ID}" =~ ^# ]] && continue

    R1="${OUT_TRIM}/${SAMPLE_ID}_R1.filt.fq.gz"
    R2="${OUT_TRIM}/${SAMPLE_ID}_R2.filt.fq.gz"

    SAM="${OUT_BAM}/${SAMPLE_ID}.sam"
    BAM_OUT="${OUT_BAM}/${SAMPLE_ID}.bam"
    SORTED_BAM="${OUT_BAM}/${SAMPLE_ID}.sorted.bam"
    TMP_DIR="${OUT_BAM}/${SAMPLE_ID}.tmp"

    echo "Aligning sample: ${SAMPLE_ID}"

    hisat2 \
        -q \
        --dta-cufflinks \
        -p "${THREADS}" \
        -x "${HISAT2_INDEX_PREFIX}" \
        -1 "${R1}" \
        -2 "${R2}" \
        -S "${SAM}"

    echo "Converting SAM to BAM for sample: ${SAMPLE_ID}"

    samtools view \
        -b \
        -o "${BAM_OUT}" \
        "${SAM}"

    echo "Sorting BAM for sample: ${SAMPLE_ID}"

    mkdir -p "${TMP_DIR}"

    samtools sort \
        -o "${SORTED_BAM}" \
        -T "${TMP_DIR}/aln.sorted" \
        --threads "${THREADS}" \
        -m 10G \
        "${BAM_OUT}"

    echo "Indexing BAM for sample: ${SAMPLE_ID}"

    samtools index \
        -c \
        "${SORTED_BAM}"

    # Remove intermediate SAM and unsorted BAM files to save space.
    rm -f "${SAM}" "${BAM_OUT}"

done < "${SAMPLE_LIST}"


# ============================================================
# STEP 4: INDEX REFERENCE FASTA
# ============================================================
#
# Portcullis requires an indexed reference genome FASTA.
# samtools faidx creates a .fai index file.
#
# ============================================================

echo "============================================================"
echo "STEP 4: Indexing reference FASTA"
echo "============================================================"

samtools faidx "${REF_GENOME}"


# ============================================================
# STEP 5: RUN PORTCULLIS
# ============================================================
#
# Portcullis is used to detect and filter splice junctions from
# RNA-seq alignments.
#
# Portcullis steps:
#
# 1. prep
#    Prepares alignments and genome information.
#
# 2. junc
#    Detects splice junctions.
#
# 3. filt
#    Filters splice junctions.
#
# 4. bamfilt
#    Filters the BAM file using the passed splice junctions.
#
# Output:
#   For each sample, this produces a junction-filtered BAM file
#   that can be used as RNA-seq evidence in downstream annotation.
#
# ============================================================

echo "============================================================"
echo "STEP 5: Running Portcullis"
echo "============================================================"

while read -r SAMPLE_ID; do
    [[ -z "${SAMPLE_ID}" ]] && continue
    [[ "${SAMPLE_ID}" =~ ^# ]] && continue

    PREP_DIR="${OUT_PORTCULLIS}/1_prep/${SAMPLE_ID}"
    JUNC_DIR="${OUT_PORTCULLIS}/2_junc/${SAMPLE_ID}"
    FILT_DIR="${OUT_PORTCULLIS}/3_filt/${SAMPLE_ID}"
    BAM_FILT_DIR="${OUT_PORTCULLIS}/4_BAM_filt"
    BAM_FILT="${BAM_FILT_DIR}/${SAMPLE_ID}.junc_filt.bam"

    mkdir -p "${BAM_FILT_DIR}"

    SORTED_BAM="${OUT_BAM}/${SAMPLE_ID}.sorted.bam"

    echo "Preparing Portcullis for sample: ${SAMPLE_ID}"

    portcullis prep \
        --use_csi \
        -o "${PREP_DIR}" \
        "${REF_GENOME}" \
        "${SORTED_BAM}"

    echo "Detecting junctions with Portcullis for sample: ${SAMPLE_ID}"

    portcullis junc \
        --use_csi \
        -t "${THREADS}" \
        -o "${JUNC_DIR}" \
        "${PREP_DIR}"

    echo "Filtering junctions with Portcullis for sample: ${SAMPLE_ID}"

    portcullis filt \
        -t "${THREADS}" \
        -o "${FILT_DIR}" \
        "${PREP_DIR}" \
        "${JUNC_DIR}.junctions.tab"

    echo "Filtering BAM with Portcullis for sample: ${SAMPLE_ID}"

    portcullis bamfilt \
        --use_csi \
        -o "${BAM_FILT}" \
        "${FILT_DIR}.pass.junctions.tab" \
        "${PREP_DIR}/portcullis.sorted.alignments.bam"

done < "${SAMPLE_LIST}"


# ============================================================
# FINISH
# ============================================================

echo "============================================================"
echo "RNA-seq alignment and Portcullis pipeline completed"
echo "End time:"
date
echo "============================================================"
