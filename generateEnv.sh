#!/bin/bash
# ./generateEnv.sh
# Generates a Python Environment for use within AWS Lambda
# Recommended that new users refer to ./generateEnv.sh --help

### WARNING
### THIS FILE REQUIRES HARD TABS FOR HEREDOC SUPPORT
### I'm sorry - it pains me as well but I'm working with the cards I've been
### dealt with. Learn to make these bearable in your text editor of choice :)

###############################################################################
###                   +++  FLAGS - MODIFY AT OWN RISK  +++                  ###
###############################################################################
### Note that most of these flags will probably become argument options in  ###
### the future!                                                             ###

# Hard Coded SSH Identity File location
#SSH_IDENTITY=~/.ssh/keyfile

# Directory on remote machine for environment generation
# Should end with directory name, and no '/'
ENVDIR=/tmp/createEnv.$$

# Directory on remote machine for SCP destination
# Should end with directory name, and no '/'
#SCPDIR=~/test
SCPDIR=/tmp/createEnvFiles.$$

# Python package name for yum
PYTHON_PKG=python36.x86_64

# Python package name for virtualenv --python=$PYTHON_ENV
PYTHON_ENV=python3.6

# Location of site-packages folder within the lib and lib64 folder within the
# virtualenv. This path string should start with $ENVDIR/lib[64]
LIB_SP=$ENVDIR/lib/python3.6/site-packages
LIB64_SP=$ENVDIR/lib64/python3.6/site-packages

# Echo Colours/Prefixes
H='\033[1;32m [REMOTE ENV]\033[0;35m' # Remote Host Message
M='\033[1;33m [LOCAL  ENV]\033[0;35m' # Regular Message (with prefix)
MN='\033[0;35m'                       # Regular Message (no prefix)
E='\033[1;31m [  ERROR  ]\033[0;31m'  # Error Message (with prefix)
EN='\033[1;31m'                       # Error Message (no prefix)
R='\033[0m'                           # Reset Colour (end of message)

###############################################################################
###                           +++  SCRIPT  +++                              ###
###############################################################################

# Sets up remote functions to run on AWS
function setRemote() {
	read -r -d '' REMOTERUN <<- EOF
	#### generateEnv.sh remote job ####
	# Check if Python is installed, if not then install it
	if yum list installed | grep -q $PYTHON_PKG; then
		echo -e "$H Found $PYTHON_PKG, continuing...$R"
	else
		sudo yum update -q -y
		echo -e "$H Not found $PYTHON_PKG, running yum update and installing...$R"
		sudo yum install -q -y $PYTHON_PKG
		if [ ! $? -eq 0 ]; then
			echo -e "$E yum exited with non 0 status code whilst installing $PYTHON_PKG$R" >&2
			exit 1
		fi
		echo -e "$H Installed $PYTHON_PKG, continuing...$R"
	fi

	# Set up virtualenv
	echo -e "$H Creating fresh new virtualenv...$R"
	virtualenv -q --python=$PYTHON_ENV $ENVDIR

	# Check set up correctly and activate virtualenv
	if [ ! $? -eq 0 ]; then
		echo -e "$E virtualenv exited with non 0 status code whilst initialising env$R" >&2
		exit 1
	fi
	cd $ENVDIR
	source ./bin/activate

	# Install user provided pip packages
	if [ ! -f $SCPDIR/$DEP ]; then
		if [ ! -r $SCPDIR/$DEP ]; then
			echo -e "$E Dependencies file does not exist/is not readable$R" >&2
		fi
	fi
	echo -e "$H Installing provided Python packages with pip...$R"
	xargs -a $SCPDIR/$DEP -I {} bash -c "yes | pip install --quiet {}"
	if [ ! $? -eq 0 ]; then
		echo -e "$E xargs/pip exited with non 0 status code whilst installing depndencies$R" >&2
		exit 1
	fi
	rm -rf $SCRPDIR/$DEP

	# ZIP up all the files
	cd $LIB_SP
	echo -e "$H Adding site-packages from lib to environment.zip...$R"
	zip -qr9 $ENVDIR/environment.zip .
	if [ ! $? -eq 0 ]; then
		echo -e "$E zip exited with non 0 status code whilst compressing lib's site-packages$R" >&2
		exit 1
	fi

	cd $LIB64_SP
	echo -e "$H Adding site-packages from lib64 to environment.zip...$R"
	zip -qur9 $ENVDIR/environment.zip .
	if [ ! $? -eq 0 ]; then
		echo -e "$E zip exited with non 0 status code whilst compressing lib64's sitepackages$R" >&2
		exit 1
	fi

	cd $SCPDIR
	echo -e "$H Adding user provided files to environment.zip...$R"
	zip -qur9 $ENVDIR/environment.zip .
	if [ ! $? -eq 0 ]; then
		echo -e "$E zip exited with non 0 status code whilst compressing user provided files$R" >&2
		exit 1
	fi

	deactivate
	echo -e "$H Complete! environment.zip has been created succesfully$R"
	EOF

	read -r -d '' REMOTECLEAN <<- EOF
	echo -e "$H Cleaning up remote files from environment generation process...$R"
	rm -rf $ENVDIR
	rm -rf $SCPDIR
	EOF
}

