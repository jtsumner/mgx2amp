#! /bin/bash
#SBATCH -A p31588
#SBATCH -p short
#SBATCH --job-name="bcl2fastq"
#SBATCH -t 02:00:00
#SBATCH -n 10
#SBATCH --mem-per-cpu=3gb


# Load modules
module load bcl2fastq

# Optional - Load conda envs

# Go to submit directory
cd $SLURM_SUBMIT_DIR

# Execute code


bcl2fastq -r 4 -p 8 -w 4 --sample-sheet SampleSheetUsed_v3.csv --use-bases-mask y300n,i8,i8,y300n




