#!/usr/bin/env bash
#SBATCH --job-name=parse_braker3
#SBATCH --partition=bigmem
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=500:00:00
#SBATCH --output=slurm.%N.%j.out
#SBATCH --error=slurm.%N.%j.err

set -euo pipefail

# ============================================================
# Parse BRAKER3 proteins and run BUSCO
# ============================================================
#
# This script parses the protein output from a BRAKER3 run.
#
# It performs the following steps:
#
#   1. Calculates protein lengths from the BRAKER3 protein FASTA.
#   2. Extracts gene IDs from transcript IDs.
#   3. Selects the longest transcript per gene.
#   4. Creates a protein FASTA file containing only the longest
#      transcript per gene.
#   5. Runs BUSCO on the longest-transcript protein set.
#
# This is useful for summarizing BRAKER3 gene prediction results
# and assessing protein completeness with BUSCO.
#
# The script is designed to be generic and reusable.
# To use it, edit the variables in the "USER SETTINGS" section
# below, then submit the script with:
#
#   sbatch parse_braker3_proteins_busco.sh
#
# Requirements:
#   1. A working SLURM environment.
#   2. BUSCO installed and available.
#   3. seqkit installed and available.
#   4. BRAKER3 protein output file, usually named braker.aa.
#   5. Internet access if BUSCO is run online.
#
# ============================================================

# ============================================================
# USER SETTINGS
# ============================================================
#
# Edit the variables below before submitting the job.
#
# WORKDIR:
#   Directory containing the BRAKER3 output files.
#
# PROTEIN_FASTA:
#   BRAKER3 protein FASTA file.
#   In many BRAKER3 runs this file is named braker.aa.
#
# SAMPLE_ID:
#   Sample or annotation name used as a prefix for output files.
#   Use a simple name without spaces.
#
# BUSCO_LINEAGE:
#   BUSCO lineage used to assess protein completeness.
#   Replace this placeholder with the lineage that best matches
#   the organism being annotated.
#
#   Examples:
#     - eukaryota_odb12
#     - metazoa_odb12
#     - fungi_odb12
#
#   A more specific lineage is usually preferred when available.
#
# THREADS:
#   Number of CPU threads to use.
#   This should usually match the SLURM --cpus-per-task value.
#
# BUSCO_MODE:
#   BUSCO analysis mode.
#   Use "proteins" for a protein FASTA file.
#
# ============================================================

WORKDIR="/path/to/braker3_output/braker3_run"
PROTEIN_FASTA="${WORKDIR}/braker.aa"
SAMPLE_ID="sample_braker3"
BUSCO_LINEAGE="your_busco_lineage_odb10"
THREADS="${SLURM_CPUS_PER_TASK:-8}"
BUSCO_MODE="proteins"

# ============================================================
# SOFTWARE SETUP
# ============================================================
#
# Edit this section depending on how BUSCO and seqkit are installed
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
# module load busco
# module load seqkit
#
# Option 3: Software already available
# If BUSCO and seqkit are already available in PATH, no changes
# are needed.
#
# ============================================================

# source /path/to/miniconda3/bin/activate annotation_env
# module load busco
# module load seqkit

# ============================================================
# CHECK INPUTS
# ============================================================

if [[ ! -d "${WORKDIR}" ]]; then
    echo "ERROR: Working directory not found:"
    echo "  ${WORKDIR}"
    echo
    echo "Please edit WORKDIR in the USER SETTINGS section."
    exit 1
fi

if [[ ! -f "${PROTEIN_FASTA}" ]]; then
    echo "ERROR: BRAKER3 protein FASTA file not found:"
    echo "  ${PROTEIN_FASTA}"
    echo
    echo "Please edit PROTEIN_FASTA in the USER SETTINGS section."
    exit 1
fi

if [[ "${BUSCO_LINEAGE}" == "your_busco_lineage" ]]; then
    echo "ERROR: BUSCO_LINEAGE is still set to the placeholder value."
    echo "Please replace it with an appropriate BUSCO lineage."
    echo "Examples: eukaryota_odb12, metazoa_odb12, fungi_odb12."
    exit 1
fi

# ============================================================
# MOVE TO WORKING DIRECTORY
# ============================================================

cd "${WORKDIR}"

# ============================================================
# PRINT RUN INFORMATION
# ============================================================

echo "============================================================"
echo "BRAKER3 protein parsing and BUSCO pipeline started"
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
echo "Protein FASTA:"
echo "  ${PROTEIN_FASTA}"
echo
echo "Sample ID:"
echo "  ${SAMPLE_ID}"
echo
echo "BUSCO lineage:"
echo "  ${BUSCO_LINEAGE}"
echo
echo "BUSCO mode:"
echo "  ${BUSCO_MODE}"
echo
echo "Threads:"
echo "  ${THREADS}"
echo "============================================================"

# ============================================================
# SANITY CHECKS
# ============================================================

echo "==== SANITY CHECKS ===="

echo "seqkit:"
which seqkit
seqkit version || true

