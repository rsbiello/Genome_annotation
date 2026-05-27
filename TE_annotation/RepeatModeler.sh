#!/usr/bin/env bash
#SBATCH --job-name=repeatmodeler
#SBATCH --cpus-per-task=32
#SBATCH --mem=500G
#SBATCH --time=240:00:00
#SBATCH --output=%x.%N.%j.out
#SBATCH --error=%x.%N.%j.err
#SBATCH --partition=bigmem

set -euo pipefail

# ============================================================
# RepeatModeler pipeline using the Dfam TETools Docker image
# ============================================================
#
# This script runs RepeatModeler on a genome assembly to build
# a de novo repeat library.
#
# The script is designed to be generic and reusable.
# To use it, edit the variables in the "USER SETTINGS" section
# below, then submit the script with:
#
#   sbatch run_repeatmodeler.sh
#
# Requirements:
#   1. A working SLURM environment.
#   2. Docker installed and available on the compute node.
#   3. A genome assembly FASTA file.
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
#   Directory where RepeatModeler output files will be written.
#
# DATABASE_NAME:
#   Name used by BuildDatabase and RepeatModeler.
#   This can be any simple name without spaces.
#
# THREADS:
#   Number of CPU threads to use.
#   This should usually match the SLURM --cpus-per-task value.
#
# TETOOLS_IMAGE:
#   Docker image used to run RepeatModeler.
#   The Dfam TETools image includes RepeatModeler and related
#   transposable element annotation tools.
#
# ============================================================

GENOME_FASTA="/path/to/genome.fasta"
OUTPUT_DIR="/path/to/repeatmodeler_output"
DATABASE_NAME="repeatmodeler_db"
THREADS="${SLURM_CPUS_PER_TASK:-32}"
TETOOLS_IMAGE="dfam/tetools:latest"


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
echo "RepeatModeler pipeline started"
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
echo "Output directory:"
echo "  ${OUTPUT_DIR}"
echo
echo "Database name:"
echo "  ${DATABASE_NAME}"
echo
echo "Threads:"
echo "  ${THREADS}"
echo
echo "Docker image:"
echo "  ${TETOOLS_IMAGE}"
echo "============================================================"


# ============================================================
# PREPARE PATHS FOR DOCKER
# ============================================================
#
# Docker needs access to the input genome and output directory.
#
# This script mounts:
#   - The directory containing the genome FASTA file
#   - The output directory
#
# Inside the Docker container, these directories are available as:
#   /genome
#   /output
#
# The genome directory is mounted as read-only because the input
# FASTA file should not be modified.
#
# The output directory is mounted as writable because RepeatModeler
# will write database files and results there.
#
# ============================================================

GENOME_DIR="$(dirname "$(readlink -f "${GENOME_FASTA}")")"
GENOME_FILE="$(basename "${GENOME_FASTA}")"

OUTPUT_DIR_ABS="$(readlink -f "${OUTPUT_DIR}")"


# ============================================================
# RUN REPEATMODELER
# ============================================================
#
# Steps performed:
#
# 1. BuildDatabase
#    Creates a RepeatModeler database from the genome assembly.
#
# 2. RepeatModeler
#    Runs de novo repeat discovery using the database created
#    in the previous step.
#
# RepeatModeler options used here:
#
# -database
#   Name of the RepeatModeler database.
#
# -threads
#   Number of CPU threads.
#
# -LTRStruct
#   Enables structural discovery of LTR elements.
#
# ============================================================

docker run --rm \
    -v "${GENOME_DIR}":/genome:ro \
    -v "${OUTPUT_DIR_ABS}":/output \
    -w /output \
    "${TETOOLS_IMAGE}" \
    bash -c "
        set -euo pipefail

        echo '--- Building RepeatModeler database ---'

        BuildDatabase \
            -name '${DATABASE_NAME}' \
            '/genome/${GENOME_FILE}'

        echo '--- Running RepeatModeler ---'

        RepeatModeler \
            -database '${DATABASE_NAME}' \
            -threads '${THREADS}' \
            -LTRStruct

        echo '--- RepeatModeler pipeline completed ---'
    "


# ============================================================
# FINISH
# ============================================================

echo "============================================================"
echo "RepeatModeler pipeline completed"
echo "End time:"
date
echo "============================================================"
