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

This script runs feat on multiple subjects. The FRMI results must be
organized in numbered directories for subjects, within numbered
directories for groups, see the example below.

The analysis is based in a template file fsf. Using awk fsf files are
generated for each subject with the appropriate values. Strings to
substituted in the template file must be empty , as "".

The intended way to get the template is to perform a feat analysis in
one subject using the GUI, and then remove some of the parameters of
the resulting design.fsf file.

Results will be placed in a different directory structure, inside the
directories of each subject.

MANDATORY OPTIONS

-r, --run <run_id>
  An integer number, used for the name of the results directory,
  as run<run_id>.

OTHER OPTIONS

-h, --help
  Display this help message.

-c, --clobber
  Remove the results for the specified value of N.

-n, --dry-run
  Print the analysis commands that would be executed, but don't
  execute them. However, result directories are generated and template
  files are processed.

ATTENTION **

Some important variables are declared in the script, in future
versions of this code they will be exposed as options. By now you need
to change values in the script.

EXAMPLE

If your FMRI data have the following structure

raw_data
|-- group_1
|   |-- subj_1
|   |-- subj_2
|   |-- subj_3
|    -- subj_4
 -- group_2
    |-- subj_1
    |-- subj_2
     -- subj_3

To run feat in all subjects, with the run identifier 8, use

${script_name} -r 8

A similar structure will be generated in the results directory, and
inside each subject directory results will be stored in a run8
sub directory.

KNOWN ISSUES

There is no special handling of directory or file names with spaces,
don't use them.

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
# ---------------------------------------------------------
#          With default values
# ---------------------------------------------------------
# Group name prefix
g_pre="grupo_"
# Subject name prefix
s_pre="suj_"
# Directory where the FMRI data is, relative to subject directory
funcd="./funcional/"
# Directory where the anatomic data is, relative to the subject
# directory
anatd="./anatomico/"
# Directory where the onstet files are, relative to the subject
# directory
onsetd="PUERTAS"
# Onset files
o_pre="puerta"
# Amount of onset files.
o_num="4"
# Log directory
logdir="${resultsdir}/logs/"
# --------------------------------------------------------

# Get absolute paths of the main directories
templatedir=$(readlink -f ${templatedir})
resultsdir=$(readlink -f ${resultsdir})
rawdatadir=$(readlink -f ${rawdatadir})

#This variable is used for validating numbers
num_re='^[0-9]+$'

while [ True ];
do
    if [ "${1}" = "--clobber" -o "${1}" = "-c" ];
    then
	clobber=1
	shift 1
    elif [ "${1}" = "--run" -o "${1}" = "-r"  ];
    then
	if ! [[ ${2} =~ ${num_re} ]]
	then
	    echo "ERROR: <run_id> must be an integer." >&2
	    cmdusage
            echo
            echo "Use -h option for a detailed description."
	    exit 1
	else
	    run_id=${2}
	    run="run${run_id}"
    	    shift 2
	fi
    elif [ "${1}" = "--dry-run" -o "${1}" = "-n"  ];
    then
	dryrun=1
    	shift 1
    elif [ "${1}" = "--help" -o "${1}" = "-h"  ];
    then
	cmdhelp
        exit 0
    # elif [ "${1}" = "--otheroption" -o "${1}" = "-o"  ];
    # then
    # 	whatever
    # 	shift somenumber
    else
	break
    fi
done

# http://stackoverflow.com/questions/3601515/
if [ -z ${run+x} ]
then
    cmdusage
    echo
    echo "Use -h option for a detailed description."
    exit 1
fi

if [ ! -z ${clobber+x} ]
then
   read -p "This will remove all results in ${run} directories. Proceed? " -n 1 -r
   echo
   if [[ $REPLY =~ ^[Yy]$ ]]
   then
       echo "Erasing all the ${run} directories."
   else
       echo "Aborted."
       exit 0
   fi
fi

if [ ! -d "${logdir}" ]
then
    mkdir -p "${logdir}" || exit 1
fi
# Don't change the order of these two commands, if you do it stderr
# will also be in stdout log.
exec 2> >(tee -a "${logdir}/${run}.stderr")
exec 1> >(tee -a "${logdir}/${run}.stdout")

