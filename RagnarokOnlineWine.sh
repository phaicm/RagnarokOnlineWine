#!/bin/bash

RAGNAROK_ONLINE_DOWNLOAD_LOCATION=https://www.example.com/download/exampleInstaller.exe
RAGNAROK_ONLINE_INSTALLATION_EXECUTABLE=exampleInstaller.exe
RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH="Games/exampleRO"
RAGNAROK_ONLINE_GAME_EXECUTABLE=exampleRO.exe
RAGNAROK_ONLINE_PATCHER_EXECUTABLE=Example\ Patcher.exe
RAGNAROK_ONLINE_PATCHER_EXECUTABLE_ESCAPED=Example\\\ Patcher.exe
RAGNAROK_ONLINE_ICON=example.png
RAGNAROK_ONLINE_ICON_LOCATION=https://www.example.com/images/example.png

REQUIRED_WINE_MAJOR=4
REQUIRED_WINE_MINOR=0
REQUIRED_WINE_PATCH=2


WINETRICKS_DOWNLOAD_LOCATION=https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
OPERATING_SYSTEM=$(uname -s)


function FATAL_ERROR
{
	local message="${1}"
	echo "${message}" >&2
	exit 1
}

function setup_mac
{
	if [ $OPERATING_SYSTEM = "Darwin" ]; then
		xcode-select --install
		which -s brew
		if [[ $? != 0 ]] ; then
			ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
		else
			brew update

		fi
		brew install wget
		brew install wine
	fi
}

function check_operating_system
{
	if [ $OPERATING_SYSTEM = "Darwin" ]; then
		OPERATING_SYSTEM=Darwin
	elif [ $OPERATING_SYSTEM = "Linux" ]; then
		OPERATING_SYSTEM=Linux
	elif [ $OPERATING_SYSTEM = "FreeBSD" ]; then
		OPERATING_SYSTEM=Linux
	elif [ $OPERATING_SYSTEM = "SunOS" ]; then
		OPERATING_SYSTEM=Linux
		FATAL_ERROR "RagnarokOnlineWine: Unsupported operating system."
	fi
}

function check_wine_version
{
	current_wine_major=$(wine --version | sed -nE "s,^wine-([[:digit:]])\.([[:digit:]])\.([[:digit:]]),\1,p")
	current_wine_minor=$(wine --version | sed -nE "s,^wine-([[:digit:]])\.([[:digit:]])\.([[:digit:]]),\2,p")
	current_wine_patch=$(wine --version | sed -nE "s,^wine-([[:digit:]])\.([[:digit:]])\.([[:digit:]]),\3,p")

	if (( ${current_wine_major} >= ${REQUIRED_WINE_MAJOR} )); then
		if (( ${current_wine_minor} >= ${REQUIRED_WINE_MINOR} )); then
			if (( ${current_wine_patch} >= ${REQUIRED_WINE_PATCH} )); then
				echo "RagnarokOnlineWine: Wine Verion accepted"
			else
				FATAL_ERROR 'RagnarokOnlineWine: Wine Version Patch failed. Please update Wine.'
			fi
		else
			FATAL_ERROR 'RagnarokOnlineWine: Wine Version Minor failed. Please update Wine.'
		fi
	else
		FATAL_ERROR 'RagnarokOnlineWine: Wine Version Major failed. Please update Wine.'
	fi
}

function setup_new_wine
{
	read -r -p "RagnarokOnlineWine: Setting up new Wine Prefix. This will delete all files in your /.wine folder. Do you want to do this? [y/N] " response
	case "$response" in
		[yY][eE][sS]|[yY]) 
	    	sudo rm -rf $HOME/.wine
			WINEARCH=win32 wineboot --init
			;;
		*)
			echo "RagnarokOnlineWine: Skipping"
			;;
	esac
}

function get_winetricks
{
	case ${OPERATING_SYSTEM} in
		Darwin)
			brew install winetricks || FATAL_ERROR 'RagnarokOnlineWine: Could not brew winetricks'
			;;
		Linux)
			wget ${WINETRICKS_DOWNLOAD_LOCATION} || FATAL_ERROR 'RagnarokOnlineWine: Could not wget winetricks'
			chmod +x winetricks
			sudo cp winetricks /usr/bin
			rm -f winetricks
			;;
	esac
}

function install_winetricks_libraries
{
	winetricks --unattended corefonts 
	winetricks --unattended d3dx9_42 
	winetricks --unattended d3dx9_43
	winetricks --unattended dinput 
	winetricks --unattended dinput8 
	winetricks --unattended vcrun2008 
	winetricks --unattended vcrun2010 
	winetricks --unattended vcrun2013 
	winetricks --unattended vcrun2015 
	winetricks --unattended vcrun6

	winetricks --force --unattended dotnet35
	status=$?
	case $status in
		0)
			;;
		105)
			;;
		194)
			;;
		*)
			echo "RagnarokOnlineWine: DotNet35 Failed. Trying DotNet35 SP1."
			winetricks --force --unattended dotnet35sp1
	esac
	winetricks --force --unattended dotnet461
}

