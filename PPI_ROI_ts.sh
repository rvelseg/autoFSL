#!/bin/bash
#

function cmdusage {
    local script_name=$(basename $0)
    cat <<UsageMessage

USAGE

${script_name} [-cn] -r <run_id>
${script_name} -h
UsageMessage
}

function cmdhelp {
    cmdusage
    local script_name=$(basename $0)
    cat <<HelpMessage

DESCRIPTION

Extracts and plots a timeseries from a ROI, to be used in a PPI
analysis based on previous results of a \`feat\` analysis, over a
directory structure generated by \`group_subj_feat.sh\`, identified
with the directory name \`run<run_id>\`.

It uses a previously generated ROI mask, img file, in the standard
space used for the \`feat\` analysis. The path for this file needs to
be specified inside this script.

Results will be written to a \`PPI\` directory, inside the
corresponding \`run<run_id>\` directory.

WORKFLOW

This script, first creates a mask in the space on the FMRI file used
to perform the \`feat\` analysis, using \`flirt\` as

    flirt \\
-in	   <maskpath> \\
-ref	   <efniipath> \\
-applyxfm \\
-init	   <s2efmatpath> \\
-datatype  float \\
-out	   <funcmaskpath>

where
    maskpath:	   The provided ROI mask img file
    efniipath:     The \`reg/example_func.nii.gz\` file of the \`feat\`
                   analysis
    s2ematpath:    The \`reg/standard2example_func.mat\` of the \`feat\`
                   analysis
    funcmaskpath:  Output

Then, extracts the time series, using \`flsmeants\` as

    flsmeants \\
-i <funcfilepath> \\
-o <tspath> \\
-m <funcmaskpath>

where
    funcfilepath:  FMRI file used for the feat analysis
    tspath:        Output
    funcmaskpath:  Output of the previous \`flirt\` command

Finally, generates a plot of the timeseries, using \`gnuplot\`.

MANDATORY OPTIONS

-r, --run <run_id>
  An integer number, registration results from the directory
  \`run<run_id>\` will be used to generate the timeseries..

OTHER OPTIONS

-h, --help
  Display this help message.

-c, --clobber
  Remove the PPI sub directory corresponding to \`run<run_id>\`.

-n, --dry-run
  Print the commands that would be executed, but don't execute them.

ATTENTION **

Some important variables are declared in the script, in future
versions of this code they will be exposed as options. By now you need
to change values in the script.

KNOWN ISSUES

There is no special handling of directories, or file names, with
spaces, don't use them.

IMPLEMENTATION

version         0.1
authors         R. Velasco-Segura and N. Gonzalez-Garcia
license         2-clause BSD
HelpMessage
}

# ---------------------------------------------------------
# TODO: Expose the following variables as shell options.
# ---------------------------------------------------------
#          Mandatory
# ---------------------------------------------------------
# A directory containing /run<run_id>/template.fsf
templatedir="./templates/"
# Root of the results directory structure
resultsdir="../results"
# Root of the directory with the FMRI data structure
rawdatadir="../datos_brutos"
# maks file of the ROI
maskpath="../${run}/PPI_ROI_mask.img"
# ---------------------------------------------------------
#          With default values
# ---------------------------------------------------------
# Group name prefix
g_pre="grupo_"
# Subject name prefix
s_pre="suj_"
# --------------------------------------------------------

# Get absolute paths
resultsdir=$(readlink -f ${resultsdir})
rawdatadir=$(readlink -f ${rawdatadir})
maskpath=$(readlink -f ${maskpath})

#This variable is used for validating numbers
num_re='^[0-9]+$'

while [ True ];
do
    if [ "${1}" = "--run" -o "${1}" = "-r"  ]
    then
	if ! [[ ${2} =~ ${num_re} ]]
	then
	    echo "ERROR: <run_id> must be a number." >&2
	    cmdhelp
	    exit 1
	else
	    run_id=${2}
	    run="run${run_id}"
    	    shift 2
	fi
    elif [ "${1}" = "--dry-run" -o "${1}" = "-n"  ]
    then
	dryrun=1
    	shift 1
    elif [ "${1}" = "--clobber" -o "${1}" = "-c" ]
    then
	clobber=1
	shift 1
    elif [ "${1}" = "--help" -o "${1}" = "-h"  ]
    then
	cmdhelp
        exit 0
    # elif [ "${1}" = "--other-option" -o "${1}" = "-o"  ];
    # then
    # 	whatever
    # 	shift somenumber
    else
	break
    fi
done

if [ -z ${run+x} ]
then
    cmdusage
    echo
    echo "Use -h option for a detailed description."
    exit 1
fi

if [ ! -z ${clobber+x} ]
then
   read -p "This will remove all the ${run}/PPI directories. Proceed? " -n 1 -r
   echo
   if [[ $REPLY =~ ^[Yy]$ ]]
   then
       echo "Removing all the ${run}/PPI directories."
   else
       echo "Aborted."
       exit 0
   fi
fi


for group in `ls ${resultsdir} | grep ${g_pre} | sort -t "_" -nk2`
do
    # echo "$group"

    groupdir="${resultsdir}/${group}"

    for subject in `ls ${groupdir} | grep ${s_pre} | sort -t "_" -nk2`
    do
	# echo $subject

	subjectdir="${groupdir}/${subject}"

	rundir="${subjectdir}/${run}"
	if [ ! -d "${rundir}" ] || [ ! "$(ls -A $rundir)" ]
	then
	    echo "WARNING: ${group} ${subject} : ${run} dir not found, skipping."
	    continue
	fi

	if true #[ $group = "grupo_2" ] && [ $subject = "suj_9" ]
	then

	    ppipath="${rundir}/PPI"

	    if [ ! -z ${clobber+x} ]
	    then
		if [ -d "${ppipath}" ]
		then
		    echo "INFO: ${group} ${subject} : ${run}/PPI removed."
		    cmd="rm -rf ${ppipath}"
		    echo ${cmd}
		    [ -z ${dryrun+x} ] && eval ${cmd}
		fi
		continue
	    else
		if [ -d "${ppipath}" ]
		then
		    echo "WARNING: ${group} ${subject} : ${ppipath} directory found, skipping subject."
		    continue
		else
		    # execute analysis
		    cmd="mkdir ${ppipath}"
		    echo ${cmd}
		    [ -z ${dryrun+x} ] && eval ${cmd}
		fi
	    fi

	    if [ 1 -lt $(ls "${rundir}" | grep "^[0-9]\+" | grep "\.feat\$" | wc -l ) ]
	    then
		echo "WARNING: ${group} ${subject} : More than one feat directory found, skipping."
		continue
	    fi
	    if [ 0 -eq $(ls "${rundir}" | grep "^[0-9]\+" | grep "\.feat\$" | wc -l ) ]
	    then
		echo "WARNING: ${group} ${subject} : feat directory not found, skipping."
		continue
	    fi
	    featdir=$(ls "${rundir}" | grep "^[0-9]\+" | grep "\.feat\$" )
	    featpath="${rundir}/${featdir}"

	    if [ -d "${featpath}/reg" ]
	    then
		regpath="${featpath}/reg"
	    else
		echo "WARNING: ${group} ${subject} : feat reg directory not found, skipping."
		continue
	    fi

	    if [ -f "${regpath}/example_func.nii.gz" ]
	    then
		efniipath="${regpath}/example_func"
	    else
		echo "WARNING: ${group} ${subject} : example_func.nii.gz not found, skipping."
		continue
	    fi

	    if [ -f "${regpath}/standard2example_func.mat" ]
	    then
		s2efmatpath="${regpath}/standard2example_func.mat"
	    else
		echo "WARNING: ${group} ${subject} : standard2example_func.mat not found, skipping."
		continue
	    fi

	    ##############################################################

	    funcmaskpath="${ppipath}/functional_mask"

	    which flirt > /dev/null && \
		cmd=$(which flirt) || \
		    { echo "WARNING: ${group} ${subject} : flirt comand not found, skipping."; \
		      continue; }

	    cmd_param="${cmd} \
-in ${maskpath} \
-ref ${efniipath} \
-applyxfm \
-init ${s2efmatpath} \
-datatype float \
-out ${funcmaskpath}"

	    echo "INFO: ${group} ${subject} : flirt : begin : $(date +"%x %T")"

	    echo ${cmd_param}
	    [ -z ${dryrun+x} ] && eval ${cmd_param}

	    echo "INFO: ${group} ${subject} : flirt : end : $(date +"%x %T")"

	    ######################################################

	    which fslmeants > /dev/null && \
		cmd=$(which fslmeants) || \
		    { echo "WARNING: ${group} ${subject} : fslmeants comand not found, skipping."; \
		      continue; }

	    funcpath="${rawdatadir}/${group}/${subject}/funcional"
	    if [ ! -d "${funcpath}" ]
	    then
		echo "WARNING: ${group} ${subject} : functional directory not found, skipping subject"
		continue
	    fi
	    if [ 1 -lt `ls "${funcpath}" | grep "\.nii\.gz\$" | wc -l` ]
	    then
		echo "ERROR: $group $subject : more than one functional file found, skipping subject" >&2
		continue
	    fi
	    if [ 0 -eq `ls "${funcpath}" | grep "\.nii\.gz\$" | wc -l` ]
	    then
		echo "WARNING: $group $subject : functional file not found, skipping subject"
		continue
	    fi
	    funcfile=`ls "${funcpath}" | grep "\.nii\.gz\$"`
	    funcfilebn=$(basename ${funcfile} .nii.gz )
	    funcfilepath="${funcpath}/${funcfile}"

	    maskbn=$(basename ${maskpath} .img)

	    tspath="${ppipath}/${funcfilebn}_${maskbn}_ts.dat"

	    cmd_param="${cmd} \
-i ${funcfilepath} \
-o ${tspath} \
-m ${funcmaskpath} "

	    echo "INFO: ${group} ${subject} : fslmeants : begin : $(date +"%x %T")"

	    echo ${cmd_param}
	    [ -z ${dryrun+x} ] && eval ${cmd_param}

	    echo "INFO: ${group} ${subject} : fslmeants : end : $(date +"%x %T")"

	    ###########################################################

	    tsbn=$(basename ${tspath} .dat)

	    which gnuplot > /dev/null && \
		cmd=$(which gnuplot) || \
		    { echo "WARNING: ${group} ${subject} : gnuplot comand not found, skipping."; \
		      continue; }

	    [ -z ${dryrun+x} ] && gnuplot <<- GPEOF
set term png
set output "${ppipath}/${tsbn}.png"
plot "${tspath}" w l
GPEOF

	fi
    done
done
