
# Linux Java JDK Installer

Based on the [askubuntu.com posting](https://askubuntu.com/questions/56104/how-can-i-install-sun-oracles-proprietary-java-jdk-6-7-8-or-jre), I created a Bash script to install either OpenJDK or Oracle Java JDK version 9 or higher in Debian Linux.  The script does not download the JDK, at least not in this release. The idea behind it was to provide greater control on what version of the JDK is installed as well as greater security by not relying on PPAs.  It is, therefore, up to the user to download the correct bit version of the JDK from a reliable source, like [OpenJDK](http://openjdk.java.net/) or [Oracle](https://www.oracle.com/technetwork/java/index.html).

The script does not support installing JDK 8 since it's end of life is right around the corner, January 2019.

It was tested in Ubuntu 14.04 LTS and 16.04 LTS.

## Usage

Once you download the script file, grant execute permissions as follow:

    chmod +x installJavaJDK.sh

The script expects two parameters - JDK `tar` file and its SHA256 sum value.  You must run it with sudo.  For example,

    sudo ./installJavaJDK.sh jdk-10_linux-x64_bin.tar.gz 0b14aaecd5323457bd15dc7798d08181ad04bad4156e55387ed714190912a9ce

Executing it with no parameters, or `-h`, or `-help` will print the help.

## What It Does?

The script performs the following:  

1. **Validate Parameters**: based in the name, it will determine and inform you whether you're installing an Oracle provided OpenJDK or Oracle JDK.  It will then confirm the provided SHA256 sum value matches that for the provided JDK `tar` file.

2. **Extract JDK File**: extracts the provided JDK `tar`, and confirm, based on naming convention, whether the extracted folder is a JDK folder.

3. **Check if JDK is Already Installed**: The scripts checks if there is a JDK installed by running `javac -version`.  If it successfully runs, it then checks how the installed JDK was configured by looking up the system's alternatives.  The script will only installed the specified JDK if there is no JDK installed or if the current one was configured through alternatives.

4. **Removes Previous Versions**: the script will remove the JDK it previously installed.  This step also includes removing configuration settings done through `update-alternatives`.

5. **Move Extracted JDK to Folder**: moves the extracted JDK to `/usr/lib/jvm/jdk-*`.  For example if installing JDK 10, the folder will be `/usr/lib/jvm/jdk-10`.

6. **Configure JDK Programs**: configure the following programs using `update-alternatives`:

    * java
    * javac
    * jar
    * javadoc
    * jshell
    * jlink
    * jmod
    * javap
    * jdeps
    * jarsigner
    * jconsole

7. **Run java -version**: last step of the installation, the script will run `java -version` to confirm the installed version was properly configured.

## What It Doesn't Do?

The script does not setup Java to run in FireFox.  This was done intentionally since this is a security risk.  Please refer to original article for instructions on how to do this.

## Future

Time permitting, looking to add the following functionality:

* Add support to install OpenJDKs from [AdoptOpenJDK](https://adoptopenjdk.net/) and [Azul Systems](https://www.azul.com/downloads/zulu-community/?architecture=x86-64-bit&package=jdk).  Now a days, there are more JDK providers the just Oracle.

* Provide the ability to install a JDK without removing the current one.  Handy feature that will allow to install more than one JDK in order to evaluate it while still coding for a previous version.

* Install JDK but do not configured to be the active version.  Goes hand-in-hand with the previous enhancement.  Again, install the latest or an early access to play with it, but do not change the system configurations to point to it.

* Update system configurations to point to another JDK.  Still in the same theme... provide the ability to update system configurations to point to another installed JDK.  That means, for example, you can have version 14 and 15 installed, and easily switch configurations between one and the other.

* Removed a specify JDK previously installed by the script.  This provide a clean way to remove an installed JDK that's no longer supported or just don't need.

## License

This script is provided under MIT license.


