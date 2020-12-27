#!/bin/bash

# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
#
# MIT License
# 
# Copyright (c) 2018 Jose Henriquez [https://github.com/jhenriquez418/linux-java-jdk-installer]
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  

# enumerator values to determine the current JDK configuration status...
readonly NOT_INSTALLED=0
readonly INSTALLED_BY_SCRIPT=1
readonly INSTALLED_NOT_CONFIGURED=2
readonly INSTALLED_POINTS_TO_ANOTHER_JDK=3

# enumerator values for available commands...
readonly INSTALL=0
readonly DELETE=1
readonly LIST=2

# enumerator values for supported JDK providers...
readonly ADOPTOPENJDK=0
readonly ZULU=1
readonly ORACLE=2
readonly UNSUPPORTED=3

# Open JDK provider file formats...
readonly ADOPTOPENJDK_FILE_FORMAT="OpenJDK([0-9]){2,}U-jdk_x64_linux_(hotspot|openj9)_([0-9]){2,}(\.[0-9]){0,3}_([0-9]){1,3}(_openj9-([0-9]){1,3}(\.([0-9]){1,3}){2})?\.tar\.gz"
readonly ZULU_FILE_FORMAT="zulu([0-9]){1,3}(\.([0-9]){1,3}){2}-ca-jdk([0-9]){2,}(\.[0-9]){0,3}-linux_x64.tar.gz"
readonly ORACLE_FILE_FORMAT="openjdk-([0-9]){2,}(\.[0-9]){0,3}_linux-x64_bin.tar.gz"

readonly SCRIPT_VERSION="1.2.0"

# Global variables...
processComand=-1
currentJDKStatus=-1
jdkTarSource=-1
jdkInstalledVersion=""
jdkVersionToInstall=""
systemJavaDir="/usr/lib/jvm"

jdkProvider=$UNSUPPORTED
processorType=$(getconf LONG_BIT)
jdkExtractedDir=""
keepPreviousJDK=false
doNotConfigure=false

