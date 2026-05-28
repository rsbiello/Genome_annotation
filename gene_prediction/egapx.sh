#!/usr/bin/env bash
#SBATCH --job-name=egapx
#SBATCH --partition=bigmem
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --mem=640G
#SBATCH --time=500:00:00
#SBATCH --output=slurm.%N.%j.out
#SBATCH --error=slurm.%N.%j.err

set -euo pipefail

# ============================================================
# EGAPx genome annotation pipeline
# ============================================================
#
# This script runs EGAPx for eukaryotic genome annotation
# using SLURM, Nextflow, and Apptainer/Singularity.
#
# The script is designed to be generic and reusable.
# To use it, edit the variables in the "USER SETTINGS" section
# below, then submit the script with:
#
#   sbatch run_egapx.sh
#
# Requirements:
#   1. A working SLURM environment.
#   2. EGAPx installed locally.
#   3. A valid EGAPx input YAML file.
#   4. Nextflow.
#   5. Apptainer or Singularity.
#   6. Java compatible with the Nextflow version used.
#   7. A Conda or virtual environment containing the software
#      required to launch EGAPx.
#
# ============================================================


# ============================================================
# USER SETTINGS
# ============================================================
#
# Edit the variables below before submitting the job.
#
# BASE_DIR:
#   Main project directory for the EGAPx run.
#   Temporary files, output files, local cache, Nextflow files,
#   and logs will be written under this directory.
#
# EGAPX_DIR:
#   Path to the local EGAPx installation directory.
#
# EGAPX_YAML:
#   Path to the EGAPx input YAML file.
#   This file contains genome information, taxonomic metadata,
#   and input files required by EGAPx.
#
# EGAPX_UI:
#   Path to the EGAPx launcher script, usually named egapx.py.
#
# WORKDIR:
#   Nextflow working directory.
#   This can become very large, so it should be placed on a
#   scratch or high-capacity filesystem.
#
# OUTDIR:
#   Directory where EGAPx final outputs will be written.
#
# LOCAL_CACHE:
#   Directory used to store EGAPx support files downloaded before
#   the main run. Keeping a local cache allows the files to be reused
#   if the job is restarted.
#
# CONDA_ACTIVATE:
#   Path to the conda activation script.
#   Example: /path/to/miniconda3/bin/activate
#
# CONDA_ENV:
#   Name of the conda environment used to run EGAPx.
#
# EGAPX_VENV:
#   Optional Python virtual environment used by EGAPx.
#   Leave empty if no separate virtual environment is needed.
#
# JAVA_HOME_DIR:
#   Path to a Java installation compatible with Nextflow.
#
# NXF_VERSION:
#   Nextflow version to use.
#
# MAX_ATTEMPTS:
#   Number of times the pipeline should be attempted.
#   If the first run fails, later attempts use Nextflow resume mode.
#
# ============================================================

BASE_DIR="/path/to/egapx_project"
EGAPX_DIR="/path/to/egapx"
EGAPX_YAML="${BASE_DIR}/input.yaml"
EGAPX_UI="${EGAPX_DIR}/ui/egapx.py"

WORKDIR="${BASE_DIR}/work"
OUTDIR="${BASE_DIR}/output"
LOCAL_CACHE="${BASE_DIR}/local_cache"

CONDA_ACTIVATE="/path/to/miniconda3/bin/activate"
CONDA_ENV="egapx"

EGAPX_VENV="/path/to/egapx/venv/bin/activate"

JAVA_HOME_DIR="/path/to/java"

NXF_VERSION="23.10.1"
MAX_ATTEMPTS=3


# ============================================================
# CREATE REQUIRED DIRECTORIES
# ============================================================

export HOME="${BASE_DIR}"
export NXF_HOME="${HOME}/.nextflow"
export TMPDIR="${HOME}/tmp/${SLURM_JOB_ID:-manual_run}"

mkdir -p \
    "${NXF_HOME}" \
    "${TMPDIR}" \
    "${WORKDIR}" \
    "${OUTDIR}" \
    "${LOCAL_CACHE}"


# ============================================================
# NEXTFLOW SETTINGS
# ============================================================
#
# NXF_VER:
#   Selects the Nextflow version.
#
# NXF_HOME:
#   Places Nextflow files under the project directory instead of
#   the user's default home directory.
#
# NXF_ANSI_LOG=false:
#   Disables colored terminal output, which makes SLURM log files
#   easier to read.
#
# TMPDIR:
#   Temporary directory for this SLURM job.
#
# ============================================================

export NXF_VER="${NXF_VERSION}"
export NXF_ANSI_LOG=false


