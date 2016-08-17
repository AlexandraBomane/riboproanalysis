#!/bin/bash

#########################################################################
## 								       ##
## This script will run all steps of a Ribosome Profiling analysis     ##
## It is executed in a Docker image				       ##
##								       ##
## Version 1.0.3						       ##
## Maintener : Alexandra Bomane 				       ##
##	       <alexandra.bomane@univ-paris-diderot.fr>	       	       ##
##								       ##
#########################################################################

########################## Variables section #############################
## Environment

# For debugging
#set -xv
# Allow to stop the program after an error, BUT doesn't display the error
#set -e

# Default variables
export SAMPLE_INDEX_ARRAY=(NONE)
export ANSWER_REMOVE_POLYN_READS=NO
export ANSWER_DEMULTIPLEXING=NO
export ANSWER_REMOVE_PCR_DUPLICATES=NO
export ANSWER_RNASEQ_COUNTING=NO
export ANSWER_KEEP_MULTIREAD=NO
export DIFFERENTIAL_ANALYSIS_PACKAGE=EDGER
export CHECK_DOCKER_IMAGES=NO

# Import configuration (.conf) file edited by th user : it erases default variables
source $1

# Check ANSWER_* variables

WORKING_ANSWER_REMOVE_POLYN_READS=${ANSWER_REMOVE_POLYN_READS^^}
if [ ! $WORKING_ANSWER_REMOVE_POLYN_READS = NO ]
then
	if [ ! $WORKING_ANSWER_REMOVE_POLYN_READS = YES ]
	then
		echo "Check your ANSWER_REMOVE_POLYN_READS parameter. It must be YES or NO."
		exit 1
	fi
fi

WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}
if [ ! $WORKING_ANSWER_DEMULTIPLEXING = NO ]
then
	if [ ! $WORKING_ANSWER_DEMULTIPLEXING = YES ]
	then
		echo "Check your ANSWER_DEMULTIPLEXING parameter. It must be YES or NO."
		exit 1
	fi
fi

WORKING_ANSWER_REMOVE_PCR_DUPLICATES=${ANSWER_REMOVE_PCR_DUPLICATES^^}
if [ ! $WORKING_ANSWER_REMOVE_PCR_DUPLICATES = NO ]
then
	if [ ! $WORKING_ANSWER_REMOVE_PCR_DUPLICATES = YES ]
	then
		echo "Check your ANSWER_REMOVE_PCR_DUPLICATES parameter. It must be YES or NO."
		exit 1
	fi
fi

WORKING_ANSWER_RNASEQ_COUNTING=${ANSWER_RNASEQ_COUNTING^^}
if [ ! $WORKING_ANSWER_RNASEQ_COUNTING = NO ]
then
	if [ ! $WORKING_ANSWER_RNASEQ_COUNTING = YES ]
	then
		echo "Check your ANSWER_RNASEQ_COUNTING parameter. It must be YES or NO."
		exit 1
	fi
fi

WORKING_ANSWER_KEEP_MULTIREAD=${ANSWER_KEEP_MULTIREAD^^}
if [ ! $WORKING_ANSWER_KEEP_MULTIREAD = NO ]
then
	if [ ! $WORKING_ANSWER_KEEP_MULTIREAD = YES ]
	then
		echo "Check your ANSWER_KEEP_MULTIREAD parameter."
		exit 1
	fi
fi

if [ ! $DIFFERENTIAL_ANALYSIS_PACKAGE = EDGER ]
then
	if [ ! $DIFFERENTIAL_ANALYSIS_PACKAGE = DESEQ2 ]
	then
		echo "Unavailable R package. Choose : EDGER or DESEQ2 (case sensitive)"
		exit 1
	fi
fi

## Scripts

# Main Bash script

MAIN_SCRIPT_CANONICAL_PATH=$(readlink -f $0) ## basename $0
CANONICAL_PATH=$(dirname $MAIN_SCRIPT_CANONICAL_PATH)

# Python and R scripts paths
export PYTHON_SCRIPTS_PATH="${CANONICAL_PATH}/PythonScripts/"
export R_SCRIPTS_PATH="${CANONICAL_PATH}/RScripts/"

# Python scripts
export PYTHON_SCRIPT_DEMULTIPLEXING="run_demultiplexing.py"
export PYTHON_SCRIPT_REMOVE_PCR_DUP="rmDupPCR.py"
export PYTHON_SCRIPT_REMOVE_BAD_IQF="remove_bad_reads_Illumina_passing_filter.py"
export PYTHON_SCRIPT_READ_LENGTH_DISTRIBUTION="read_length_distribution.py"
export PYTHON_SCRIPT_SAM_FILTERING="sam_file_filter.py"
export PYTHON_SCRIPT_LONGEST_TRANSCRIPT="get_longest_transcripts_from_ensembl_gtf.py"

# R scripts
export R_SCRIPT_BUILD_COUNTING_TABLE_RNASEQ="RNAseqCountDataMatrix.R"
export R_SCRIPT_BUILD_COUNTING_TABLE_RP="RPCountDataMatrix.R"
export R_SCRIPT_ANADIFF_BABEL="babel_RP_differentialAnalysis.R"
export R_SCRIPT_PERMT_TEST_BABEL="babel_RP_permutationTest.R"
export R_SCRIPT_ANADIFF_SARTOOLS_DESEQ2="script_DESeq2.R"
export R_SCRIPT_ANADIFF_SARTOOLS_EDGER="script_edgeR.R"

# Check mandatory parameters
if [ -z $SAMPLE_ARRAY ]
then
	echo "Give the sample array."
	exit 1
fi

if [ -z $ADAPTER_SEQUENCE_THREE_PRIME ]
then
	echo "Give the 3' adapter sequence."
	exit 1
fi

export WORKING_SAMPLE_ARRAY=$(echo ${SAMPLE_ARRAY[*]})

WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}
if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
then
	if [ -z $SAMPLE_INDEX_ARRAY ]
	then
		echo "Give your sample index array."
		exit 1
	fi
fi

WORKING_ANSWER_RNASEQ_COUNTING=${ANSWER_RNASEQ_COUNTING^^}
if [ $WORKING_ANSWER_RNASEQ_COUNTING = NO ]
then
	if [ -z $AUTHOR ]
	then
		$AUTHOR=UserName
	fi
