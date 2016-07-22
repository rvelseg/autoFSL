# autoFSL

Authors : R. Velasco-Segura and N. Gonzalez-Garcia

Affiliations : Grupo de Acústica y Vibraciones, Centro de Ciencias Aplicadas y Desarrollo Tecnológico (CCADET) UNAM, Hospital Infantil de México Federico Gómez.

Source repository : https://github.com/rvelseg/autoFSL

# Description

Some scripts to automate analysis of FMRI using FSL.

Even when an effort has been made to make this scripts for general purpose, they still have some parameters specific for the investigation that motivate them.
Therefore, previous to its use, it is adviced to read the scripts, and use the --dry-run option to have an idea of what they are actually going to execute.

# TODO

Use the following structure to check for the existence of the needed commands, previous to the execution of the main loop, and alert the user if something is missing

~~~~
needed_commands="ls cp cmd1 cmd2 cdm3"
for cmd in ${needed_commands}
do
    which ${cmd} > /dev/null || m_cmd="${m_cmd} ${cmd}"
done
if [ ! -z ${m_cmd+x} ]
then
	echo "Missing commands:${m_cmd}"
	exit 1
fi
~~~~




<!-- Local Variables: -->
<!-- mode: visual-line -->
<!-- mode: markdown -->
<!-- End: -->