# TODO: ask for a template file, not a template directory.
# TODO: use a different name for the following variable
templatedir="${templatedir}/${run}"
if [ 1 -lt `ls ${templatedir} | grep "\.fsf\$" | wc -l` ]
then
    echo "ERROR: more than one .fsf file found in template directory ${templatedir}." >&2
    exit 1
fi
if [ 0 -eq `ls ${templatedir} | grep "\.fsf\$" | wc -l` ]
then
    echo "ERROR: no .fsf file found in template directory ${templatedir}." >&2
    exit 2
fi
fsf_file=`ls ${templatedir} | grep "\.fsf\$"`

report_script="./html_report.sh"

for group in `ls ${rawdatadir} | grep ${g_pre} | sort -t "_" -nk2`
do
    # echo "$group"

    if [ ! -d "${resultsdir}/${group}" ]
    then
	mkdir "${resultsdir}/${group}"
    fi

    groupdir="${rawdatadir}/${group}"

    for subject in `ls ${groupdir} | grep ${s_pre} | sort -t "_" -nk2`
    do
	# echo $subject

	if [ ! -d "${resultsdir}/${group}/${subject}" ]
	then
	    mkdir "${resultsdir}/${group}/${subject}"
	fi

	subjectdir="${groupdir}/${subject}"

        # This condition is useful to debug this script
	if true #[ ${group} = "${g_pre}4" ] && [ $subject = "${s_pre}10" ]
	then

	    outputdir="${resultsdir}/${group}/${subject}/${run}"

	    if [ ! -z ${clobber+x} ]
	    then
		if [ -d "${outputdir}" ]
		then
		    cmd="rm -rf ${outputdir}"
                    echo ${cmd}
	            [ -z ${dryrun+x} ] && eval ${cmd}
                    [ -z ${dryrun+x} ] && echo "INFO: ${group} ${subject} : ${run} removed."
		fi
		continue
	    else
		# execute analysis
                if [ ! -d "${outputdir}" ]
                then
		    mkdir "${outputdir}"
                fi
	    fi

	    ############################################################

            funcdir=$(readlink -f "${subjectdir}/${funcd}")
	    if [ ! -d "${funcdir}" ]
	    then
		echo "WARNING: ${group} ${subject} : functional directory not found, skipping subject"
		continue
	    fi

	    if [ 1 -lt `ls "${funcdir}" | grep "\.nii\.gz\$" | wc -l` ]
	    then
		echo "ERROR: ${group} ${subject} : more than one functional file found, skipping subject" >&2
		continue
	    fi
	    if [ 0 -eq `ls "${funcdir}" | grep "\.nii\.gz\$" | wc -l` ]
	    then
		echo "WARNING: ${group} ${subject} : functional file not found, skipping subject"
		continue
	    fi
	    func_file=`ls "${funcdir}" | grep "\.nii\.gz\$"`
	    func_file=$(basename "${func_file}")
	    func_file="${func_file%.*}"
	    func_file=$(basename "${func_file}")
	    func_file="${func_file%.*}"
	    func_file_name="${func_file}"
	    func_file="${funcdir}/${func_file}"

	    #############################################################

	    funcpath_reo="${outputdir}/${func_file_name}_reo"

	    cmd="fslreorient2std"

	    cmd_param="${cmd} \
${func_file}.nii.gz \
${funcpath_reo}.nii.gz"

	    echo ${cmd_param}
	    [ -z ${dryrun+x} ] && eval ${cmd_param}

	    #############################################################

            cmd="slices"

	    cmd_param="${cmd} \
${funcpath_reo}.nii.gz \
-o ${funcpath_reo}.gif"

            echo ${cmd_param}
	    [ -z ${dryrun+x} ] && eval ${cmd_param}

	    #############################################################

	    anatomicdir=$(readlink -f "${subjectdir}/${anatd}")

	    if [ ! -d "${anatomicdir}" ]
	    then
		echo "WARNING: ${group} ${subject} : anatomic directory not found, skipping subject."
		continue
	    fi

	    if [ 1 -lt `ls "${anatomicdir}" | grep "^[0-9]\+" | grep -v "_brain\.nii\.gz\$" | wc -l` ]
	    then
		echo "WARNING: ${group} ${subject} : More than one anatomic file found, skipping."
		continue
	    fi
	    if [ 0 -eq `ls "${anatomicdir}" | grep "^[0-9]\+" | grep -v "_brain\.nii\.gz\$" | wc -l` ]
	    then
		echo "WARNING: ${group} ${subject} : Anatomic file not found, skipping."
		continue
	    fi
	    anatomicfile=`ls "${anatomicdir}" | grep "^[0-9]\+" | grep -v "_brain\.nii\.gz\$"`
	    basename_anatomic=`echo "${anatomicfile}" | cut -d'.' -f1`
	    anatomicpath="${anatomicdir}/${basename_anatomic}"

	    ############################################################

	    brainpath="${outputdir}/${basename_anatomic}_anatomic_brain"

	    echo "INFO: ${group} ${subject} : begin : bet : $(date +"%x %T")"

	    cmd="bet"
	    cmd_param="${cmd} \
${anatomicpath} \
${brainpath} \
-f 0.5 \
-g 0 "

	    echo ${cmd_param}
	    [ -z ${dryrun+x} ] && eval ${cmd_param}

	    echo "INFO: ${group} ${subject} : end : bet : $(date +"%x %T")"

	    ############################################################

	    brainpath_reo="${brainpath}_reo"

	    cmd="fslreorient2std"

	    cmd_param="${cmd} \
${brainpath}.nii.gz \
${brainpath_reo}.nii.gz"

	    echo ${cmd_param}
	    [ -z ${dryrun+x} ] && eval ${cmd_param}

	    ############################################################

            cmd="slices"

	    cmd_param="${cmd} \
${brainpath_reo}.nii.gz \
-o ${brainpath_reo}.gif"

            echo ${cmd_param}
	    [ -z ${dryrun+x} ] && eval ${cmd_param}

	    ############################################################

	    outputdir_feat="${resultsdir}/${group}/${subject}/${run}/${func_file_name}.feat"
	    if [ -d ${outputdir_feat} ]
	    then
		echo "WARNING: ${group} ${subject} : feat analisis already done, skipping subject."
		continue
	    fi

            ############################################################

	    onset_dir="${subjectdir}/${onsetd}/"
	    if [ ! -d "${onset_dir}" ]
	    then
		echo "WARNING: ${group} ${subject} : onset files directory not found, skipping subject"
		continue
	    fi

            for onset_i in $(seq 1 $o_num)
            do
                onset_fn="${o_pre}${onset_i}"
	        if [ 1 -lt `ls "${onset_dir}" | grep -i "^${onset_fn}" | wc -l` ]
	        then
		    echo "ERROR: ${group} ${subject} : more than one ${onset_fn} file found, skipping subject" >&2
		    continue
	        fi
	        if [ 0 -eq `ls "${onset_dir}" | grep -i "^${onset_fn}" | wc -l` ]
	        then
		    echo "WARNING: ${group} ${subject} : ${onset_fn} file not found, skipping subject"
		    continue
	        fi
	        onset_files[$(( $onset_i - 1 ))]=$(readlink -f \
                   "${resultsdir}/${group}/${subject}/${run}/${onsetd}/$(ls ${onset_dir} | grep -i "^${onset_fn}")")
            done
	    cp -a ${onset_dir} "${resultsdir}/${group}/${subject}/${run}"

            #############################################################
            ######### Process template file

	    feat_configdir="${resultsdir}/${group}/${subject}/${run}/feat_config"
	    if [ -d ${feat_configdir} ]
	    then
	    	echo "WARNING: ${feat_configdir} overwritten"
	    	rm -rf ${feat_configdir}
	    fi
	    cp -a ${templatedir} ${feat_configdir}

	    tmp_file=`mktemp`
	    awk "/set feat_files\(1\)/ {gsub(\"\\\"\\\"\", \"\\\"${funcpath_reo}\\\"\")}; {print}" "${feat_configdir}/${fsf_file}" > ${tmp_file}
	    mv ${tmp_file} "${feat_configdir}/${fsf_file}"

	    tmp_file=`mktemp`
	    awk "/set highres_files\(1\)/ {gsub(\"\\\"\\\"\", \"\\\"${brainpath_reo}\\\"\")}; {print}" "${feat_configdir}/${fsf_file}" > ${tmp_file}
	    mv ${tmp_file} "${feat_configdir}/${fsf_file}"

            for onset_i in $(seq 1 $o_num)
            do
                onset_fn=${onset_files[$(( $onset_i - 1 ))]}
	        tmp_file=`mktemp`
	        awk "/set fmri\(custom${onset_i}\)/ {gsub(\"\\\"\\\"\", \"\\\"${onset_fn}\\\"\")}; {print}" "${feat_configdir}/${fsf_file}" > ${tmp_file}
	        mv ${tmp_file} "${feat_configdir}/${fsf_file}"
            done

	    tmp_file=`mktemp`
	    awk "/set fmri\(outputdir\)/ {gsub(\"\\\"\\\"\", \"\\\"${outputdir_feat}\\\"\")}; {print}" "${feat_configdir}/${fsf_file}" > ${tmp_file}
	    mv ${tmp_file} "${feat_configdir}/${fsf_file}"

	    tmp_file=`mktemp`
	    [ -z ${dryrun+x} ] \
                && fslinfo ${funcpath_reo} > ${tmp_file} \
                    || fslinfo ${func_file} > ${tmp_file}
	    dim1=`cat ${tmp_file} | awk '/^dim1/{print $2}'`
	    dim2=`cat ${tmp_file} | awk '/^dim2/{print $2}'`
	    dim3=`cat ${tmp_file} | awk '/^dim3/{print $2}'`
	    dim4=`cat ${tmp_file} | awk '/^dim4/{print $2}'`
	    totalvoxels=$(( $dim1 * $dim2 * $dim3 * $dim4 ))
	    rm ${tmp_file}

	    tmp_file=`mktemp`
	    awk "/set fmri\(npts\)/ {gsub(\"\\\"\\\"\", \"${dim4}\")}; {print}" "${feat_configdir}/${fsf_file}" > ${tmp_file}
	    mv ${tmp_file} "${feat_configdir}/${fsf_file}"

	    tmp_file=`mktemp`
	    awk "/set fmri\(totalVoxels\)/ {gsub(\"\\\"\\\"\", \"${totalvoxels}\")}; {print}" "${feat_configdir}/${fsf_file}" > ${tmp_file}
	    mv ${tmp_file} "${feat_configdir}/${fsf_file}"

            ############################################################
            ######### Execute feat

	    [ -z ${dryrun+x} ] && ${report_script} --current "${group}/${subject}" --silent -r ${run_id} &

	    echo "INFO: ${group} ${subject} : begin : feat : $(date +"%x %T")"
	    cmd="feat"

	    cmd_param="${cmd} ${feat_configdir}/${fsf_file}"

	    echo ${cmd_param}
	    [ -z ${dryrun+x} ] && eval ${cmd_param}
	    echo "INFO: ${group} ${subject} : end : feat : $(date +"%x %T")"

            # When analysis is actually done, it is not neccesary to
            # keep ${feat_configdir} since the feat results directory
            # has a copy.
	    [ -z ${dryrun+x} ] && rm -rf ${feat_configdir}
	fi
    done
done

[ -z ${dryrun+x} ] && [ -z ${clobber+x} ] && ${report_script} --silent -r ${run_id}

[ ! -z ${dryrun+x} ] && echo "Dry run mode: listed commands were NOT executed."

# TODO: Add option to clear logs.

# TODO: Standardize the use of subshells, use $(command),
# rather than `command`

# TODO: Standardize and clean the getting of base name for files.

# TODO: parallelize at processor level, not with GPU. Ask for the
# number of processors, and call the same number of feat processes
# using a counting variable
#
# p=4  # processors
# echo "0" > ./running_feats
# for {
#     ...
#     c=`cat ./running_feats`
#     while c >= p {
#        sleep 10min
#        c=`cat ./running_feats`
#     }
#     feat_wrap.sh $run &
# }
#
# feat_wrap.sh
# -------------
# c=`cat ./running_feats`
# echo $c+1 ./running_feats
# feat $1
# echo $c-1 ./running_feats
#
# If considering to use pid files, see this:
# http://stackoverflow.com/questions/696839/

# TODO: Standardize variable names to use underscores, camellcase, or
# something.

# TODO: Everything should be in English.

# TODO: check for mandatory arguments of options, and complain if not
# present.