function main {
	# Check user folder path ends in /
	i=$((${#str}-1))
	if [ "${USER_FOLDER:$i:1}" != "/" ]; then
		USER_FOLDER="$USER_FOLDER/"
	fi

	# Extract dependencies file name
	DEP=$(basename $DEP_LOC)

	# Check if SSH identiy file was given, append necesary flag
	echo "SSH: $SSH_IDENTITY"
	if [ ! -z ${SSH_IDENTITY+x} ]; then
		SSH_IDENTITY="-i $SSH_IDENTITY"
	fi
	echo "SSH: $SSH_IDENTITY"
	exit 0

	# Set up the remote job variables
	setRemote

	# Create Remote SCP endpoint
	echo -e "$M Creating folder on remote host for user files...$R"
	ssh -o LogLevel=QUIET $SSH_IDENTITY $SSH_TARGET -t "mkdir $SCPDIR"

	# SCP over user defined files
	echo -e "$M Uploading user files...$R"
	scp -q $SSH_IDENTITY $USER_FOLDER* $SSH_TARGET:$SCPDIR
	scp -q $SSH_IDENTITY $DEP_LOC      $SSH_TARGET:$SCPDIR

	# Run Job
	ssh -o LogLevel=QUIET $SSH_IDENTITY $SSH_TARGET -t "$REMOTERUN"

	# Collect resulting envrionment.zip
	echo -e "$M Downloading resulting envrionment.zip to ./$R"
	scp -q $SSH_IDENTITY $SSH_TARGET:$ENVDIR/environment.zip ./

	# Cleanup
	ssh -o LogLevel=QUIET $SSH_IDENTITY $SSH_TARGET -t "$REMOTECLEAN"

	echo -e "$M \033[1;32mCompleted!\033[0;35m Check for any errors however it looks like it's fine!$R"
	exit 0
}

function printHelp {
	echo -e "$MN"
	echo "generateEnv - A Python Environment generator for AWS"
	echo "Usage: ./generateEnv.sh -d DEPENDENCIES -F FOLDER [OPTIONS] [USER@]IP"
	echo
	echo "Notes:"
	echo "  [USER@]IP is the AWS instance IP address, with optional username."
	echo
	echo "  The DEPENDENCIES file should have a list of valid pip packages on"
	echo "  individual lines. Invalid package names will cause adverse effects."
	echo
	echo "  Some parameters can be changed in variables in the top of the script"
	echo "  file. Config file coming soon - hopefully!"
	echo
	echo "  If arguments are given more than once, the last declared argument takes"
	echo "  the highest level of precedence."
	echo
	echo "Options are as follows:"
	echo "  -d DEPENDENCIES --dependencies  Location of file with pip depenedencies"
	echo "  -F FOLDER       --folder        Path of folder containing user files to"
	echo "                                  add to environment"
	echo "  -I IDENTIY      --identity      Path to SSH identity file for access"
	echo "  -h              --help          Shows this print out"
	echo -e "$R"
}

# Main Argument Parsing loop
if [ $# -ge 5 ]; then
	while [ $# -gt 1 ]; do
		case $1 in
			-d|--dependencies)
				shift
				DEP_LOC=$1
				shift
				;;
			-F|--folder)
				shift
				USER_FOLDER=$1
				shift
				;;
			-I|--identity)
			    shift
			    SSH_IDENTITY=$1
			    shift
			    ;;
			-h|--help)
				help
				exit 0
				;;
			*)	echo "Unrecognized argument, please refer to help." >&2
				help
				exit 1
				;;
		esac
	done
	SSH_TARGET=$1
	main
else
	while [ $# -gt 0 ]; do
		if [ "$1" == "--help" -o "$1" == "-h" ]; then
			printHelp
			exit 0
		else
			shift
		fi
	done
	echo -e "$E Not enough arguments given.. Did you provide an IP address?"
	echo -e "$E Stopping.$R" >&2
	printHelp
	exit 1
fi