# ============================================================
# APPTAINER / SINGULARITY CACHE SETTINGS
# ============================================================
#
# Container images and temporary files can require a large amount
# of disk space. These variables place Apptainer/Singularity cache
# and temporary directories under the project directory.
#
# This helps avoid filling the user's default home directory.
#
# ============================================================

export NXF_APPTAINER_CACHEDIR="${HOME}/.apptainer_nxf_cache"
export APPTAINER_CACHEDIR="${HOME}/.apptainer_cache"
export APPTAINER_TMPDIR="${TMPDIR}/apptainer_tmp"

# Some software still expects Singularity variable names.
# These are set for compatibility.
export NXF_SINGULARITY_CACHEDIR="${NXF_APPTAINER_CACHEDIR}"

mkdir -p \
    "${NXF_APPTAINER_CACHEDIR}" \
    "${APPTAINER_CACHEDIR}" \
    "${APPTAINER_TMPDIR}"


# ============================================================
# SOFTWARE SETUP
# ============================================================
#
# Edit this section depending on how EGAPx and dependencies are
# installed on your system.
#
# Conda:
#   Activates the conda environment used to run EGAPx.
#
# Python virtual environment:
#   Some EGAPx installations may also use a separate virtual
#   environment. If not needed, leave EGAPX_VENV empty.
#
# Java:
#   Nextflow requires Java. JAVA_HOME and NXF_JAVA_HOME are set
#   so Nextflow uses the requested Java installation.
#
# ============================================================

if [[ -f "${CONDA_ACTIVATE}" ]]; then
    source "${CONDA_ACTIVATE}" "${CONDA_ENV}"
else
    echo "ERROR: Conda activation script not found:"
    echo "  ${CONDA_ACTIVATE}"
    echo
    echo "Please edit CONDA_ACTIVATE in the USER SETTINGS section."
    exit 1
fi

if [[ -n "${EGAPX_VENV}" ]]; then
    if [[ -f "${EGAPX_VENV}" ]]; then
        source "${EGAPX_VENV}"
    else
        echo "ERROR: EGAPx virtual environment activation script not found:"
        echo "  ${EGAPX_VENV}"
        echo
        echo "If no virtual environment is needed, set EGAPX_VENV=\"\"."
        exit 1
    fi
fi

if [[ -d "${JAVA_HOME_DIR}" ]]; then
    export JAVA_HOME="${JAVA_HOME_DIR}"
    export PATH="${JAVA_HOME}/bin:${PATH}"
    export NXF_JAVA_HOME="${JAVA_HOME}"
else
    echo "ERROR: Java directory not found:"
    echo "  ${JAVA_HOME_DIR}"
    echo
    echo "Please edit JAVA_HOME_DIR in the USER SETTINGS section."
    exit 1
fi


# ============================================================
# APPTAINER / SINGULARITY COMPATIBILITY WRAPPER
# ============================================================
#
# EGAPx or Nextflow may call the container engine using the command
# name "singularity".
#
# On systems where Apptainer is installed instead of Singularity,
# this wrapper creates a local "singularity" command that forwards
# all arguments to "apptainer".
#
# If your cluster already provides Singularity, this section can
# usually be left as-is or removed.
#
# ============================================================

mkdir -p "${HOME}/bin"

cat > "${HOME}/bin/singularity" <<'EOF'
#!/usr/bin/env bash
exec apptainer "$@"
EOF

chmod +x "${HOME}/bin/singularity"
export PATH="${HOME}/bin:${PATH}"


# ============================================================
# CHECK INPUTS
# ============================================================

if [[ ! -f "${EGAPX_YAML}" ]]; then
    echo "ERROR: EGAPx YAML input file not found:"
    echo "  ${EGAPX_YAML}"
    echo
    echo "Please edit EGAPX_YAML in the USER SETTINGS section."
    exit 1
fi

if [[ ! -f "${EGAPX_UI}" ]]; then
    echo "ERROR: EGAPx launcher script not found:"
    echo "  ${EGAPX_UI}"
    echo
    echo "Please edit EGAPX_UI or EGAPX_DIR in the USER SETTINGS section."
    exit 1
fi


# ============================================================
# PRINT RUN INFORMATION
# ============================================================

