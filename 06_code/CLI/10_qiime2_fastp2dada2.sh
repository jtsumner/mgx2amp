#!/bin/bash
#SBATCH -A p31588
#SBATCH -p short
#SBATCH -t 04:00:00
#SBATCH -N 1
#SBATCH -n 20
#SBATCH --mem=100G 
#SBATCH --job-name="qiime2"
#SBATCH --output=%x.slurmlog.out
#SBATCH --error=%x.slurmlog.err
#SBATCH --mail-user=jacksumner2026@u.northwestern.edu
#SBATCH --mail-type=BEGIN,END,FAIL,REQUEUE

# Load modules
module purge all
module load qiime2/2021.11

# Requirements for this script:
# 1. 16S reads must be merged/joined first using fastp
# 2. Silva database must be in the base path under directory qiime2_silvaDB
# 3. Must have already prepared manifest files + sample metadata files, set in basedir


# Set base path (wd) for data. QIIME2 requires absolute paths
base_path="/projects/b1042/HartmannLab/jack/Misharin18_v3/amplicon_analysis"



##############################
# STEP 1: Import data. This script takes merged ("joined") PE reads QC'ed with fastp.
echo "STEP 1: Import Data"

qiime tools import \
  --input-path "${base_path}/fp-manifest-v3" \
  --output-path "${base_path}/qiime2_out/fp-joined-demux.qza" \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-format PairedEndFastqManifestPhred33V2



##############################
# STEP 2: Summarize read data
echo "STEP 2: Summarize read data"

qiime demux summarize \
  --i-data "${base_path}/qiime2_out/fp-joined-demux.qza" \
  --o-visualization "${base_path}/qiime2_out/fp-joined-demux.qzv"



##############################
# STEP 3: Cluster ASVs with Deblur
echo "STEP 3: Cluster ASVs with Deblue"

export TMPDIR="${base_path}/tmp_deblur"    # Delete between re-runs

# Clustering
#qiime deblur denoise-16S \
#  --i-demultiplexed-seqs "${base_path}/qiime2_out/fp-joined-demux.qza" \
#  --p-trim-length 465 \
#  --p-jobs-to-start 19 \
#  --p-sample-stats \
#  --o-representative-sequences "${base_path}/qiime2_out/rep-seqs.qza" \
#  --o-table "${base_path}/qiime2_out/table.qza" \
#  --o-stats "${base_path}/qiime2_out/deblur-stats.qza" \
#  --output-dir "${base_path}/qiime2_out/tmp_deblur" \
#  --verbose

# Prepare visuals
#qiime deblur visualize-stats \
#  --i-deblur-stats "${base_path}/qiime2_out/deblur-stats.qza" \
#  --o-visualization "${base_path}/qiime2_out/deblur-stats.qzv"

#mv rep-seqs-deblur.qza rep-seqs.qza
#mv table-deblur.qza table.qza

qiime dada2 denoise-paired \
  --i-demultiplexed-seqs "${base_path}/qiime2_out/fp-joined-demux.qza" \
  --p-trunc-len-f 0 \
  --p-trunc-len-r 0 \
  --o-representative-sequences "${base_path}/qiime2_out/rep-seqs.qza" \
  --o-table "${base_path}/qiime2_out/table.qza" \
  --p-n-threads 20 \
  --o-denoising-stats "${base_path}/qiime2_out/stats.qza"

qiime metadata tabulate \
  --m-input-file "${base_path}/qiime2_out/stats.qza" \
  --o-visualization "${base_path}/qiime2_out/stats.qzv"

#mv rep-seqs-dada2.qza rep-seqs.qza
#mv table-dada2.qza table.qza



##############################
# STEP 4: Distill feature tables
echo "STEP 4: Distill feature tables"

qiime feature-table summarize \
  --i-table "${base_path}/qiime2_out/table.qza" \
  --o-visualization "${base_path}/qiime2_out/table.qzv" \
  --m-sample-metadata-file "${base_path}/sample-metadata.tsv"

