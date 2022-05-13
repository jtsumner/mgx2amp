#!/bin/sh
#SBATCH -A p31588
#SBATCH -p short
#SBATCH -N 1
#SBATCH -n 17
#SBATCH -t 02:00:00
#SBATCH --mem=20gb
#SBATCH --job-name="run_fastp_metagenomics"

#load modules
module purge all
module load anaconda3
module load fastqc
module load multiqc
# activate conda env with fasp

# Set working directory
cd $SLURM_SUBMIT_DIR

# The command to execute:

# For timestamp logs
timestamp=$(date +%d_%m_%Y_%H_%M_%S)


# For fastp qc analysis
for dire in $(ls -d Misharin18)
do
	cd ${SLURM_SUBMIT_DIR}/${dire}
	source activate seq_processing

	for i in $(ls *R1_001.fastq.gz)
	do
		i_sub=$(echo $i | cut -d "_" -f 1-3)
		for j in $(ls *R2_001.fastq.gz)
		do
			j_sub=$(echo $j | cut -d "_" -f 1-3)
			if [[ $i_sub == $j_sub ]]
			then
				echo "${i_sub}	${j_sub}"
				fastp -i ${i} -I ${j} --out1 ${i_sub}_fastp_R1.fastq.gz --out2 ${j_sub}_fastp_R2.fastq.gz --detect_adapter_for_pe --thread 16 --length_required 50

			fi

		done

	done

	source deactivate

	# To move FASTP outputs into new directory

	trim_dir="./trimmed_fastp_merged_${timestamp}"
	if [ -d $trim_dir ]
	then
		echo "Directory ${trim_dir} exists" 
	else
		mkdir ${trim_dir} 
		echo "Directory ${trim_dir} now exists"
	fi

	mv *fastp-* ${trim_dir}/
	mv fastp.html fastp.json ${trim_dir}/

	cd ${trim_dir}/

	# For fastqc analysis
	fastqc -t 12 *fq.gz

	# To move fastqc data
	fastqc_dir=./fastqc_${timestamp}
	if [ -d ${fastqc_dir} ]
	then		echo "Directory ${fastqc_dir} exists" 
		echo "Directory ${fastqc_dir} exists" 
	else
		mkdir ${fastqc_dir}
		echo "Directory ${fastqc_dir} now exists"
	fi

	mv *fastqc.html ${fastqc_dir}
	mv *fastqc.zip ${fastqc_dir}

	cd ${fastqc_dir}
	multiqc .
	cd $SLURM_SUBMIT_DIR

done