fi

if [ $WORKING_ANSWER_RNASEQ_COUNTING = NO ]
then
	if [ -z $REFERENCE_CONDITION ]
	then
		echo "Give your reference (biological) condition."
		exit 1
	fi
fi

if [ -z $USER_IDS ]
then
	echo "Give your user ids : get them with USER_IDS=$(id -u):$(id -g) command."
	exit 1
fi

export WORKING_SAMPLE_ARRAY=$(echo ${SAMPLE_ARRAY[*]})

WORKING_SAMPLE_INDEX_ARRAY=$(echo ${SAMPLE_INDEX_ARRAY[*]})

export $WORKING_SAMPLE_INDEX_ARRAY

export SAMPLES=($(echo ${SAMPLE_ARRAY[@]%.fastq}))

WORKING_CONDITION_ARRAY=$(echo ${CONDITION_ARRAY[*]})

export SHELL=$(type -p bash)

export PROJECT_NAME=$(basename $1 .conf)

# Check arrays length

NB_SAMPLE=$(echo ${#SAMPLE_ARRAY[@]})

if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
then
	NB_SAMPLE_INDEX=$(echo ${#SAMPLE_INDEX_ARRAY[@]})
	if [ $NB_SAMPLE_INDEX -ne $NB_SAMPLE ]
	then
		echo "SAMPLE_INDEX_ARRAY and SAMPLE_ARRAY have different lengths. Check them."
		exit 1
	fi
fi

if [ $WORKING_ANSWER_RNASEQ_COUNTING = YES ]
then
	NB_CONDITION=$(echo ${#CONDITION_ARRAY[@]})
	if [ $NB_CONDITION -ne $NB_SAMPLE ]
	then
		echo "CONDITION_ARRAY and SAMPLE_ARRAY have different lengths. Check them."
		exit 1
	fi
fi

# Check Docker images (optional)

WORKING_CHECK_DOCKER_IMAGES=${CHECK_DOCKER_IMAGES^^}
if [ ! $WORKING_CHECK_DOCKER_IMAGES = NO ]
then
	if [ $WORKING_CHECK_DOCKER_IMAGES = YES ]
	then
		docker pull genomicpariscentre/fastqc:0.11.5
		docker pull genomicpariscentre/cutadapt:1.8.3
		docker pull genomicpariscentre/bowtie1:1.1.1
		docker pull genomicpariscentre/star:2.5.1b
		docker pull genomicpariscentre/samtools:0.1.19
		docker pull genomicpariscentre/gff3-ptools:0.4.0
		docker pull genomicpariscentre/htseq:0.6.1p1
		docker pull genomicpariscentre/babel:0.3-0
		docker pull genomicpariscentre/sartools:1.3.2
	else
		echo "Check your CHECK_DOCKER_IMAGES parameter. It must be YES or NO."
		exit 1
	fi
fi

### Tools parameters

	## 3' trimming : Cutadapt

export MIN_READ_LENGTH="25"
export MAX_READ_LENGTH="45"
export FILTER_MAX_N="2"

	## Align to rRNA sequences : Bowtie 1

# Bowtie 1 Options details : -q --> Fastq file as input ; --un --> write unaligned reads to another file (.fastq) ; -S --> write hits in SAM format
export BOWTIE_OPTIONS="-q -S --un"

	## Align to reference genome : STAR

export MAX_ALLOWED_MISMATCHES="0.06"	# alignment will be output only if its ratio of mismatches to *mapped* length is less than this value
export SEED_SEARCH_POINT="16"	# defines the search start point through the read - the read is split into pieces no longer than this value
export FILTER_SCORE_MIN="0"	# alignment will be output if its ratio of score to *read* length is higher than this value
export FILTER_MATCH_MIN="0.85"	# alignment will be output if its ratio of number of matched bases to *read* length is higher than this value
export MAX_LOCI_ALLOWED="1000"	# max number of loci anchors are allowed to map to
export MULTIMAP_SCORE_RANGE="0"	# the score range below the maximum score for multimapping alignments

	## HTSeq-Count

export MODE_FOR_MULTIPLE_FEATURES_READS="union"
export FEATURE_TYPE="CDS"
export IDATTR="gene_id"
export FILETYPE="bam"

###########################################################################

# We run the demultiplexing to get our Fastq files
# $1 = SAMPLE $2 = ADAPTER

demultiplexing()
	{
		WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}

		if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
		then
			if [ -z $PATH_TO_RAW_UNDEMULTIPLEXED_FILE ]
			then
				echo "Give the path to your multiplexed FASTQ file."
				exit 1
			fi

			LOGFILE="$1_demultiplexing.log"
			OUTFILE=$1_demultiplex.fastq

			if [ -s $OUTFILE ]
			then
				return 0
			else
				echo "Starting of demultiplexing :"

				$PYTHON_SCRIPT_DEMULTIPLEXING -i $PATH_TO_RAW_UNDEMULTIPLEXED_FILE -o $OUTFILE -a $2 > $LOGFILE

				if [ $? -ne 0 ]
				then
					echo "run_demultiplexing cannot run correctly ! Check your mutliplexed FASTQ path and your index adapter sequence."
					exit 1
				fi

				# Give rights to user
				chown $USER_IDS $OUTFILE
				chown $USER_IDS $LOGFILE

				echo "Log file : $LOGFILE generated."
				echo "End of demultiplexing."
			fi
		else
			return 0
		fi
	}

# We run FastQC to check input
# $1 = directory output ; $2 = input

fastqc_quality_control()
	{
		if [ "$(ls -1 $1)" ]
		then
			return 0
		else
			mkdir -p $1

			if [ $? -ne 0 ]
			then
				echo "$1 cannot be created !"
				exit 1
			fi
				echo "Starting of FastQC :"

				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/fastqc:0.11.5 -o $1 $2

				if [ $? -ne 0 ]
				then
					echo "FastQC cannot run correctly !"
					exit 1
				fi

				chown -R $USER_IDS $1

				echo "End of FastQC."
		fi
	}

export -f fastqc_quality_control

# We run FastQC to check our demultiplexing
# This function will be renamed raw_quality_control_report()

raw_quality_report()
	{
		WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}

		if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
		then
			INPUT_RAW_FASTQ="$1_demultiplex.fastq"
		else
			INPUT_RAW_FASTQ="${1}.fastq"
		fi

		DIR_RAW_FASTQ_REPORT="$1_raw_fastqc_report"

		if [ -s $INPUT_RAW_FASTQ ]
		then
			fastqc_quality_control $DIR_RAW_FASTQ_REPORT $INPUT_RAW_FASTQ
		else
			echo "$INPUT_RAW_FASTQ doesn't exist ! Check your SAMPLE_ARRAY."
			exit 1
		fi
	}

# We remove bas passing filter reads
removeBadIQF()
	{
		WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}

		if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
		then
			INPUT_FASTQ="$1_demultiplex.fastq"
		else
			INPUT_FASTQ="$1.fastq"
		fi

		LOGFILE="$1_rmIQF.log"
		RM_BADIQF_OUTPUT="$1_rmIQF.fastq"

		if [ -s $LOGFILE ] && [ -s $RM_BADIQF_OUTPUT ]
		then
			return 0
		else
			echo "Removing bad IQF :"

			$PYTHON_SCRIPT_REMOVE_BAD_IQF -i $INPUT_FASTQ -o $RM_BADIQF_OUTPUT > $LOGFILE

			if [ $? -ne 0 ]
			then
				echo "Removing bad IQF cannot run correctly !"
				exit 1
			fi

			chown $USER_IDS $RM_BADIQF_OUTPUT
			chown $USER_IDS $LOGFILE

			echo "Log file : $LOGFILE generated"
			echo "End of removing bad IQF"
		fi
	}

# Check remove bad passing filter
removeBadIQF_report()
	{
		RM_BADIQF_DIR="$1_rmIQF_report"
		RM_IQF_INPUT="$1_rmIQF.fastq"

		if [ -s $RM_IQF_INPUT ]
		then
			fastqc_quality_control $RM_BADIQF_DIR $RM_IQF_INPUT
		else
			echo "$RM_IQF_INPUT doesn't exist"
			exit 1
		fi
	}

# Remove PCR duplicates --> % Amplification in log file
removePCRduplicates()

	{
		WORKING_ANSWER_REMOVE_PCR_DUPLICATES=${ANSWER_REMOVE_PCR_DUPLICATES^^}

		if [ $WORKING_ANSWER_REMOVE_PCR_DUPLICATES = YES ]
		then
			LOGFILE="$1_rmPCR.log"
			RM_PCRDUP_OUTPUT="$1_rmPCR.fastq"
			RM_PCRDUP_INPUT="$1_rmIQF.fastq"

			if [ -s $RM_PCRDUP_INPUT ]
			then
				if [ -s $RM_PCRDUP_OUTPUT ] && [ -s $LOGFILE ]
				then
					return 0
				else
					echo "Removing PCR duplicates :"

					awk '{ i=(NR-1) % 4; tab[i]=$0 ; if (i==3) { print tab[1]"\t"tab[0]"\t"tab[3]"\t"tab[2]} }' $RM_PCRDUP_INPUT | sort | $PYTHON_SCRIPT_REMOVE_PCR_DUP -i $RM_PCRDUP_INPUT -o $RM_PCRDUP_OUTPUT > $LOGFILE

					if [ $? -ne 0 ]
					then
						echo "Cannot run rmExactDup_fastq.py correctly !"
						exit 1
					fi

					chown $USER_IDS $RM_PCRDUP_OUTPUT
					chown $USER_IDS $LOGFILE

					echo "Log file : $LOGFILE generated."
					echo "End of PCR duplicates removing."
				fi
			else
				echo "You need a file which was filtered on bad Illumina Qualitiy Filter (_rmIQF.fastq)."
				exit 1
			fi
		else
			return 0
		fi
	}

# We run the 5' trimming

Index_Adapter_trimming()
	{
		WORKING_ANSWER_REMOVE_PCR_DUPLICATES=${ANSWER_REMOVE_PCR_DUPLICATES^^}
		WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}

		if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
		then
			INDEX_TRIM_OUTPUT="$1_TrimIndex.fastq"

			if [ $WORKING_ANSWER_REMOVE_PCR_DUPLICATES = YES ]
			then
				INDEX_TRIM_INPUT="$1_rmPCR.fastq"
			else
				INDEX_TRIM_INPUT="$1_rmIQF.fastq"
			fi

			INDEX_LENGTH=$(expr length $2)

			LOGFILE="$1_TrimIndex.log"

			if [ -s $INDEX_TRIM_OUTPUT ]
			then
				return 0
			else

				echo "Index adapter trimming :"

				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/cutadapt:1.8.3 bash -c "cutadapt -u $INDEX_LENGTH -o $INDEX_TRIM_OUTPUT $INDEX_TRIM_INPUT" > $LOGFILE

				if [ $? -ne 0 ]
                                then
                                        echo "Index adapter trimming cannot run correctly !"
                                        exit 1
                                fi

				chown $USER_IDS $INDEX_TRIM_OUTPUT
				chown $USER_IDS $LOGFILE

				echo "Log file : $LOGFILE generated."
				echo "End of index adapter trimming."
			fi
		else
			return 0
		fi
	}

# We shake the 5' trimming

Index_Adapter_trimming_report()
	{
		WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}

		if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
		then
			DIR_INDEX_TRIM_FASTQC="$1_TrimIndex_report"
			INDEX_TRIM_INPUT="$1_TrimIndex.fastq"

			if [ -s $INDEX_TRIM_INPUT ]
			then
				fastqc_quality_control $DIR_INDEX_TRIM_FASTQC $INDEX_TRIM_INPUT
			else
				echo "$INDEX_TRIM_INPUT doesn't exist"
				exit 1
			fi
		fi
	}

# We run Cutadapt for the 3' trimming

ThreePrime_trimming()
	{
		WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}
		WORKING_ANSWER_REMOVE_PCR_DUPLICATES=${ANSWER_REMOVE_PCR_DUPLICATES^^}
		WORKING_ANSWER_REMOVE_POLYN_READS=${ANSWER_REMOVE_POLYN_READS^^}

		if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
		then
			THREEPRIME_TRIM_INPUT="$1_TrimIndex.fastq"
		else
			if [ $WORKING_ANSWER_REMOVE_PCR_DUPLICATES = 'YES' ]
			then
				THREEPRIME_TRIM_INPUT="$1_rmPCR.fastq"
			else
				THREEPRIME_TRIM_INPUT="$1_rmIQF.fastq"
			fi
		fi

		THREEPRIME_TRIM_OUTPUT="$1_ThreePrime_Trim.fastq"
		LOGFILE="$1_ThreePrimeTrim.log"

		if [ -s $THREEPRIME_TRIM_OUTPUT ] && [ -s $LOGFILE ]
		then
			return 0
		else
			echo "3' trimming :"

			if [ $WORKING_ANSWER_REMOVE_POLYN_READS = YES ]
			then
				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/cutadapt:1.8.3 bash -c "cutadapt -a $2 --discard-untrimmed --max-n $FILTER_MAX_N -o $THREEPRIME_TRIM_OUTPUT $THREEPRIME_TRIM_INPUT > $LOGFILE"
			else
				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/cutadapt:1.8.3 bash -c "cutadapt -a $2 --discard-untrimmed -o $THREEPRIME_TRIM_OUTPUT $THREEPRIME_TRIM_INPUT > $LOGFILE"
			fi

			if [ $? -ne 0 ]
                        then
                                echo "Cutadapt cannot run correctly !"
                                exit 1
                        fi

			chown $USER_IDS $THREEPRIME_TRIM_OUTPUT
			chown $USER_IDS $LOGFILE

			echo "Log file : $LOGFILE generated."
			echo "End of Cutadapt."
		fi
	}