echo
echo "BUSCO:"
which busco
busco --version || true

# ============================================================
# STEP 1: CALCULATE PROTEIN LENGTHS
# ============================================================
#
# This step creates a table with:
#
#   transcript_id    protein_length    sample_id
#
# The protein length is calculated directly from the FASTA file.
# This avoids needing a custom external Perl script.
#
# ============================================================

echo "============================================================"
echo "STEP 1: Calculating protein lengths"
echo "============================================================"

awk -v sample_id="${SAMPLE_ID}" '
    /^>/ {
        if (seq_id != "") {
            print seq_id "\t" length(seq) "\t" sample_id
        }
        seq_id = $1
        sub(/^>/, "", seq_id)
        seq = ""
        next
    }
    {
        seq = seq $0
    }
    END {
        if (seq_id != "") {
            print seq_id "\t" length(seq) "\t" sample_id
        }
    }
' "${PROTEIN_FASTA}" > "${SAMPLE_ID}.aa.transcript_lengths"

# ============================================================
# STEP 2: EXTRACT GENE IDS
# ============================================================
#
# BRAKER/AUGUSTUS transcript IDs often look like:
#
#   gene_id.transcript_id
#
# This step extracts the part before the first dot as the gene ID.
#
# If your transcript naming scheme is different, edit the cut command
# below to match your FASTA headers.
#
# ============================================================

echo "============================================================"
echo "STEP 2: Extracting gene IDs"
echo "============================================================"

cut -d "." -f1 "${SAMPLE_ID}.aa.transcript_lengths" \
    | sort -u \
    > "${SAMPLE_ID}.gene_IDs.txt"

# ============================================================
# STEP 3: PRINT BASIC PROTEIN STATISTICS
# ============================================================

echo "============================================================"
echo "STEP 3: Printing basic protein statistics"
echo "============================================================"

awk -v sample_id="${SAMPLE_ID}" '
    {
        sum += $2
    }
    END {
        if (NR > 0) {
            print sample_id " transcript count: " NR
            print sample_id " average protein length: " sum / NR
        }
    }
' "${SAMPLE_ID}.aa.transcript_lengths"

# ============================================================
# STEP 4: SELECT LONGEST TRANSCRIPT PER GENE
# ============================================================
#
# For each gene ID, this step selects the transcript with the
# longest protein sequence.
#
# Output:
#
#   SAMPLE_ID.LTPG_IDs.txt
#
# LTPG = longest transcript per gene.
#
# ============================================================

echo "============================================================"
echo "STEP 4: Selecting longest transcript per gene"
echo "============================================================"

while read -r GENE_ID; do
    [[ -z "${GENE_ID}" ]] && continue

    grep "^${GENE_ID}\." "${SAMPLE_ID}.aa.transcript_lengths" \
        | sort -k2,2rn \
        | head -n 1 \
        | cut -f1

done < "${SAMPLE_ID}.gene_IDs.txt" > "${SAMPLE_ID}.LTPG_IDs.txt"


# ============================================================
# STEP 5: EXTRACT LONGEST-TRANSCRIPT PROTEINS
# ============================================================
#
# seqkit is used to extract the selected protein IDs from the
# original BRAKER3 protein FASTA file.
#
# Output:
#
#   SAMPLE_ID.aa.LTPG.fa
#
# ============================================================

echo "============================================================"
echo "STEP 5: Extracting longest-transcript protein FASTA"
echo "============================================================"

seqkit grep \
    -f "${SAMPLE_ID}.LTPG_IDs.txt" \
    "${PROTEIN_FASTA}" \
    > "${SAMPLE_ID}.aa.LTPG.fa"


# ============================================================
# STEP 6: RUN BUSCO ONLINE
# ============================================================
#
# This script runs BUSCO online.
#
# Unlike offline BUSCO mode, this does not require a local BUSCO
# database path and does not use the --offline option.
#
# BUSCO will download the selected lineage automatically if it is
# not already available in the BUSCO download/cache directory.
#
# BUSCO options used here:
#
# -i
#   Input protein FASTA file.
#
# -o
#   BUSCO output name.
#
# -m
#   BUSCO mode. For protein FASTA files, use "proteins".
#
# -l
#   BUSCO lineage.
#
# -c
#   Number of CPU threads.
#
# ============================================================

echo "============================================================"
echo "STEP 6: Running BUSCO online"
echo "============================================================"

BUSCO_OUTPUT="busco.${BUSCO_LINEAGE}.${SAMPLE_ID}"

busco \
    -i "${SAMPLE_ID}.aa.LTPG.fa" \
    -o "${BUSCO_OUTPUT}" \
    -m "${BUSCO_MODE}" \
    -l "${BUSCO_LINEAGE}" \
    -c "${THREADS}"


# ============================================================
# FINISH
# ============================================================

echo "============================================================"
echo "BRAKER3 protein parsing and BUSCO pipeline completed"
echo "End time:"
date
echo "============================================================"