# Assign parameters... 
# JDK file
sourceFile=""
# JDK's sha256sum value
sha256sum=""


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Prints the help info and exits the script...
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
printHelpAndExit()
{
	echo ""
	echo "Installs the provided JDK.  It confirms the tar SHA256 sum matches that of the provided value and performs simple validation to verify the provided tar file contains a JDK folder.  Script can intall JDKs version 9 or higher from AdoptOpenJDK, Oracle, or Zulu.  Installation script has been tested on Ubuntu.  Go to project home page (https://github.com/jhenriquez418/linux-java-jdk-installer) for further info."
	echo ""
	echo "Script must be executed with sudo.  For example:"
	echo ""
	echo "sudo ./installJavaJDK jdk-10_linux-x64_bin.tar.gz 0b14aaecd5323457bd15dc7798d08181ad04bad4156e55387ed714190912a9ce"
	echo ""
	echo ""
	echo "The script provides the following parameter options when installing a JDK:"
	echo ""
	echo "  -h  prints this help.  This is the same as running the script without any parameters."
	echo ""
	echo "  -k  keep previously installed JDK when installing a new one, meaning it will not delete the JDK folder but will remove system configurations."
	echo ""
	echo "  -N  installs specified JDK but does not configure it as the default.  This option keeps the previously installed JDK and configurations settings."
	echo ""
	echo ""
	echo "installJavaJDK version $SCRIPT_VERSION"
	echo "Copyright (c) 2018 Jose Henriquez [https://github.com/jhenriquez418/linux-java-jdk-installer]"
	echo "MIT License"
	echo ""
	echo 'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.'
	echo ""
	exit

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Assigns internal processing flags based on the passed parameters.  Function may
# be called itself if processing paramters are group - i.e. -kN
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
readParameter()
{
	# Assigning parameters to variables for readability...
	areBundled=$1
	paramToProcess=$2

	case  ${paramToProcess:0:1} in 
		"h")
			printHelpAndExit
			;;

		"k")
			keepPreviousJDK=true
			;;

		"N")
			doNotConfigure=true
			keepPreviousJDK=true
			;;

		 * )
			echo "Unknown parameter [${paramToProcess:0:1}].  Type -h for available options"
			exit
			;;
	esac
	
	if [[ ${areBundled} = true && -n ${paramToProcess:1} ]]; then
		readParameter true ${paramToProcess:1}
		
	fi 

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Parses the passed script command line arguments to read the parameters (if any), 
# source file, and sha256 value.
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
parseParameters()
{
	# Our special case, no parameters which means print help...
	if [ $# = 0 ]; then
		printHelpAndExit;

	fi

	# Default behavior is to install a JDK unless otherwise requested...
	processCommand=$INSTALL

	# Read any script options the user may have provided; they must be specifed first!
	while [[ -n $1 && ${1:0:1} = '-' ]]
	do
		if [ -z ${1:2} ]; then
			# Single parameter...
			readParameter false ${1:1}
		else
			# Grouped parameters...
			readParameter true ${1:1}
		fi
		shift
	done
	
	# Next value is the source file, if provided...
	if [ -n "$1" ]; then
		sourceFile=$1
		shift
	fi

	# Last, the SHA sum.  Again, if provided...
	if [ -n "$1" ]; then
		sha256sum=$1
	fi

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Determines the JDK source, i.e. AdoptOpenJDK, Zulu, or Oracle, and version based 
# on the tar name.  Returns 0 (true) if it's invalid, otherwise 1 (false).
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
isNotValidJDKSource()
{
	# Run through the three supported open JDK format files to identify which one we're working with...
	if [[ $sourceFile =~ $ADOPTOPENJDK_FILE_FORMAT ]]; then
		echo "Source file is an AdoptOpenJDK...."
		jdkVersionToInstall=$(echo $sourceFile | cut -d'_' -f 5)
		# Location of what looks like a build number will be different depending if the JDK has openj9 or hotspot JVM...
		if [[ $jdkToInstallVersion =~ "openj9" ]]; then
			buildNumber=$(echo $sourceFile | cut -d'_' -f 6)
		else
			buildNumber=$(echo $sourceFile | cut -d'_' -f 6 | cut -d'.' -f 1)
		fi
		jdkExtractedDir="jdk-$jdkVersionToInstall+$buildNumber"
		jdkProvider=$ADOPTOPENJDK
	fi

	if [[ $sourceFile =~ $ZULU_FILE_FORMAT ]]; then
		echo "Source file is a Zulu JDK...."
		jdkVersionToInstall=$(echo $sourceFile | cut -d'-' -f 3)
		jdkVersionToInstall=${jdkVersionToInstall:3}
		jdkExtractedDir=${sourceFile:0:${#sourceFile}-7}
		jdkProvider=$ZULU_FILE_FORMAT
	fi

	if [[ $sourceFile =~ $ORACLE_FILE_FORMAT ]]; then
		echo "Source file is an Oracle JDK...."
		jdkVersionToInstall=$(echo ${sourceFile:8} | cut -d'_' -f 1)
		jdkExtractedDir="jdk-$jdkVersionToInstall"
		jdkProvider=$ORACLE	
	fi

	if [ $jdkProvider != $UNSUPPORTED ]; then
		echo "JDK version number to install is [$jdkVersionToInstall]..."
		return 1
	fi

	return 0

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Validate provided sha256 value against the provided JDK file.  Returns 0 (true) if
# it does not match, otherwise 1 (false).
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
isInvalidShaSum()
{
	# Compare sha256 value...
	shaSUM=$(sha256sum $sourceFile)
	shaSumValue=${shaSUM:0:64}
	shaSumFile=${shaSUM:66}

	if [ "$sha256sum" != "$shaSumValue" ]; then
		echo "Provided SHA sum value does not match the SHA value for the provided JDK file.  Validation failed!  Process will end."
		return 0
	elif [ "$sourceFile" != "$shaSumFile" ]; then
		echo "SHA sum file name does not match the provided JDK file name.  Validation failed!  Process will end."
		return 0
	fi

	return 1

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Validate we have the correct params...
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
validateParams() 
{
	echo "*-*-*-*-*           Validating script parameters             *-*-*-*-*"
	echo ""

	# Verify the running user is root!
	if [ $USER != "root" ]; then
		echo "You must run installation script with root.  Validation failed!  Process will end."
		exit
	fi

	# Confirm the user provided the JDK file name to process...
	if [ -z "$sourceFile" ]; then 
		echo "You must provide a JDK tar file to work with.  Validation failed!  Process will end."
		exit
	fi 

	# Confirm the user provided the sha256sum value for the passed JDK...
	if [ -z "$sha256sum" ]; then
		echo "You must provide the SHA256 value for the specified JDK.  Validation failed!  Process will end."
		exit
	fi

	# Validate the source JDK file against supported open JDKs...
	if isNotValidJDKSource; then
		echo "The specified [$sourceFile] JDK tar file is not from AdoptOpenJDK, Zulu, or Oracle.  The script cannot install this JDK.  Process will end."
		exit
		
	fi
	
	# Verify the specified parameter file exists...
	if [ ! -e $sourceFile ]; then
		echo "Source file [$sourceFile] does not exist in the current directory.  Validation failed!  Process will end."
		exit
	fi
	echo "Specified source file [$sourceFile] exists in the specified directory!"

	# Validate provided SHA256 sum value against file...
	echo "Validating SHA256 value..."
	if isInvalidShaSum; then
		exit
	fi
	echo "Provided value matched!"

	# If we're here is because all validations passed!
	echo "Source file [$sourceFile] seems to be a JDK file from one of the supported vendors!"
	
	echo "Input parameter validation passed!"
	echo ""

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Detect if Java is already installed.  Returns true (0) if it is, otherwise false (1).
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
isJDKInstalled() 
{
	echo "*-*-*-*-*     Checking system to see if JDK is installed     *-*-*-*-*"
	echo 

	echo "Will confirm by checking if Java compiler (javac) is installed..."

	# Get where system is looking for Java...
	jdkInstalledPath=$(su -l -c "javac -version" $SUDO_USER)
	if [ -z "$jdkInstalledPath" ]; then
		# Got nothing, so Java is not set up in the system!
		currentJDKStatus=$NOT_INSTALLED
	else
		# JDK is installed!  Check if it's configured through alternatives...
		echo "A JDK is installed!"
		echo
	    echo "Checking if Java is configured using alternatives..."

		# This time will check Java instead...
		jdkInstalledPath=$(sudo update-alternatives --display java | grep -i "link currently points to" | cut --characters=28-)
		if [ -z "$jdkInstalledPath" ]; then
			# We got nothing, so it's not configured through alternatives!
			echo "It is not!"
			currentJDKStatus=$INSTALLED_NOT_CONFIGURED
		else
			echo "It is!"

			# There is an alternative! Check if it's pointing to a script installed path...
			if [ ${jdkInstalledPath:0:17} = "$systemJavaDir/jdk-" ]; then
				# It is!
				currentJDKStatus=$INSTALLED_BY_SCRIPT
				jdkInstalledVersion=$(echo ${jdkInstalledPath:17} | cut -d'/' -f 1)		
			else
				# It is not!  Is it configured but not pointing to the script installed JDK?
				jdkInstalledPath=$(sudo update-alternatives --list java | grep -i "$systemJavaDir/jdk-" | cut -d'/' -f 5)
				if [ -z "$jdkInstalledPath" ]; then
					# Negative!  We never installed it...
					currentJDKStatus=$INSTALLED_NOT_CONFIGURED
				else
					# So we did installed a version once, but but it's pointing to another JDK!
					jdkInstalledVersion=${jdkInstalledPath:4}
					currentJDKStatus=$INSTALLED_POINTS_TO_ANOTHER_JDK
				fi
			fi
		fi
	fi

	# Lastly, inform the user what we found...
	echo ""
	case $currentJDKStatus in
		$NOT_INSTALLED) 
			echo "JDK is not installed!"
			;;

		$INSTALLED_BY_SCRIPT)
			echo "Current JDK was installed by this script! Installed version is $jdkInstalledVersion."
			;;

		$INSTALLED_NOT_CONFIGURED)
			# We are terminating!  Clean up first...
			rm -r -f $jdkExtractedDir

			# Now tell the user the script is terminating and why!
			echo "A JDK is installed, but it's configured through the system path.  Since this was not done through system's alternatives, the script cannot properly remove the current settings!"
			echo
			echo "Please manually remove the installed JDK and the re-run the script to install the new JDK."
			echo 
			echo "The script will terminate."
			;;

		$INSTALLED_POINTS_TO_ANOTHER_JDK)
			echo "The script previously installed version $jdkInstalledVersion, but Java is pointing to another JDK/JRE!"

	esac
	echo ""

	if [[ $currentJDKStatus = $NOT_INSTALLED || $currentJDKStatus = $INSTALLED_NOT_CONFIGURED ]]; then
		return 1
	fi

	return 0
}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Extract the provided tar file and validate the extracted folder is a JDK folder
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
extractAndValidateJDK() 
{
	echo "*-*-*-*-*                Extracting JDK File                 *-*-*-*-*"
	echo

	# Before extracting, make sure there is no JDK directory in the working folder...
	# For that, declare an array and read files that start with jdk-*
	echo "Checking for previous JDK folders in working directory..."
	declare -a jdkFiles

	jdkFiles=( ./jdk-* )
	deletedFolders=false

	# Now traverse the array looking for directories...
	for (( x=0;x<${#jdkFiles[@]};x++ )); do
		if [ -d ${jdkFiles[$x]} ]; then
			deletedFolders=true
			echo ""
			echo "There is a previous JDK directory in working path - deleting it!"
			rm -r -f ${jdkFiles[${x}]}
			echo "JDK directory [${jdkFiles[${x}]}] deleted!"
			echo ""
		fi

	done

	if [ $deletedFolders = false ]; then
		echo "No folders found!"
		echo ""
	fi

	echo "Extracting JDK files..."
	tar -xf $sourceFile
	echo "Validating uncompressed tar file..."
	if [ ! -d $jdkExtractedDir ]; then
		echo "No JDK $jdkVersionToInstall directory was extrated from the file!  Please validate the provided tar file is for a JDK.  Process will end."
		exit
	else
		echo "Confirmed!  Extrated a valid JDK!"
		echo
	fi
	echo "JDK was extracted!"
	echo ""

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Sync the extrated JDK folder to final destination
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
moveJDKToSysFolder() 
{
	echo "*-*-*-*-*            Moving JDK to system folder             *-*-*-*-*"
	echo  
	if [ ! -d "$systemJavaDir/jdk-$jdkVersionToInstall" ]; then
		echo "Creating JDK folder for new JDK..."
		sudo mkdir -p "$systemJavaDir/jdk-$jdkVersionToInstall"
		echo "Folder created!"

	fi

	echo "Moving extracted JDK to [$systemJavaDir/jdk-$jdkVersionToInstall]..."
	sudo rsync -rl $jdkExtractedDir"/" "$systemJavaDir/jdk-$jdkVersionToInstall"
	echo "JDK moved to system folder!"
	echo ""
	rm -r -f $jdkExtractedDir
	echo "Deleting extracted files..."
	echo ""

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Remove existing configuration if JDK is already installed
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
removeCurrentConfiguration() 
{
	# There are two conditions when we need to remove the configured alternatives - 
	# INSTALLED_BY_SCRIPT and INSTALLED_POINTS_TO_ANOTHER_JDK!

	if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
		echo "*-*-*-*-*         Removing previous JDK configuration        *-*-*-*-*"
		echo ""

		if [[ $doNotConfigure = true ]]; then
			echo "Requested not to configure new JDK, therefore keeping current JDK alternatives to point to the previously installed JDK..."
			echo ""
			return
		fi

		# Be a good citizen and only remove the alternatives that we have created!
		echo "Removing configured alternatives..."
		echo

		# Removing java...
		echo "java..."
		sudo update-alternatives --quiet --remove "java" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/java" 
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing javac...
		echo "javac..."
		sudo update-alternatives --quiet --remove "javac" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/javac"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing jar...
		echo "jar..."
		sudo update-alternatives --quiet --remove "jar" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/jar"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		#Configuring javadoc...
		echo "javadoc..."
		sudo update-alternatives --quiet --remove "javadoc" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/javadoc"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing jshell...
		echo "jshell..."
		sudo update-alternatives --quiet --remove "jshell" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/jshell"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing jlink...
		echo "jlink..."
		sudo update-alternatives --quiet --remove "jlink" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/jlink"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing jmod...
		echo "jmod..."
		sudo update-alternatives --quiet --remove "jmod" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/jmod"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing javap...
		echo "javap..."
		sudo update-alternatives --quiet --remove "javap" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/javap"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing jdeps...
		echo "jdeps..."
		sudo update-alternatives --quiet --remove "jdeps" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/jdeps"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing jarsigner...
		echo "jarsigner..."
		sudo update-alternatives --quiet --remove "jarsigner" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/jarsigner"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 

		# Removing jconsole...
		echo "jconsole..."
		sudo update-alternatives --quiet --remove "jconsole" "$systemJavaDir/jdk-$jdkInstalledVersion/bin/jconsole"
		if [ $? = 0 ]; then
			echo "Removed!"
		else
			echo "Huummm... there was an error!  We'll continue anyway..."
		fi
		echo 
		echo "Removed configured alternatives for previous installed JDK."
		echo

		if [ $keepPreviousJDK = false ]; then
			# User requested not to keep the previously installed JDK, so delete it...
			sudo rm -rf $systemJavaDir/jdk-$jdkInstalledVersion
			echo "Deleted previously installed JDK folder..."
		else
			echo "Previous installed JDK folder was not removed, as requested..."
		fi

		echo ""
		echo "Done!  Removed previously installed JDK version $jdkInstalledVersion configuration!"
		echo ""

	fi

 }


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# Configure JDK program alternatives (links)
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
configureJDKUtilities() 
{
	echo "*-*-*-*-*        Configuring alternatives for new JDK        *-*-*-*-*"
	echo

	if [ $doNotConfigure = true ]; then
		# User requested not to configure the JDK, so exit!
		echo "JDK utilities were not configured as requested!"
		echo ""
		return 0;
	fi

	echo "The following JDK utilities will be configured in the system's alternatives: "
	echo ""

	userConfigMsg=""

	# Configuring java...
	echo "java..."
	sudo update-alternatives --quiet --install "/usr/bin/java" "java" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/java" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			# I'm concluding the set will not failed since we successfully added the alternative!
			sudo update-alternatives --quiet --set "java" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/java"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"java\"!"
	fi
	echo 

	# Configuring javac...
	echo "javac..."
	sudo update-alternatives --quiet --install "/usr/bin/javac" "javac" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/javac" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "javac" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/javac"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"javac\"!"
	fi
	echo 

	# Configuring jar...
	echo "jar..."
	sudo update-alternatives --quiet --install "/usr/bin/jar" "jar" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jar" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "jar" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jar"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"jar\"!"
	fi
	echo 

	# Configuring javadoc...
	echo "javadoc..."
	sudo update-alternatives --quiet --install "/usr/bin/javadoc" "javadoc" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/javadoc" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "javadoc" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/javadoc"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"javadoc\"!"
	fi
	echo 

	# Configuring jshell...
	echo "jshell..."
	sudo update-alternatives --quiet --install "/usr/bin/jshell" "jshell" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jshell" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "jshell" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jshell"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"jshell\"!"
	fi
	echo 

	# Configuring jlink...
	echo "jlink..."
	sudo update-alternatives --quiet --install "/usr/bin/jlink" "jlink" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jlink" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "jlink" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jlink"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"jlink\"!"
	fi
	echo 

	# Configuring jmod...
	echo "jmod..."
	sudo update-alternatives --quiet --install "/usr/bin/jmod" "jmod" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jmod" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "jmod" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jmod"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"jmod\"!"
	fi
	echo 

	# Configuring javap...
	echo "javap..."
	sudo update-alternatives --quiet --install "/usr/bin/javap" "javap" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/javap" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "javap" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/javap"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"javap\"!"
	fi
	echo 

	# Configuring jdeps...
	echo "jdeps..."
	sudo update-alternatives --quiet --install "/usr/bin/jdeps" "jdeps" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jdeps" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "jdeps" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jdeps"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"jdeps\"!"
	fi
	echo 

	# Configuring jarsigner...
	echo "jarsigner..."
	sudo update-alternatives --quiet --install "/usr/bin/jarsigner" "jarsigner" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jarsigner" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "jarsigner" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jarsigner"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"jarsigner\"!"
	fi
	echo 

	# Configuring jconsole...
	echo "jconsole..."
	sudo update-alternatives --quiet --install "/usr/bin/jconsole" "jconsole" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jconsole" 1
	if [ $? = 0 ]; then
		if [[ $currentJDKStatus = $INSTALLED_BY_SCRIPT  || $currentJDKStatus = $INSTALLED_POINTS_TO_ANOTHER_JDK ]]; then
			sudo update-alternatives --quiet --set "jconsole" "$systemJavaDir/jdk-$jdkVersionToInstall/bin/jconsole"
		fi	
		echo "Configured!"
	else
		echo "Failed to configured \"jconsole\"!"
	fi

	echo ""	
	echo "Primary JDK utilities have been configured!"
	echo ""

}


# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
# 									Main
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*  
parseParameters "$@"

# We are here because the user wants to install the provided JDK - the default behavior of the script...
validateParams
extractAndValidateJDK
# Do we need to remove any system configurations from a previosly installed JDK?
if isJDKInstalled; then
	# Yes!  Removing existing settings even if it's the same Java version; original install may have failed!
	removeCurrentConfiguration;
fi	

# Exit the installation if there is a JDK installed outside of the system configurations - i.e. $PATH
if [ $currentJDKStatus = $INSTALLED_NOT_CONFIGURED ]; then
	exit
fi

moveJDKToSysFolder
configureJDKUtilities

if [ $doNotConfigure = true ]; then
	echo "Running 'java -version' to verify previously installed JDK is still configured..."
else
	echo "Running 'java -version' to verify new JDK installation..."
fi
echo 
echo `java -version`