# We shake the 3' trimming

ThreePrime_trimming_report()
	{
		DIR_THREEPRIME_TRIM_FASTQC="$1_ThreePrime_Trim_report"
		THREEPRIME_TRIM_INPUT="$1_ThreePrime_Trim.fastq"

		if [ -s $THREEPRIME_TRIM_INPUT ]
		then
			fastqc_quality_control $DIR_THREEPRIME_TRIM_FASTQC $THREEPRIME_TRIM_INPUT
		else
			echo "$THREEPRIME_TRIM_INPUT doesn't exist"
			exit 1
		fi
	}

Size_Selection()
	{
		WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}
		WORKING_ANSWER_REMOVE_PCR_DUPLICATES=${ANSWER_REMOVE_PCR_DUPLICATES^^}

		if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
		then
			THREEPRIME_TRIM_INPUT="$1_ThreePrime_Trim.fastq"
			SIZE_SELECT_OUTPUT="$1_SizeSelection.fastq"
			LOGFILE="$1_SizeSelection.log"
		else
			BASENAME=$(basename $1 .f*q)
			THREEPRIME_TRIM_INPUT="${BASENAME}_ThreePrime_Trim.fastq"
			SIZE_SELECT_OUTPUT="${BASENAME}_SizeSelection.fastq"
			LOGFILE="${BASENAME}_SizeSelection.log"
		fi

		if [ -s $THREEPRIME_TRIM_OUTPUT ] && [ -s $LOGFILE ]
		then
			return 0
		else
			echo "Size selection :"

			docker run --rm --volumes-from ribopro -w /home genomicpariscentre/cutadapt:1.8.3 bash -c "cutadapt -m $MIN_READ_LENGTH -M $MAX_READ_LENGTH -o $SIZE_SELECT_OUTPUT $THREEPRIME_TRIM_INPUT > $LOGFILE"

			if [ $? -ne 0 ]
                        then
                                echo "Cutadapt cannot run correctly !"
                                exit 1
                        fi

			chown $USER_IDS $SIZE_SELECT_OUTPUT
			chown $USER_IDS $LOGFILE


			echo "Log file : $LOGFILE generated."
			echo "End of Cutadapt."
		fi
	}

