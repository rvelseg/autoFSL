#!/usr/bin/python
#

import xml.etree.ElementTree as ET
import argparse
from argparse import RawTextHelpFormatter
import os
from ctypes import POINTER, c_int, cast, pythonapi
import tempfile
import shutil
from slugify import slugify
import subprocess

# TODO: Make a module with the functionality to test if the code is
# running in interactive mode.

# http://stackoverflow.com/questions/640389
def in_interactive_inspect_mode() :
    """Whether '-i' option is present or PYTHONINSPECT is not empty."""
    if os.environ.get('PYTHONINSPECT'): return True
    iflag_ptr = cast(pythonapi.Py_InteractiveFlag, POINTER(c_int))
    #NOTE: in Python 2.6+ ctypes.pythonapi.Py_InspectFlag > 0
    #      when PYTHONINSPECT set or '-i' is present
    return iflag_ptr.contents.value != 0

def safe_exit(code = 0):
    if in_interactive_inspect_mode () :
        # This will generate an exception and stop the execution of
        # the script, but it will not kill the interactive
        # session. This is usefulf for me when running the script
        # in emacs, using the shell of the Inferior Python mode.
        raise ValueError('Script terminated within interactive session.')
    else :
        exit(code)

def safe_parse_args(parser, default_args) :
    if in_interactive_inspect_mode() :
        try :
            args = parser.parse_args()
        except :
            print "Something wrong with the arguments, using the default."
            print default_args
            args = parser.parse_args(default_args.split())
    else :
        args = parser.parse_args()
    return args

parser = argparse.ArgumentParser()
parser.description="This script use the `fslsplit` command to get ROIs, in separated .nii.gz files, from specified atlas."

parser.add_argument('atlas_nii', metavar='<.nii.gz file.>',
                    help='An atlas .nii.gz file, where regions are stored as diferent volumes.')

parser.add_argument('atlas_xml', metavar='<.xml file.>',
                    help='The atlas .xml file, containing the labels related to volumes of <.nii.gz file.> with the attribute `index`.')

parser.add_argument('outdir', metavar='<outdir>',
                    help='An existent output directory to put the obtained ROIs.')

debug_args = "/usr/share/data/harvard-oxford-atlases/HarvardOxford/HarvardOxford-cortl-prob-1mm.nii.gz /usr/share/data/harvard-oxford-atlases/HarvardOxford-Cortical-Lateralized.xml ."
args = safe_parse_args(parser, debug_args)
argsv = vars(args)

tree = ET.parse(argsv['atlas_xml'])
data = tree.find('data')
labels = data.findall('label')

# Split the Atlas in available regions
tmpdir = tempfile.mkdtemp()
cmd = ['fslsplit', argsv['atlas_nii'], tmpdir + "/"]
proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
output, error = proc.communicate()

for label in labels :
    index = str(label.attrib['index'])
    roifile1 = tmpdir + "/" + index.zfill(4) + ".nii.gz"
    roifile2 = argsv['outdir'] + "/" + index.zfill(4) + "_" + slugify(unicode(label.text)) + ".nii.gz"
    shutil.move(roifile1, roifile2)

shutil.rmtree(tmpdir)