qiime feature-table tabulate-seqs \
  --i-data "${base_path}/qiime2_out/rep-seqs.qza" \
  --o-visualization "${base_path}/qiime2_out/rep-seqs.qzv"



##############################
# STEP 5: Construct phylogenetic tree
echo "STEP 5: Cluster phylogenetic tree"

qiime phylogeny align-to-tree-mafft-fasttree \
  --i-sequences "${base_path}/qiime2_out/rep-seqs.qza" \
  --o-alignment "${base_path}/qiime2_out/aligned-rep-seqs.qza" \
  --o-masked-alignment "${base_path}/qiime2_out/masked-aligned-rep-seqs.qza" \
  --o-tree "${base_path}/qiime2_out/unrooted-tree.qza" \
  --o-rooted-tree "${base_path}/qiime2_out/rooted-tree.qza" \
  --p-n-threads 20



##############################
# STEP 6: Quantify diversity metrics
echo "STEP 6: Quantify diversity metrics"

qiime diversity core-metrics-phylogenetic \
  --i-phylogeny "${base_path}/qiime2_out/rooted-tree.qza" \
  --i-table "${base_path}/qiime2_out/table.qza" \
  --p-sampling-depth 500 \
  --m-metadata-file "${base_path}/sample-metadata.tsv" \
  --output-dir "${base_path}/qiime2_out/core-metrics-results" \
  --p-n-jobs-or-threads 20

qiime diversity alpha-group-significance \
  --i-alpha-diversity "${base_path}/qiime2_out/core-metrics-results/faith_pd_vector.qza" \
  --m-metadata-file "${base_path}/sample-metadata.tsv" \
  --o-visualization "${base_path}/qiime2_out/core-metrics-results/faith-pd-group-significance.qzv"

qiime diversity alpha-group-significance \
  --i-alpha-diversity "${base_path}/qiime2_out/core-metrics-results/evenness_vector.qza" \
  --m-metadata-file "${base_path}/sample-metadata.tsv" \
  --o-visualization "${base_path}/qiime2_out/core-metrics-results/evenness-group-significance.qzv"



##############################
# STEP 7: Assign Taxonomy
echo "STEP 7: Assign Taxonomy"

qiime feature-classifier classify-consensus-vsearch \
  --i-query "${base_path}/qiime2_out/rep-seqs.qza" \
  --i-reference-reads "${base_path}/qiime2_silvaDB/silva-138-99-seqs.qza" \
  --i-reference-taxonomy "${base_path}/qiime2_silvaDB/silva-138-99-tax.qza" \
  --p-threads 20 \
  --o-classification "${base_path}/qiime2_out/taxonomy.qza"

qiime metadata tabulate \
  --m-input-file "${base_path}/qiime2_out/taxonomy.qza" \
  --o-visualization "${base_path}/qiime2_out/taxonomy.qzv"



##############################
# STEP 8: Abundance Barplot
echo "STEP 8: Abundance Barplot"

qiime taxa barplot \
  --i-table "${base_path}/qiime2_out/table.qza" \
  --i-taxonomy "${base_path}/qiime2_out/taxonomy.qza" \
  --m-metadata-file "${base_path}/sample-metadata.tsv" \
  --o-visualization "${base_path}/qiime2_out/taxa-bar-plots.qzv"


##############################
# STEP 9: Alpha rarefaction
echo "STEP 9: Alpha rarefaction"

qiime diversity alpha-rarefaction \
  --i-table "${base_path}/qiime2_out/table.qza" \
  --i-phylogeny "${base_path}/qiime2_out/rooted-tree.qza" \
  --p-max-depth 4000 \
  --m-metadata-file "${base_path}/sample-metadata.tsv" \
  --o-visualization "${base_path}/qiime2_out/alpha-rarefaction.qzv"