function change_wine_settings
{
	winetricks vd=1280x720
}

function install_ragnarok_online

{
	wget ${RAGNAROK_ONLINE_DOWNLOAD_LOCATION} || FATAL_ERROR 'RagnarokOnlineWine: Could not wget Ragnarok Installation'
	wine ${RAGNAROK_ONLINE_INSTALLATION_EXECUTABLE}
}

function optimize_for_ragnarok
{
	wine reg add 'HKCU\Software\Wine\AppDefaults\'${RAGNAROK_ONLINE_GAME_EXECUTABLE}'\Direct3D' /v csmt /t REG_DWORD /d 1 /f 2>/dev/null
	wine reg add 'HKCU\Software\Wine\AppDefaults\'${RAGNAROK_ONLINE_GAME_EXECUTABLE}'\Direct3D' /v RenderTargetLockMode /t REG_SZ /d disabled /f 2>/dev/null
	wine reg add 'HKCU\Software\Wine\AppDefaults\'${RAGNAROK_ONLINE_GAME_EXECUTABLE}'\Direct3D' /v DirectDrawRenderer /t REG_SZ /d opengl /f 2>/dev/null
	wine reg add 'HKCU\Software\Wine\AppDefaults\'${RAGNAROK_ONLINE_GAME_EXECUTABLE}'\Direct3D' /v Multisampling /t REG_SZ /d disabled /f 2>/dev/null
}

function create_shortcuts
{
	wget -O $HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH}/${RAGNAROK_ONLINE_ICON} ${RAGNAROK_ONLINE_ICON_LOCATION}


	case ${OPERATING_SYSTEM} in
		Darwin)
			echo "#!/bin/bash"  >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.command"
			echo "" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.command"
			echo "wineserver -k " >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.command"
			echo "cd \$HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH}" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.command"
			echo "WINEDEBUG=warn+all,-d3d,-d3d_perf,-wgl,-ntdll wine ${RAGNAROK_ONLINE_GAME_EXECUTABLE}" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.command"
			sips -s format icns $HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH}/${RAGNAROK_ONLINE_ICON} --out tmpicns.icns
			echo "read 'icns' (-16455) \"tmpicns.icns\";" >> tmpicns.rsrc
			Rez -a tmpicns.rsrc -o ${RAGNAROK_ONLINE_GAME_EXECUTABLE}.command
			SetFile -a C ${RAGNAROK_ONLINE_GAME_EXECUTABLE}.command
			rm -f tmpicns.icns
			rm -f tmpicns.rsrc
			chmod u+x "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.command"

			echo "#!/bin/bash"  >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.command"
			echo "" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.command"
			echo "wineserver -k " >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.command"
			echo "cd \$HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH}" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.command"
			echo "WINEDEBUG=warn+all wine ${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.command"
			sips -s format icns $HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH}/${RAGNAROK_ONLINE_ICON} --out tmpicns.icns
			echo "read 'icns' (-16455) \"tmpicns.icns\";" >> tmpicns.rsrc
			Rez -a tmpicns.rsrc -o "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.command"
			SetFile -a C "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.command"
			rm -f tmpicns.icns
			rm -f tmpicns.rsrc
			;;

		Linux)
			echo "#!/usr/bin/env xdg-open"  >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			echo "" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			echo "[Desktop Entry]" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			echo "Version=1.0" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			echo "Type=Application" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			echo "Terminal=true" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			echo "Exec=sh -c \"wineserver -k; cd \$HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH}; WINEDEBUG=warn+all,-d3d,-d3d_perf,-wgl,-ntdll wine ${RAGNAROK_ONLINE_GAME_EXECUTABLE}\"" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			echo "Name=${RAGNAROK_ONLINE_GAME_EXECUTABLE}" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			echo "Icon=$HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH}/${RAGNAROK_ONLINE_ICON}" >> "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"
			chmod +x "${RAGNAROK_ONLINE_GAME_EXECUTABLE}.desktop"

			echo "#!/usr/bin/env xdg-open"  >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			echo "" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			echo "[Desktop Entry]" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			echo "Version=1.0" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			echo "Type=Application" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			echo "Terminal=false" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			echo "Exec=sh -c \"wineserver -k; cd \$HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH};WINEDEBUG=warn+all wine ${RAGNAROK_ONLINE_PATCHER_EXECUTABLE_ESCAPED}\"" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			echo "Name=${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			echo "Icon=$HOME/.wine/drive_c/${RAGNAROK_ONLINE_DEFAULT_INSTALL_PATH}/${RAGNAROK_ONLINE_ICON}" >> "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			chmod +x "${RAGNAROK_ONLINE_PATCHER_EXECUTABLE}.desktop"
			;;
		esac
}


check_operating_system
setup_mac
check_wine_version
setup_new_wine
get_winetricks
install_winetricks_libraries
install_ragnarok_online
create_shortcuts
change_wine_settings
optimize_for_ragnarok
echo "RagnarokOnlineWine: Finished"