echo "============================================================"
echo "EGAPx pipeline started"
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
echo "Base directory:"
echo "  ${BASE_DIR}"
echo
echo "EGAPx directory:"
echo "  ${EGAPX_DIR}"
echo
echo "EGAPx YAML:"
echo "  ${EGAPX_YAML}"
echo
echo "EGAPx launcher:"
echo "  ${EGAPX_UI}"
echo
echo "Nextflow work directory:"
echo "  ${WORKDIR}"
echo
echo "Output directory:"
echo "  ${OUTDIR}"
echo
echo "Local cache:"
echo "  ${LOCAL_CACHE}"
echo
echo "Temporary directory:"
echo "  ${TMPDIR}"
echo
echo "Nextflow version:"
echo "  ${NXF_VER}"
echo
echo "Java home:"
echo "  ${JAVA_HOME}"
echo
echo "Maximum attempts:"
echo "  ${MAX_ATTEMPTS}"
echo "============================================================"


# ============================================================
# SANITY CHECKS
# ============================================================
#
# These commands print software versions and paths into the SLURM
# log file. They are useful for debugging and reproducibility.
#
# ============================================================

echo "==== SANITY CHECKS ===="

echo "Python:"
which python3
python3 -V

echo
echo "Nextflow:"
which nextflow || true
nextflow -version || true

echo
echo "Apptainer:"
which apptainer
apptainer --version

echo
echo "Singularity command:"
which singularity
singularity --version || true

echo
echo "Environment paths:"
echo "HOME=${HOME}"
echo "NXF_HOME=${NXF_HOME}"
echo "TMPDIR=${TMPDIR}"
echo "WORKDIR=${WORKDIR}"
echo "OUTDIR=${OUTDIR}"
echo "LOCAL_CACHE=${LOCAL_CACHE}"


# ============================================================
# PRE-DOWNLOAD EGAPx SUPPORT FILES
# ============================================================
#
# EGAPx may need to download support files before the main run.
#
# This step downloads those files into LOCAL_CACHE.
# A sentinel file named ".download_complete" is created only after
# the download finishes successfully.
#
# If the SLURM job stops during download, the sentinel file will not
# be created, and the next run will try downloading again.
#
# ============================================================

CACHE_READY="${LOCAL_CACHE}/.download_complete"

if [[ ! -f "${CACHE_READY}" ]]; then
    echo "==== LOCAL CACHE NOT FOUND OR INCOMPLETE ===="
    echo "Downloading EGAPx support files into:"
    echo "  ${LOCAL_CACHE}"

    python3 "${EGAPX_UI}" "${EGAPX_YAML}" \
        -dl \
        -lc "${LOCAL_CACHE}" \
        && touch "${CACHE_READY}" \
        || {
            echo "ERROR: EGAPx support file download failed. Aborting."
            exit 1
        }
else
    echo "==== REUSING EXISTING LOCAL CACHE ===="
    echo "  ${LOCAL_CACHE}"
fi


# ============================================================
# RUN EGAPx
# ============================================================
#
# EGAPx options used here:
#
# -e singularity
#   Tells EGAPx to run using Singularity-style containers.
#   On Apptainer systems, the wrapper above forwards the command
#   to Apptainer.
#
# -w
#   Nextflow working directory.
#
# -o
#   Output directory.
#
# -lc
#   Local cache directory containing EGAPx support files.
#
# -resume
#   Used automatically after a failed attempt so Nextflow can resume
#   from completed steps instead of restarting from the beginning.
#
# ============================================================

echo "==== STARTING EGAPx RUN ===="

RESUME_FLAG=""

for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do
    echo "==== EGAPx RUN ATTEMPT ${attempt}/${MAX_ATTEMPTS} ===="

    if python3 "${EGAPX_UI}" "${EGAPX_YAML}" \
        -e singularity \
        -w "${WORKDIR}" \
        -o "${OUTDIR}" \
        -lc "${LOCAL_CACHE}" \
        ${RESUME_FLAG}; then

        echo "==== EGAPx RUN COMPLETED SUCCESSFULLY ===="
        break
    fi

    EXIT_CODE=$?

    if [[ "${attempt}" -lt "${MAX_ATTEMPTS}" ]]; then
        echo "==== ATTEMPT ${attempt} FAILED WITH EXIT CODE ${EXIT_CODE} ===="
        echo "Retrying with Nextflow resume mode."
        RESUME_FLAG="-resume"
    else
        echo "==== ALL ${MAX_ATTEMPTS} ATTEMPTS FAILED ===="
        echo "Check logs in the EGAPx output and Nextflow directories:"
        echo "  ${OUTDIR}"
        echo "  ${WORKDIR}"
        exit "${EXIT_CODE}"
    fi
done


# ============================================================
# FINISH
# ============================================================

echo "============================================================"
echo "EGAPx pipeline completed"
echo "End time:"
date
echo "============================================================"
