#!/bin/bash
#

function cmdusage {
    local script_name=$(basename $0)
    cat <<UsageMessage

USAGE

${script_name} [-s] [-c <path>] -r N
${script_name} -h
UsageMessage
}

function cmdhelp {
    cmdusage
    local script_name=$(basename $0)
    cat <<HelpMessage

DESCRIPTION

Generate a HTML report for a, possibly running, execution of
group_subj_feat.sh . The report contains links to the feat reports; a
description (mouse hover) of the actions performed of each subject,
read from logs; is configured to ask the browser for auto refresh
every minute; and is based on floats to render well even in small
screens, e.g. mobile devices.

The aim of this script is not to be called directly, but to let
group_subj_feat.sh call it. However, you can execute it anytime to
build reports.

MANDATORY OPTIONS

-r, --run N An integer number, used for the name of the results
  directory to be read, as runN.

OTHER OPTIONS

-h, --help
  Display this help message.

-s, --silent
  Send nothing to the STDOUT.

-c, --current <path>
  Mark the subject corresponding to <path> as "Running", in the
  report. This <path> is relative to the root of the results directory
  structure.

ATTENTION **

Some important variables are declared in the script, in future
versions of this code they will be exposed as options. By now you need
to change values in the script.

KNOWN ISSUES

If group_subj_feat.sh dies for some reason, the report will still be
reporting the last subject as "Running". See a TODO task marked with
[1] in the script.

Silent mode prints the help and usage messages.

IMPLEMENTATION

version         0.1
authors         R. Velasco-Segura and N. Gonzalez-Garcia
license         2-clause BSD
HelpMessage
}

silent=0

while [ True ]; do
    if [ "${1}" = "--current" -o "${1}" = "-c" ]; then
	# [1] TODO: use a loop to check if the 'current' process is
	# actually running
	#
	# procline=""
	# for i=1 to 10
	#    procline=`ps -fea | grep feat | grep $2 | grep -v grep`
	#    if [ ! -z $procline ]
	#       current_path=$2
	#       break
	#    fi
	#    sleep 1
	# done
	# if [ -z $procline ]
	# then
	#     current_path="not found"
	# fi
	sleep 2
	current_path=$2
	shift 2
    elif [ "${1}" = "--silent" -o "${1}" = "-s"  ]; then
	silent=1
	shift 1
    elif [ "${1}" = "--help" -o "${1}" = "-h"  ];
    then
	cmdhelp
        exit 0
    elif [ "${1}" = "--run" -o "${1}" = "-r"  ];
    then
	if ! [[ ${2} =~ ${num_re} ]]
	then
	    echo "ERROR: N must be a number." >&2
	    cmdusage
            echo
            echo "Use -h option for a detailed description."
	    exit 1
	else
	    N=${2}
	    run="run${2}"
    	    shift 2
	fi
    else
	break
    fi
done

# # This could be part of the task marked with [1].
# if [ $silent = 0 ] &&
#     [ "$current_path" == "not found"]
# then
#     echo "WARNING: current process not found."
#     current_path=""
# fi

# ---------------------------------------------------------
# TODO: Expose the following variables as shell options.
# ---------------------------------------------------------
#          Mandatory
# ---------------------------------------------------------
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
# Log directory
logdir="${resultsdir}/logs/"
# ---------------------------------------------------------

if [ -z ${run+x} ]
then
    cmdusage
    echo
    echo "Use -h option for a detailed description."
    exit 1
fi

errorlist=""
run_report="${logdir}/${run}_report.htm"

# TODO: include complete header for HTML
echo "<head>
<style>
.left {
float: left;
padding: 10px;
border: 2px solid black;
margin: 10px;
}
.error {
color: #ff0000
}
.running {
color: #21620F
}
</style>
<meta http-equiv=\"refresh\" content=\"60\">
</head>" > ${run_report}
echo "<body>" >> ${run_report}
echo "<h1>${run}</h1>" >> ${run_report}

