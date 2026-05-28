#!/usr/bin/env bash
#SBATCH --job-name=braker3
#SBATCH --partition=bigmem
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=160G
#SBATCH --time=500:00:00
#SBATCH --output=slurm.%N.%j.out
#SBATCH --error=slurm.%N.%j.err

set -euo pipefail

# ============================================================
# BRAKER3 gene prediction pipeline
# ============================================================
#
# This script runs BRAKER3 for structural gene prediction using:
#
#   1. A repeat-masked genome assembly
#   2. RNA-seq evidence as BAM files
#   3. Protein evidence as a FASTA file
#
# The workflow is useful for generating gene models for a genome
# annotation project after transposable element masking and RNA-seq
# alignment have been completed.
#
# The script is designed to be generic and reusable.
# To use it, edit the variables in the "USER SETTINGS" section
# below, then submit the script with:
#
#   sbatch run_braker3.sh
#
# Requirements:
#   1. A working SLURM environment.
#   2. BRAKER3.
#   3. GeneMark-ETP.
#   4. ProtHint.
#   5. AUGUSTUS.
#   6. compleasm.
#   7. A repeat-masked genome FASTA file.
#   8. RNA-seq BAM files, preferably splice-junction-filtered.
#   9. A protein evidence FASTA file.
#
# ============================================================

# ============================================================
# USER SETTINGS
# ============================================================
#
# Edit the variables below before submitting the job.
#
# GENOME_FASTA:
#   Path to the repeat-masked genome assembly FASTA file.
#
# RNA_BAM_FILES:
#   Comma-separated list of RNA-seq BAM files.
#   BRAKER expects multiple BAM files as one comma-separated string
#   with no spaces.
#
# PROTEIN_FASTA:
#   Protein evidence FASTA file used by ProtHint/BRAKER.
#   This can be a protein set from a related species or a curated
#   ortholog database.
#
# SPECIES_NAME:
#   Species name used internally by AUGUSTUS/BRAKER.
#   Use a simple unique name without spaces.
#
# WORKDIR:
#   Main directory where BRAKER output will be written.
#
# BRAKER_RUN_DIR:
#   Subdirectory created inside WORKDIR for this specific run.
#
# THREADS:
#   Number of CPU threads to use.
#   This should usually match the SLURM --cpus-per-task value.
#
# BUSCO_LINEAGE:
#   BUSCO lineage used by compleasm/BRAKER.
#   Replace this with the lineage appropriate for your organism.
#
# USE_EXISTING:
#   If set to "--useexisting", BRAKER will reuse existing files
#   from previous runs when possible.
#   Set this to an empty string "" for a fresh run.
#
# ============================================================

GENOME_FASTA="/path/to/repeat_masked_genome.fasta"
RNA_BAM_FILES="/path/to/sample1.junc_filt.bam,/path/to/sample2.junc_filt.bam"
PROTEIN_FASTA="/path/to/protein_evidence.fa"
SPECIES_NAME="my_species_braker3"
WORKDIR="/path/to/braker3_output"
BRAKER_RUN_DIR="braker3_run"
THREADS="${SLURM_CPUS_PER_TASK:-16}"
BUSCO_LINEAGE="your_busco_lineage"

# ============================================================
# SOFTWARE PATH SETTINGS
# ============================================================
#
# Edit these variables depending on how BRAKER3 and its dependencies
# are installed on your system.
#
# CONDA_ACTIVATE:
#   Path to the conda activation script.
#
# CONDA_ENV:
#   Name of the conda environment containing BRAKER3.
#
# GENEMARK_BIN:
#   Directory containing GeneMark executables.
#
# GENEMARK_TOOLS:
#   Directory containing GeneMark tools.
#
# COMPLEASM_PATH:
#   Path to the compleasm installation directory.
#
# PROTHINT_PATH:
#   Path to the ProtHint bin directory.
#
# AUGUSTUS_CONFIG_PATH:
#   Path to the writable AUGUSTUS config directory.
#   This should usually be a user-writable copy of the AUGUSTUS
#   config folder, not a read-only system directory.
#
# AUGUSTUS_BIN_PATH:
#   Path to the AUGUSTUS binary directory.
#
# ============================================================

CONDA_ACTIVATE="/path/to/miniconda3/bin/activate"
CONDA_ENV="braker3"
GENEMARK_BIN="/path/to/GeneMark-ETP/bin"
GENEMARK_TOOLS="/path/to/GeneMark-ETP/tools"
COMPLEASM_PATH="/path/to/compleasm_kit"
PROTHINT_PATH="/path/to/ProtHint/bin"
AUGUSTUS_CONFIG_PATH="/path/to/augustus/config"
AUGUSTUS_BIN_PATH="/path/to/augustus/bin"

# ============================================================
# SOFTWARE SETUP
# ============================================================

if [[ -f "${CONDA_ACTIVATE}" ]]; then
    source "${CONDA_ACTIVATE}" "${CONDA_ENV}"
else
    echo "ERROR: Conda activation script not found:"
    echo "  ${CONDA_ACTIVATE}"
    echo
    echo "Please edit CONDA_ACTIVATE in the SOFTWARE PATH SETTINGS section."
    exit 1
fi

