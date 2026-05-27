#!/usr/bin/env bash
#SBATCH --job-name=repeatmasker
#SBATCH --cpus-per-task=32
#SBATCH --mem=100G
#SBATCH --time=240:00:00
#SBATCH --output=%x.%N.%j.out
#SBATCH --error=%x.%N.%j.err

set -euo pipefail

# ------------------------------------------------------------
# RepeatMasker pipeline using the Dfam TETools Docker image
#
# Requirements:
#   - SLURM
#   - Docker
#   - Genome assembly FASTA file
#   - Custom repeat library FASTA file
#
# Usage:
#   sbatch run_repeatmasker.sh genome.fasta repeat_library.fa
#
# Example:
#   sbatch run_repeatmasker.sh my_genome.fasta my_repeats.fa
# ------------------------------------------------------------

GENOME_FASTA="${1:-genome.fasta}"
REPEAT_LIBRARY="${2:-repeat_library.fa}"
THREADS="${SLURM_CPUS_PER_TASK:-32}"

if [[ ! -f "${GENOME_FASTA}" ]]; then
    echo "ERROR: Genome FASTA file not found: ${GENOME_FASTA}"
    echo "Usage: sbatch $0 genome.fasta repeat_library.fa"
    exit 1
fi

if [[ ! -f "${REPEAT_LIBRARY}" ]]; then
    echo "ERROR: Repeat library file not found: ${REPEAT_LIBRARY}"
    echo "Usage: sbatch $0 genome.fasta repeat_library.fa"
    exit 1
fi

echo "--- RepeatMasker pipeline started ---"
echo "Genome FASTA: ${GENOME_FASTA}"
echo "Repeat library: ${REPEAT_LIBRARY}"
echo "Threads: ${THREADS}"

docker run --rm \
    -v "$(pwd)":/data \
    -w /data \
    dfam/tetools:latest \
    bash -c "
        set -euo pipefail

        echo '--- Running RepeatMasker ---'

        RepeatMasker \
            -a \
            -gff \
            -s \
            -pa '${THREADS}' \
            -lib '${REPEAT_LIBRARY}' \
            '${GENOME_FASTA}'

        echo '--- RepeatMasker pipeline completed ---'
    "
