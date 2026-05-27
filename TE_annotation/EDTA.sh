#!/usr/bin/env bash
#SBATCH --job-name=edta
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=96G
#SBATCH --time=500:00:00
#SBATCH --output=slurm.%N.%j.out
#SBATCH --error=slurm.%N.%j.err

set -euo pipefail

# ============================================================
# EDTA transposable element annotation pipeline
# ============================================================
#
# This script runs EDTA on a genome assembly using SLURM.
#
# The script is designed to be generic and reusable.
# To use it, edit the variables in the "USER SETTINGS" section
# below, then submit the script with:
#
#   sbatch run_edta.sh
#
# Requirements:
#   1. A working SLURM environment.
#   2. EDTA installed through Conda, an environment module,
#      or another local installation.
#   3. A genome assembly FASTA file.
#
# Notes:
#   - Cluster-specific paths should be avoided in GitHub examples.
#   - Do not include personal usernames, project directories,
#     or institution-specific storage paths.
#   - Users should replace the placeholder paths below with
#     paths from their own system.
#
# ============================================================


# ============================================================
# USER SETTINGS
# ============================================================
#
# Edit the variables below before submitting the job.
#
# GENOME_FASTA:
#   Path to the input genome assembly FASTA file.
#
# OUTPUT_DIR:
#   Directory where EDTA output files will be written.
#
# SPECIES:
#   Species option passed to EDTA.
#   Use "others" for non-model species or when no specific
#   EDTA species option is appropriate.
#
# THREADS:
#   Number of CPU threads to use.
#   This should usually match the SLURM --cpus-per-task value.
#
# EDTA_COMMAND:
#   Command used to run EDTA.
#   If EDTA.pl is available in your PATH after loading the
#   Conda environment or module, leave this as "EDTA.pl".
#   Otherwise, replace it with the full path to EDTA.pl.
#
# ============================================================

GENOME_FASTA="/path/to/genome.fasta"
OUTPUT_DIR="/path/to/edta_output"
SPECIES="others"
THREADS="${SLURM_CPUS_PER_TASK:-32}"
EDTA_COMMAND="EDTA.pl"


# ============================================================
# SOFTWARE SETUP
# ============================================================
#
# Edit this section depending on how EDTA is installed
# on your system.
#
# Option 1: Conda environment
# Uncomment and edit the following line if using Conda:
#
# source /path/to/miniconda3/bin/activate edta_env
#
# Option 2: Environment module
# Uncomment and edit the following line if using modules:
#
# module load EDTA
#
# Option 3: EDTA already available
# If EDTA.pl is already available in your PATH, no changes
# are needed in this section.
#
# ============================================================

# source /path/to/miniconda3/bin/activate edta_env
# module load EDTA


# ============================================================
# CHECK INPUTS
# ============================================================

if [[ ! -f "${GENOME_FASTA}" ]]; then
    echo "ERROR: Genome FASTA file not found:"
    echo "  ${GENOME_FASTA}"
    echo
    echo "Please edit GENOME_FASTA in the USER SETTINGS section."
    exit 1
fi

if [[ ! -d "${OUTPUT_DIR}" ]]; then
    echo "Output directory does not exist. Creating:"
    echo "  ${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}"
fi


# ============================================================
# PRINT RUN INFORMATION
# ============================================================

echo "============================================================"
echo "EDTA pipeline started"
echo "============================================================"
echo "Working directory before moving to output directory:"
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
echo "Output directory:"
echo "  ${OUTPUT_DIR}"
echo
echo "Species setting:"
echo "  ${SPECIES}"
echo
echo "Threads:"
echo "  ${THREADS}"
echo
echo "EDTA command:"
echo "  ${EDTA_COMMAND}"
echo "============================================================"


# ============================================================
# RUN EDTA
# ============================================================
#
# EDTA options used here:
#
# --genome
#   Input genome assembly FASTA file.
#
# --sensitive 1
#   Enables sensitive TE discovery.
#
# --anno 1
#   Runs whole-genome TE annotation after library construction.
#
# --force 1
#   Allows EDTA to overwrite previous results if they exist.
#
# --species
#   Species mode used by EDTA.
#   "others" is a generic option for non-model organisms.
#
# -t
#   Number of CPU threads.
#
# ============================================================

cd "${OUTPUT_DIR}"

"${EDTA_COMMAND}" \
    --genome "${GENOME_FASTA}" \
    --sensitive 1 \
    --anno 1 \
    --force 1 \
    --species "${SPECIES}" \
    -t "${THREADS}"


# ============================================================
# FINISH
# ============================================================

echo "============================================================"
echo "EDTA pipeline completed"
echo "End time:"
date
echo "============================================================"