export PATH="${GENEMARK_BIN}:${GENEMARK_TOOLS}:${COMPLEASM_PATH}:${PATH}"

# ============================================================
# CHECK INPUTS
# ============================================================

if [[ ! -f "${GENOME_FASTA}" ]]; then
    echo "ERROR: Genome FASTA file not found:"
    echo "  ${GENOME_FASTA}"
    exit 1
fi

if [[ ! -f "${PROTEIN_FASTA}" ]]; then
    echo "ERROR: Protein FASTA file not found:"
    echo "  ${PROTEIN_FASTA}"
    exit 1
fi

IFS=',' read -ra BAM_ARRAY <<< "${RNA_BAM_FILES}"

for BAM_FILE in "${BAM_ARRAY[@]}"; do
    if [[ ! -f "${BAM_FILE}" ]]; then
        echo "ERROR: RNA-seq BAM file not found:"
        echo "  ${BAM_FILE}"
        exit 1
    fi
done

if [[ ! -d "${PROTHINT_PATH}" ]]; then
    echo "ERROR: ProtHint path not found:"
    echo "  ${PROTHINT_PATH}"
    exit 1
fi

if [[ ! -d "${COMPLEASM_PATH}" ]]; then
    echo "ERROR: compleasm path not found:"
    echo "  ${COMPLEASM_PATH}"
    exit 1
fi

if [[ ! -d "${AUGUSTUS_CONFIG_PATH}" ]]; then
    echo "ERROR: AUGUSTUS config path not found:"
    echo "  ${AUGUSTUS_CONFIG_PATH}"
    exit 1
fi

if [[ ! -d "${AUGUSTUS_BIN_PATH}" ]]; then
    echo "ERROR: AUGUSTUS binary path not found:"
    echo "  ${AUGUSTUS_BIN_PATH}"
    exit 1
fi

# ============================================================
# CREATE OUTPUT DIRECTORY
# ============================================================

mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

# ============================================================
# PRINT RUN INFORMATION
# ============================================================

echo "============================================================"
echo "BRAKER3 gene prediction pipeline started"
echo "============================================================"
echo "Working directory:"
pwd
echo
echo "Hostname:"
hostname
echo
echo "Start time:"
date
echo
echo "Genome FASTA:"
echo "  ${GENOME_FASTA}"
echo
echo "RNA-seq BAM files:"
echo "  ${RNA_BAM_FILES}"
echo
echo "Protein FASTA:"
echo "  ${PROTEIN_FASTA}"
echo
echo "BRAKER working directory:"
echo "  ${BRAKER_RUN_DIR}"
echo
echo "Species name:"
echo "  ${SPECIES_NAME}"
echo
echo "BUSCO lineage:"
echo "  ${BUSCO_LINEAGE}"
echo
echo "Threads:"
echo "  ${THREADS}"
echo
echo "Use existing:"
echo "  ${USE_EXISTING}"
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

echo "BRAKER:"
which braker.pl
braker.pl --version || true

echo
echo "GeneMark:"
which gmes_petap.pl || true

echo
echo "ProtHint:"
ls "${PROTHINT_PATH}" || true

echo
echo "AUGUSTUS:"
ls "${AUGUSTUS_BIN_PATH}" || true

echo
echo "compleasm:"
ls "${COMPLEASM_PATH}" || true

# ============================================================
# RUN BRAKER3
# ============================================================
#
# BRAKER options used here:
#
# --genome
#   Repeat-masked genome assembly FASTA file.
#
# --workingdir
#   BRAKER output directory for this run.
#
# --PROTHINT_PATH
#   Path to ProtHint executables.
#
# --COMPLEASM_PATH
#   Path to compleasm installation.
#
# --AUGUSTUS_CONFIG_PATH
#   Writable AUGUSTUS configuration directory.
#
# --AUGUSTUS_BIN_PATH
#   Path to AUGUSTUS executables.
#
# --threads
#   Number of CPU threads.
#
# --gff3
#   Produces GFF3 output.
#
# --bam
#   RNA-seq BAM evidence.
#
# --prot_seq
#   Protein evidence FASTA file.
#
# --busco_lineage
#   BUSCO lineage used for compleasm-supported training.
#
# --species
#   Unique species name used by AUGUSTUS/BRAKER.
#
# --useexisting
#   Reuses existing intermediate results when possible.
#
# ============================================================

braker.pl \
    --genome="${GENOME_FASTA}" \
    --workingdir="${BRAKER_RUN_DIR}" \
    --PROTHINT_PATH="${PROTHINT_PATH}" \
    --COMPLEASM_PATH="${COMPLEASM_PATH}" \
    --AUGUSTUS_CONFIG_PATH="${AUGUSTUS_CONFIG_PATH}" \
    --AUGUSTUS_BIN_PATH="${AUGUSTUS_BIN_PATH}" \
    --threads="${THREADS}" \
    --gff3 \
    --bam="${RNA_BAM_FILES}" \
    --prot_seq="${PROTEIN_FASTA}" \
    --busco_lineage="${BUSCO_LINEAGE}" \
    --species="${SPECIES_NAME}"

# ============================================================
# FINISH
# ============================================================

echo "============================================================"
echo "BRAKER3 gene prediction pipeline completed"
echo "End time:"
date
echo "============================================================"