# We shake the size selection

Size_Selection_report()
	{
		DIR_SIZE_SELECT_FASTQC="$1_Size_Selection_report"
		SIZE_SELECT_INPUT="$1_SizeSelection.fastq"

		if [ -s $SIZE_SELECT_INPUT ]
		then
			fastqc_quality_control $DIR_SIZE_SELECT_FASTQC $SIZE_SELECT_INPUT
		else
			echo "$SIZE_SELECT_INPUT doesn't exist"
			exit 1
		fi
	}

# We run Bowtie 1 to align reads to rRNA sequences : we get unmapped reads for next steps and mapped reads to have length distribution (Python script using matplotlib)

align_To_R_RNA()
	{
		for sample in ${SAMPLE_ARRAY[*]}
		do
			echo "Starting of mapping to rRNA :"

			WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}

			if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
			then
				UNMAPPED_RNA_FASTQ_FILE="${sample}_no_rRNA.fastq"
				MAPPED_RNA_SAM_FILE="${sample}_rRNA_mapped.sam"
				LOGFILE_BOWTIE="${sample}_rRNA_mapping.log"
				INPUT_RNA_MAPPING="${sample}_SizeSelection.fastq"
			else
				BASENAME=$(basename $sample .fastq)
				UNMAPPED_RNA_FASTQ_FILE="${BASENAME}_no_rRNA.fastq"
				MAPPED_RNA_SAM_FILE="${BASENAME}_rRNA_mapped.sam"
				LOGFILE_BOWTIE="${BASENAME}_rRNA_mapping.log"
				INPUT_RNA_MAPPING="${BASENAME}_SizeSelection.fastq"
			fi

			# Check rRNA path mounted
			if [ ! "$(ls -1 /rRNAindexdirectory)" ]
			then
				echo "Mount your rRNA index path in /rRNAindexdirectory."
				exit 1
			fi

			rRNA_INDEX_BASENAME=$(echo $(basename /rRNAindexdirectory/*.1.ebwt | cut -f1 -d'.'))

			if [ -s $UNMAPPED_RNA_FASTQ_FILE ] && [ -s $MAPPED_RNA_SAM_FILE ]
			then
				echo "Mapping to rRNA already done for $sample"
				#return 0
			else
				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/bowtie1:1.1.1 bash -c "bowtie -p $(nproc) $BOWTIE_OPTIONS $UNMAPPED_RNA_FASTQ_FILE /rRNAindexdirectory/$rRNA_INDEX_BASENAME $INPUT_RNA_MAPPING $MAPPED_RNA_SAM_FILE 2> $LOGFILE_BOWTIE"

				if [ $? -ne 0 ]
                                then
                                        echo "Bowtie1 cannot run correctly ! Check the rRNA index path."
                                        exit 1
                                fi

				chown $USER_IDS $UNMAPPED_RNA_FASTQ_FILE
				chown $USER_IDS $MAPPED_RNA_SAM_FILE
				chown $USER_IDS $LOGFILE_BOWTIE


				echo "Log file : $LOGFILE_BOWTIE generated."
				echo "End of Bowtie1."
			fi
		done
	}

# We run FASTQC on unmapped fastq
Unmmaped_to_rRNA_report()
	{
		DIR_UNMAPPED_RRNA_FASTQC="$1_no_rRNA_report"
		UNMAPPED_RRNA_INPUT="$1_no_rRNA.fastq"

		if [ -s $UNMAPPED_RRNA_INPUT ]
		then
			fastqc_quality_control $DIR_UNMAPPED_RRNA_FASTQC $UNMAPPED_RRNA_INPUT
		else
			echo "$UNMAPPED_RRNA_INPUT doesn't exist ! Check your rRNA index path."
			exit 1
		fi
	}

# We run the Python library matplotlib

mapped_to_R_RNA_distrib_length()
	{
		DISTR_LGT_PNG="$1_mapped_to_rRNA_read_length_distribution.png"
		INPUT_SAM_MAPPED_RNA="$1_rRNA_mapped.sam"

		if [ -s $DISTR_LGT_PNG ]
		then
			return 0
		else
			echo "Computing mapped to rRNA reads length distribution :"

			grep -v '^@' $INPUT_SAM_MAPPED_RNA | awk '$2 != 4 {print $0}' | awk '{print length($10)}' | $PYTHON_SCRIPT_READ_LENGTH_DISTRIBUTION -i $INPUT_SAM_MAPPED_RNA -o $DISTR_LGT_PNG

			if [ $? -ne 0 ]
                        then
                                echo "Cannot computing mapped to rRNA reads length distribution !"
                                exit 1
                        fi

			chown $USER_IDS $DISTR_LGT_PNG

			echo "PNG file : $DISTR_LGT_PNG generated."
			echo "End of computing mapped to rRNA reads length distribution."
		fi
	}

# We run STAR to align reads to the reference genome

align_to_ref_genome()
	{
		for sample in ${SAMPLE_ARRAY[*]}
		do
			echo "Starting of mapping to reference genome :"

			WORKING_ANSWER_DEMULTIPLEXING=${ANSWER_DEMULTIPLEXING^^}

			if [ $WORKING_ANSWER_DEMULTIPLEXING = YES ]
			then
				DIR_ALIGN_STAR="${sample}_align_star/"
				INPUT_ALIGN_GENOME="${sample}_no_rRNA.fastq"
			else
				BASENAME=$(basename $sample .fastq)
				DIR_ALIGN_STAR="${BASENAME}_align_star/"
				INPUT_ALIGN_GENOME="${BASENAME}_no_rRNA.fastq"
			fi

			if [ -s "${DIR_ALIGN_STAR}Aligned.out.sam" ]
			then
				echo "Mapping already done for $sample."
			else
				# Check /genomeindexdirectory
				if [ ! "$(ls -1 /genomeindexdirectory)" ]
				then
					echo "Mount your genome index path in /genomeindexdirectory."
					exit 1
				fi

				mkdir -p $DIR_ALIGN_STAR

				if [ $? -ne 0 ]
				then
					echo "Cannot create the directory !"
					exit 1
				fi

				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/star:2.5.1b bash -c "STAR --runThreadN $(nproc) --genomeDir /genomeindexdirectory --readFilesIn $INPUT_ALIGN_GENOME --outFileNamePrefix $DIR_ALIGN_STAR --outSAMunmapped Within --outFilterMismatchNoverLmax $MAX_ALLOWED_MISMATCHES --quantMode TranscriptomeSAM --seedSearchStartLmax $SEED_SEARCH_POINT --outFilterScoreMinOverLread $FILTER_SCORE_MIN --outFilterMatchNminOverLread $FILTER_MATCH_MIN --winAnchorMultimapNmax $MAX_LOCI_ALLOWED --outFilterMultimapScoreRange $MULTIMAP_SCORE_RANGE"

				if [ $? -ne 0 ]
                                then
                                        echo "Mapping to reference genome cannot run correctly !"
                                        exit 1
                                fi

				chown -R $USER_IDS $DIR_ALIGN_STAR

				echo "Directory $DIR_ALIGN_STAR generated"
				echo "End of mapping to reference genome."
			fi
		done
	}

# We filter the SAM file to get conserve uniq reads

samFiltering()
	{
		WORKING_ANSWER_KEEP_MULTIREAD=${ANSWER_KEEP_MULTIREAD^^}

		SAM_INPUT="$1_align_star/Aligned.out.sam"
		FILTERED_SAM_UNIQUE_OUTPUT="$1_align_filtered.sam"
		FILTERED_SAM_MULTI_OUTPUT="$1_align_multi.sam"
		LOGFILE="$1_align_filtering.log"

		echo "Starting of SAM file filtering :"

		if [ -s $SAM_INPUT ]
		then
			if [ -s $FILTERED_SAM_UNIQUE_OUTPUT ]
			then
				echo "SAM file filering already done."
				return 0
			else
				if [ $WORKING_ANSWER_KEEP_MULTIREAD = YES ]
				then
					grep -v '^@' $SAM_INPUT | awk '$2 != 4 {print $0}' | sort -k 1,1 | $PYTHON_SCRIPT_SAM_FILTERING -i $SAM_INPUT -o $FILTERED_SAM_UNIQUE_OUTPUT -m $FILTERED_SAM_MULTI_OUTPUT > $LOGFILE

					chown $USER_IDS $FILTERED_SAM_UNIQUE_OUTPUT
					chown $USER_IDS $FILTERED_SAM_MULTI_OUTPUT
					chown $USER_IDS $LOGFILE
				else
					grep -v '^@' $SAM_INPUT | awk '$2 != 4 {print $0}' | sort -k 1,1 | $PYTHON_SCRIPT_SAM_FILTERING -i $SAM_INPUT -o $FILTERED_SAM_UNIQUE_OUTPUT > $LOGFILE

					chown $USER_IDS $FILTERED_SAM_UNIQUE_OUTPUT
					chown $USER_IDS $LOGFILE
				fi

				if [ $? -ne 0 ]
				then
					echo "SAM file filtering cannot run correctly !"
					exit 1
				fi

				echo "Log file : $LOGFILE generated."
				echo "End of SAM file filtering."
			fi
		else
			echo "You need a SAM file to launch this step !"
			exit 1
		fi
	}

# We compute the uniquely mapped reads length distribution after alignment to the reference genome and the SAM file filtering

mapped_to_genome_distrib_length()
	{
		SAM_FILTERED_INPUT="$1_align_filtered.sam"
		DISTR_LGT_PNG="$1_uniquely_mapped_to_genome_read_length_distribution.png"

		if [ -s $DISTR_LGT_PNG ]
		then
			return 0
		else
			echo "Computing uniquely mapped to genome reads length distribution :"

			grep -v '^@' $SAM_FILTERED_INPUT | awk '{print length($10)}' | $PYTHON_SCRIPT_READ_LENGTH_DISTRIBUTION -i $SAM_FILTERED_INPUT -o $DISTR_LGT_PNG

			if [ $? -ne 0 ]
                        then
                                echo "Cannot computing mapped to genome reads length distribution !"
                                exit 1
                        fi

			chown $USER_IDS $DISTR_LGT_PNG

			echo "PNG file : $DISTR_LGT_PNG generated."
			echo "End of computing mapped to genome reads length distribution."
		fi
	}

# We compute the multi-reads length distribution after alignment to reference genome

multimapped_to_genome_distrib_length()
	{
		WORKING_ANSWER_KEEP_MULTIREAD=${ANSWER_KEEP_MULTIREAD^^}

		if [ $WORKING_ANSWER_KEEP_MULTIREAD = YES ]
		then
			SAM_MULTIREAD_INPUT="$1_align_multi.sam"
			DISTR_LGT_PNG="$1_multimapped_to_genome_read_length_distribution.png"

			if [ -s $DISTR_LGT_PNG ]
			then
				return 0
			else
				echo "Computing multi-mapped to genome reads length distribution :"

				grep -v '^@' $SAM_MULTIREAD_INPUT | awk '{print length($10)}' | $PYTHON_SCRIPT_READ_LENGTH_DISTRIBUTION -i $SAM_MULTIREAD_INPUT -o $DISTR_LGT_PNG

				if [ $? -ne 0 ]
				then
					echo "Cannot compute multi-mapped to genome reads length distribution !"
					exit 1
				fi
			fi

			echo "PNG file : $DISTR_LGT_PNG generated."
			echo "End of computing multi-mapped to genome reads length distribution."
		else
			return 0
		fi
	}

# We convert the filtered SAM file into a BAM file

sam_to_bam()
	{
		FILTERED_SORTED_ALIGNMENT="$1_align_filtered.sorted"	# Sorted alignment basename for BAM & BAI files
		FILTERED_SAM="$1_align_filtered.sam"

		if [ -s $FILTERED_SAM ]
		then
			if [ -s "${FILTERED_SORTED_ALIGNMENT}.bam" ]
			then
				return 0
			else
				echo "Starting of Samtools"

				# SAM to BAM conversion + Sorting of BAM file
				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/samtools:0.1.19 bash -c "samtools view -Sb $FILTERED_SAM | samtools sort - $FILTERED_SORTED_ALIGNMENT"
				# BAI index of sorted BAM
				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/samtools:0.1.19 bash -c "samtools index "${FILTERED_SORTED_ALIGNMENT}.bam" "${FILTERED_SORTED_ALIGNMENT}.bai""

				chown $USER_IDS "${FILTERED_SORTED_ALIGNMENT}.bam" "${FILTERED_SORTED_ALIGNMENT}.bai"

				if [ $? -ne 0 ]
				then
					echo "Samtools cannot run correctly !"
					exit 1
				fi

				echo "Sorted-indexed alignment : '${FILTERED_SORTED_ALIGNMENT}.bam' generated. You can use it in a genome browser (e.g IGV)"
				echo "End of Samtools."
			fi
		else
			echo "You need a filtered SAM file to launch this step !"
			exit 1
		fi
	}


# We get longest transcript of each gene for CDS annotations from Ensembl 75 GTF
get_longest_transcripts_from_annotations()
	{
		# Check annotations in /root
#		NB_FILE_IN_ROOT=$(ls -R /root | wc -l)
#		let NB_FILE_IN_ROOT=$NB_FILE_IN_ROOT-1

#		if [ $NB_FILE_IN_ROOT -eq 0 ]
		if [ ! "$(ls -1 /root)" ]
		then
			echo "Mount the path to your GTF annotations in /root."
			exit 1
		fi

		INPUT_ANNOTATION=$(basename $PATH_TO_ANNOTATION_FILE)

		ANNOTATION_PREFIX=${INPUT_ANNOTATION:0:-4}

		CDS_ANNOTATIONS="${ANNOTATION_PREFIX}_only_cds.gtf"
		LONGEST_TRANSCRIPTS="${ANNOTATION_PREFIX}_longest_transcripts.txt"

		CDS_LONGEST_TRANSCRIPTS_LIST="${ANNOTATION_PREFIX}_only_cds_longest_transcripts.txt"
		CDS_LONGEST_TRANSCRIPTS_ANNOTATIONS="${ANNOTATION_PREFIX}_only_cds_longest_transcripts.gtf"

		if [ ! -s $CDS_LONGEST_TRANSCRIPTS_ANNOTATIONS ]
		then
			echo "Building annotations containing CoDing Sequences from longest transcripts :"

			docker run --rm --volumes-from ribopro -w /home genomicpariscentre/gff3-ptools:0.4.0 bash -c "gtf-filter --keep-comments -o $CDS_ANNOTATIONS \"field feature == CDS\" /root/$INPUT_ANNOTATION"

			if [ $? -ne 0 ]
                        then
                                echo "Building annotations cannot run correctly. Check your GTF annotations path."
                                exit 1
                        fi

			chown $USER_IDS $CDS_ANNOTATIONS

			$PYTHON_SCRIPT_LONGEST_TRANSCRIPT -i "/root/${INPUT_ANNOTATION}" -o $CDS_LONGEST_TRANSCRIPTS_LIST
			chown $USER_IDS $CDS_LONGEST_TRANSCRIPTS_LIST

			grep -Ff $CDS_LONGEST_TRANSCRIPTS_LIST $CDS_ANNOTATIONS > $CDS_LONGEST_TRANSCRIPTS_ANNOTATIONS
			chown $USER_IDS $CDS_LONGEST_TRANSCRIPTS_ANNOTATIONS

			echo "GTF annotations $CDS_LONGEST_TRANSCRIPTS_ANNOTATIONS generated."
			echo "End of building annotations."
		else
			return 0
		fi
	}

# We compute the number of reads in CDS (HTSeq-count)
htseq_count()
	{
		# Check annotations in /root
#               NB_FILE_IN_ROOT=$(ls -R /root | wc -l)
#               let NB_FILE_IN_ROOT=$NB_FILE_IN_ROOT-1

#               if [ $NB_FILE_IN_ROOT -eq 0 ]
		if [ ! "$(ls -1 /root)" ]
                then
                        echo "Mount the path to your GTF annotations in /root."
                        exit 1
                fi

		WORKING_ANSWER_RNASEQ_COUNTING=${ANSWER_RNASEQ_COUNTING^^}

		FILTERED_SORTED_BAM="$1_align_filtered.sorted.bam"
		HTSEQCOUNT_FILE="$1_htseq.txt"
		HTSEQCOUNT_FILE_ANADIF_BABEL="$1_RPcounts.txt"

		ANNOTATIONS_FILE=$(basename $PATH_TO_ANNOTATION_FILE)
		ANNOTATION_PREFIX=${ANNOTATIONS_FILE:0:-4}

		CDS_LONGEST_TRANSCRIPTS_ANNOTATIONS="${ANNOTATION_PREFIX}_only_cds_longest_transcripts.gtf"

		if [ -s $FILTERED_SORTED_BAM ] && [ -s $CDS_LONGEST_TRANSCRIPTS_ANNOTATIONS ]
		then
			if [ -s $HTSEQCOUNT_FILE ] || [ -s DifferentialAnalysis/$HTSEQCOUNT_FILE ]
			then
				return 0
			else
				echo "Starting of expression estimation (counted reads/gene) :"

				if [ -z $STRANDED ]
				then
					echo "Set the --stranded option of HTSeq-Count (For help : http://www-huber.embl.de/users/anders/HTSeq/doc/count.html)"
					exit 1
				fi

				docker run --rm --volumes-from ribopro -w /home genomicpariscentre/htseq:0.6.1p1 bash -c "htseq-count --mode $MODE_FOR_MULTIPLE_FEATURES_READS --type $FEATURE_TYPE --idattr $IDATTR --stranded $STRANDED --format $FILETYPE $FILTERED_SORTED_BAM $CDS_LONGEST_TRANSCRIPTS_ANNOTATIONS > $HTSEQCOUNT_FILE"

				if [ $? -ne 0 ]
				then
					echo "HTSeq-Count cannot run correctly ! Check your --stranded option on http://www-huber.embl.de/users/anders/HTSeq/doc/count.html"
					exit 1
				fi

				chown $USER_IDS $HTSEQCOUNT_FILE

				mkdir -p DifferentialAnalysis

				chown -R $USER_IDS DifferentialAnalysis

				if [ $WORKING_ANSWER_RNASEQ_COUNTING = YES ]
				then
					grep -v __.* $HTSEQCOUNT_FILE > $HTSEQCOUNT_FILE_ANADIF_BABEL
					chown $USER_IDS $HTSEQCOUNT_FILE_ANADIF_BABEL

					cp $HTSEQCOUNT_FILE_ANADIF_BABEL DifferentialAnalysis
					cp $1_mRNAcounts.txt DifferentialAnalysis
				else
					cp $HTSEQCOUNT_FILE DifferentialAnalysis
				fi

				if [ -s target.txt ]
				then
					cp target.txt DifferentialAnalysis
				else
					if [ $WORKING_ANSWER_RNASEQ_COUNTING = NO ]
					then
						echo "Give your target.txt file."
						exit 1
					fi
				fi

				if [ $? -ne 0 ]
				then
					echo "HTSeq-Count cannot run correctly !"
					exit 1
				fi

				echo "DifferentialAnalysis generated. It contains :"
				ls DifferentialAnalysis
				echo "End of HTSeq-Count."
			fi
		else
			echo "You need a filtered-sorted BAM file to launch this step !"
			exit 1
		fi
	}

# If user has RNA-seq counts, we run Babel : here, build of counts matrix
build_rnaseq_ribopro_counting_tables()
	{
		if [ -e DifferentialAnalysis ]
		then
			WORKDIR_ANADIFF=$(readlink -f DifferentialAnalysis)
		fi

		WORKING_ANSWER_RNASEQ_COUNTING=${ANSWER_RNASEQ_COUNTING^^}

		# If user has RNA-seq countings, we build RNAseq and Ribosome Profiling counting tables
		if [ $WORKING_ANSWER_RNASEQ_COUNTING = YES ]
		then
			echo "Building matrix expression for Babel :"

			docker run --rm --volumes-from ribopro -w $WORKDIR_ANADIFF genomicpariscentre/babel:0.3-0 Rscript "${R_SCRIPTS_PATH}/${R_SCRIPT_BUILD_COUNTING_TABLE_RNASEQ}" ${SAMPLES[@]}
			chown -R $USER_IDS $WORKDIR_ANADIFF

			docker run --rm --volumes-from ribopro -w $WORKDIR_ANADIFF genomicpariscentre/babel:0.3-0 Rscript "${R_SCRIPTS_PATH}/${R_SCRIPT_BUILD_COUNTING_TABLE_RP}" ${SAMPLES[@]}
			chown -R $USER_IDS $WORKDIR_ANADIFF

			if [ $? -ne 0 ]
			then
				echo "Building matrix expression cannot run correctly."
				exit 1
			fi

			echo "End of building matrix expression."
		else
			return 0
		fi
	}

# If user has RNA-seq counts, we run Babel : here differntial analysis and its permutation test
anadif_babel()
	{
		WORKDIR_ANADIFF=$(readlink -f DifferentialAnalysis)
		WORKING_ANSWER_RNASEQ_COUNTING=${ANSWER_RNASEQ_COUNTING^^}

		# If user has RNA-seq counting, we use Babel R package
		if [ $WORKING_ANSWER_RNASEQ_COUNTING = YES ]
		then
			if [ -z $CONDITION_ARRAY ]
			then
				echo "Give your (biological) condition array."
				exit 1
			fi

			echo "Differential analysis :"
			docker run --rm --volumes-from ribopro -w $WORKDIR_ANADIFF genomicpariscentre/babel:0.3-0 Rscript "${R_SCRIPTS_PATH}/${R_SCRIPT_ANADIFF_BABEL}" ${CONDITION_ARRAY[@]}
			chown -R $USER_IDS $WORKDIR_ANADIFF

			echo "Permutation test :"
			docker run --rm --volumes-from ribopro -w $WORKDIR_ANADIFF genomicpariscentre/babel:0.3-0 Rscript "${R_SCRIPTS_PATH}/${R_SCRIPT_PERMT_TEST_BABEL}" ${CONDITION_ARRAY[@]}
			chown -R $USER_IDS $WORKDIR_ANADIFF

			if [ $? -ne 0 ]
			then
				echo "Statistical analysis cannot run correctly."
				exit 1
			fi

			echo "End of statistical analysis."
		else
			return 0
		fi
	}

anadif_sartools()
	{
		WORKING_ANSWER_RNASEQ_COUNTING=${ANSWER_RNASEQ_COUNTING^^}
		WORKING_DIFFERENTIAL_ANALYSIS_PACKAGE=${DIFFERENTIAL_ANALYSIS_PACKAGE^^}

		# If user hasn't RNA-seq counting, we use SARTools R package
		if [ ! $WORKING_ANSWER_RNASEQ_COUNTING = YES ]
		then
			if [ -e DifferentialAnalysis ]
			then
				WORKDIR_ANADIFF=$(readlink -f DifferentialAnalysis)
			fi

			PARAM=($WORKDIR_ANADIFF $1 $2 target.txt $WORKDIR_ANADIFF $3)
			WORK_PARAM=$(echo ${PARAM[*]})
			PARAMETERS=$(echo $WORK_PARAM)

			# EdgeR is launch by default if not specified (because Babel uses edgeR)
			if [ $WORKING_DIFFERENTIAL_ANALYSIS_PACKAGE = DESEQ2 ]
			then
				docker run --rm --volumes-from ribopro -w $WORKDIR_ANADIFF genomicpariscentre/sartools:1.3.2 Rscript "${R_SCRIPTS_PATH}/${R_SCRIPT_ANADIFF_SARTOOLS_DESEQ2}" $PARAMETERS
				chown -R $USER_IDS $WORKDIR_ANADIFF
			else
				docker run --rm --volumes-from ribopro -w $WORKDIR_ANADIFF genomicpariscentre/sartools:1.3.2 Rscript "${R_SCRIPTS_PATH}/${R_SCRIPT_ANADIFF_SARTOOLS_EDGER}" $PARAMETERS
				chown -R $USER_IDS $WORKDIR_ANADIFF
			fi

			if [ $? -ne 0 ]
			then
				echo "Statistical analysis cannot run correctly."
				exit 1
			fi

			echo "End of differential analysis."
		else
			return 0
		fi
	}

export -f demultiplexing
export -f raw_quality_report
export -f removeBadIQF
export -f removeBadIQF_report
export -f removePCRduplicates
export -f Index_Adapter_trimming
export -f Index_Adapter_trimming_report
export -f ThreePrime_trimming
export -f ThreePrime_trimming_report
export -f Size_Selection
export -f Size_Selection_report
export -f align_To_R_RNA
export -f Unmmaped_to_rRNA_report
export -f mapped_to_R_RNA_distrib_length
export -f align_to_ref_genome
export -f samFiltering
export -f mapped_to_genome_distrib_length
export -f multimapped_to_genome_distrib_length
export -f sam_to_bam
export -f get_longest_transcripts_from_annotations
export -f htseq_count
export -f build_rnaseq_ribopro_counting_tables
export -f anadif_babel
export -f anadif_sartools

### MAIN ###

parallel --xapply demultiplexing ::: $WORKING_SAMPLE_ARRAY ::: $WORKING_SAMPLE_INDEX_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel raw_quality_report {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel removeBadIQF {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel removeBadIQF_report {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel removePCRduplicates {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel --xapply Index_Adapter_trimming {.} ::: $WORKING_SAMPLE_ARRAY ::: $WORKING_SAMPLE_INDEX_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel Index_Adapter_trimming_report {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel --xapply ThreePrime_trimming {.} ::: $WORKING_SAMPLE_ARRAY ::: $ADAPTER_SEQUENCE_THREE_PRIME

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel ThreePrime_trimming_report {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel Size_Selection {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel Size_Selection_report {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

align_To_R_RNA

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel Unmmaped_to_rRNA_report {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel mapped_to_R_RNA_distrib_length {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

align_to_ref_genome

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel samFiltering {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel mapped_to_genome_distrib_length {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel multimapped_to_genome_distrib_length {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel sam_to_bam {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

get_longest_transcripts_from_annotations

if [ $? -ne 0 ]
then
	exit 1
fi

wait

parallel htseq_count {.} ::: $WORKING_SAMPLE_ARRAY

if [ $? -ne 0 ]
then
	exit 1
fi

wait

build_rnaseq_ribopro_counting_tables

if [ $? -ne 0 ]
then
	exit 1
fi

wait

anadif_babel

if [ $? -ne 0 ]
then
	exit 1
fi

wait

anadif_sartools $PROJECT_NAME $AUTHOR $REFERENCE_CONDITION

if [ $? -ne 0 ]
then
	exit 1
fi

# Write final report
#FINALLOGFILE="${PROJECT_NAME}.final.report"

#for file in $(ls -c *log); do stat -c '%y' $file >> $FINALLOGFILE; printf "\n" >> $FINALLOGFILE; cat $file >> $FINALLOGFILE; done
#chown $USER_IDS $FINALLOGFILE

# Put log files in log directory
mkdir -p log

chown $USER_IDS -R log
mv *.log log

echo "End of the analysis. Find your log files in log/ directory."
