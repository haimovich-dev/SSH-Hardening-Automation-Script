# SSH Hardening Automation script
## Foreword
The goal for this project is to build a script that will automate the process of hardening OpenSSH in Linux environemnts, I decided to firstly build the logic of the script to document and explain the reason for each action taken in the script, in that way it will be possible to learn from this repository and edit the script more easily for your own needs.

Security is directly influenced by the version of the used software and its configurations, and these are the topics that the script covers.

This script is supported only on **Debian/Fedora** base distributions, take that in mind that after understanding its logic, you will be able to change the script for your own needs.

## 1 - Initial Preperation
Before changing anything in the system, it is mandatory to gather the current state of the system, different related information that will be used by the script when taking spesific actions, for example saving the current SSH keys.

### 1.1 - Distribution and Packet Manager
After the script is downloaded and executed on the machine, it must understand if its **Fedora/Ubuntu** based to determine if it should use `apt/dpkg` or `dnf/rpm`. there is a 'systemd' standard that says `/etc/os-release` should exist. Because 'systemd' is used by most of the distirbutions, the script will rely on it when determining the package manager and will also verify it by check under the `/bin` directory.

Varriables used in the script:

- "BASE_DISTRO": Fedora/Debian, otherwise stop the script and through an incompetability error.
- "PKGMGR": systems package manager dnf/apt
- "PKGMGRTL": package manager tool rpm/dpkg

### 1.2 - Required Packages
Installing software from source, compiling it, and building requries additional packages that will allow to achieve the desired state. below is a list of the packages and why they are needed.

- "GCC": A C compiler used by "Make" to compile .c files into binaries (Version C89 and above are requried)
- "Make": A builder package that compiles the source files, creates the directories and all the dependencies, uses the 'MakeFile' after running the configure.ac file.
- "wget": non-interactive file downloader, will be used to download the source from the OpenSSH website

If one or more of the packages are missing, the script will install them with the previouslt found packaet manager.

### 1.3 - Libraries
This section is more complicated, when I tried to install OpenSSH I succeded but saw that its using OpenSSL, I started my research and found out that it is a software that provides cryptographic ciphers and algorithms, and OpenSSH uses that by libcrypto library that is provided by OpenSSL. So I've decided to reinstall the library and overrode the previous version with a newer one, the OpenSSH worked and showed me the newer version, but the next time I tried to boot my machine it failed saying that dbus.service was unable to load, so I tried to boot into rescue mode and also didn't succed. Later figured out that OpenSSL is used by system critical processes.

That leads us to installing newer version of libraries statically and telling the 'Make' to embbed them into the binaries instead of using the linker. the only downside I found in it is that the binaries sizes are higher.

Below is a table with all the libraries that OpenSSH can depend on, different libraries provide different features.

|Library/Package Name|Version|Include|Description|
|---|---|---|---|
|OpenSSL| 1.1.1 >= |High|Cryptographic ciphers and algorithms (Update if needed)|
|libedit| --- |Medium|Used for interactive SFTP CLI editing|
|PAM| --- |Medium|Provides additional authentication methods|
|ldns| --- |Medium|Enable SSHFP records with DNSSEC|
|zlib| 1.2 >=|Low|Allows traffic compression, known attack vectors|
|libfido2| 1.5 >=|Low|Allows hardware key authentication|
|Autoconf & Automake| --- |No|Only for editing configure.ac file (Developers)|
|Makedepend| --- |No|Only if you change source code to update dependencies|
|GNOME| --- |No|Used in desktop environments, irrelevant|
|x11-ssh-askpass| --- |No|Used in desktop environments, irrelevant|
|PRNGD/EGD| --- |Depends|If /dev/random does not exist (Legacy)|
|BSM| --- |Depends|Auditing for Solaris/FreeBSD/MacOS (Out of the scope)|

At this point the script will scan for currently installed libraries and its versions with `dpkg/dnf` (depending on the OS distribution), then asking the user which libraries to install. according to the table, the script will prompt the user about every library that is marked as low and above. PRNGD/EGD requries additional testing of `/dev/random` if exist then skip, otherwise install without asking the user but log the decision.

