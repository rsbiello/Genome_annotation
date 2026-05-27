#!/usr/bin/env bash
#SBATCH --job-name=repeatmodeler
#SBATCH --cpus-per-task=32
#SBATCH --mem=500G
#SBATCH --time=240:00:00
#SBATCH --output=%x.%N.%j.out
#SBATCH --error=%x.%N.%j.err
#SBATCH --partition=bigmem

set -euo pipefail

# ------------------------------------------------------------
# RepeatModeler pipeline using the Dfam TETools Docker image
#
# Requirements:
#   - SLURM
#   - Docker
#   - Input genome FASTA file in the working directory
#
# Usage:
#   sbatch run_repeatmodeler.sh genome.fasta database_name
#
# Example:
#   sbatch run_repeatmodeler.sh my_genome.fasta my_genome_db
# ------------------------------------------------------------

GENOME_FASTA="${1:-genome.fasta}"
DATABASE_NAME="${2:-repeatmodeler_db}"
THREADS="${SLURM_CPUS_PER_TASK:-32}"

if [[ ! -f "${GENOME_FASTA}" ]]; then
    echo "ERROR: Genome FASTA file not found: ${GENOME_FASTA}"
    echo "Usage: sbatch $0 genome.fasta database_name"
    exit 1
fi

echo "--- RepeatModeler pipeline started ---"
echo "Genome FASTA: ${GENOME_FASTA}"
echo "Database name: ${DATABASE_NAME}"
echo "Threads: ${THREADS}"

docker run --rm \
    -v "$(pwd)":/data \
    -w /data \
    dfam/tetools:latest \
    bash -c "
        set -euo pipefail

        echo '--- Building RepeatModeler database ---'
        BuildDatabase \
            -name '${DATABASE_NAME}' \
            '${GENOME_FASTA}'

        echo '--- Running RepeatModeler ---'
        RepeatModeler \
            -database '${DATABASE_NAME}' \
            -threads '${THREADS}' \
            -LTRStruct

        echo '--- RepeatModeler pipeline completed ---'
    "