if [ ! -z ${current_path} ]
then
    echo "Currently running ${current_path} </br>" >> ${run_report}
fi

stdoutlog="${logdir}/${run}.stdout"
stderrlog="${logdir}/${run}.stderr"

for group in `ls ${resultsdir} | grep ${g_pre} | sort -t "_" -nk2`
do
    # echo "$group"
    groupdir="${resultsdir}/${group}"

    echo "<div class=\"left\">" >> ${run_report}
    echo "<h2>$group</h2>" >> ${run_report}

    for subject in `ls ${groupdir} | grep ${s_pre} | sort -t "_" -nk2`
    do
	# echo $subject
	subjectdir="${groupdir}/${subject}"

	rundir="${subjectdir}/${run}"

	echo "<h2>${subject}</h2>" >> ${run_report}

	if [ ! -d ${rundir} ] || [ ! "$(ls -A ${rundir})" ]
	then
	    skipping_msg=`cat ${stdoutlog} ${stderrlog} | grep -i "skipping" | grep ": ${group} ${subject} :" | sort -u`
	    if [ ! -z "${skipping_msg}" ]
	    then
                echo "<span title=\"${skipping_msg}\">Skipped</span></br>" >> ${run_report}
	    fi
	    continue
	fi

	if true #[ $group == "grupo_5" ] && [ $subject == "suj_1" ]
	then
	    if [ 1 -lt `ls "${rundir}" | grep "\.feat\$" | wc -l` ]
	    then
		echo "<span class=\"error\" title=\"More than one feat dir found in $rundir\">Multiple</span></br>" >> $run_report
		continue
	    fi
	    if [ 0 -eq `ls "${rundir}" | grep "\.feat\$" | wc -l` ]
	    then
		if [ 0 -eq ${silent} ]
		then
		    echo "WARNING: ${group} ${subject} : feat dir not found, skipping subject"
		fi
		continue
	    fi
	    feat=`ls "${rundir}" | grep "\.feat\$"`
	    featdir="${rundir}/$feat"
	    featdir2="../${group}/${subject}/${run}/${feat}"

	    log_msgs=`cat ${stdoutlog} ${stderrlog} | grep ": ${group} ${subject} :" | sort -u`
	    if [ -z "${log_msgs}" ]
	    then
		tltle=""
	    else
		title="title=\"${log_msgs}\""
	    fi

	    if 	[ ! 0 -eq `cat "${featdir}/report.html" "${featdir}/report_log.html" 2> /dev/null | grep -i error | wc -l` ]
	    then
		echo "<span class=\"error\" ${title} >Error</span></br>" >> ${run_report}
		errorlist="${errorlist} </br>
<a href=\"${featdir2}/report_log.html\" >${group} ${subject}</a>"
	    fi

	    if [ "${group}/${subject}" == "${current_path}" ]
	    then
		echo "<span class=\"running\" ${title} >Running</span></br>" >> ${run_report}
	    fi

	    echo "<a href=\"${featdir2}/report_log.html\" ${title} >log</a>" >> ${run_report}
	fi
    done
    echo "</div>" >> ${run_report}
done

echo "<div class=\"left\">
<h2>Error list</h2>
<p>${errorlist}</p>
</div>" >> ${run_report}

echo "<div class=\"left\">
<h2>Disk info</h2>
<pre>
$(df -h ${resultsdir})
</pre>
</div>" >> ${run_report}

echo "<div class=\"left\">
<h2>Directories size</h2>
<pre>
$(du -sh ${resultsdir})
$(du -sh ${rawdatadir})
</pre>
</div>" >> ${run_report}

echo "</body>" >> ${run_report}


# TODO: display total execution time.

# TODO: display total disk usage of this run

# TODO: Use exec rather than >> to redirect output

# TODO: Use exec to implement silent behavior

# TODO: check for mandatory arguments of options, and complain if not
# present.

# TODO: In silent mode prevent printing of help and usage messages.
