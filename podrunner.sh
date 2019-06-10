#!/bin/bash
set -euo pipefail

podman_run_options=()

# add_option will add a pair of cmd args when they do not yet exist.
# input:  2 arguments to add
# output: updates podman_run_options
function add_option
{
	# arguments to add to run options
	local arg1="${1}"
	local arg2="${2}"

	foundfirst=false
	for opt in "${podman_run_options[@]}"; do
		if [[ "$foundfirst" == true ]] && [[ "$opt" == "$arg2" ]]; then
			# option already added
			return
		fi
		if [[ "$foundfirst" == false ]] && [[ "$opt" == "$arg1" ]]; then
			foundfirst=true
		else
			foundfirst=false
		fi
	done
	podman_run_options+=("$arg1")
	podman_run_options+=("$arg2")
}

# map_user maps your user to the same uid inside the container instead of root.
function map_user
{
	local user_id_real
	user_id_real=$(id -ru)
	local max_uid_count=65536
	local max_minus_uid=$((max_uid_count - user_id_real))
	local uid_plus_one=$((user_id_real + 1))

	add_option --uidmap "${user_id_real}:0:1"
	add_option --uidmap "0:1:${user_id_real}"
	add_option --uidmap "${uid_plus_one}:${uid_plus_one}:${max_minus_uid}"
	add_option --security-opt "label=disable"
}

# transparent_homedir make the homedir accesible and matches the current
# working directory.
function transparent_homedir
{
	add_option --volume "${HOME}:${HOME}:rslave"
	add_option --env "HOME=${HOME}"
	add_option --workdir "$(pwd)"
	add_option --security-opt "label=disable"
}

# ssh_agent exposes the ssh agent socket inside the container.
function ssh_agent
{
	add_option --volume "${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}"
	add_option --env "SSH_AUTH_SOCK=${SSH_AUTH_SOCK}"
}

# utf8_support enables generic utf-8 in most containers.
function utf8_support
{
	add_option --env "LANG=C.UTF-8"
	add_option --env "TERM=${TERM}"
}

# x11_socket exposes the x11 socket inside the container.
function x11_socket
{
	add_option --env "DISPLAY=${DISPLAY}"
	add_option --volume "${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}"
}

# usage prints help.
function usage
{
	echo "Usage: podrunner.sh [PODMAN RUN OPTION...] [OPTION...]"
	echo ""
	echo "  --map-user      Map OS user to user 1000 inside the container."
	echo "  --ssh-agent     Expose ssh-agent inside the container."
	echo "  --homedir       Make homedir transparent inside the container."
	echo "  --utf8          Enable basic UTF8 support in most containers."
	echo "  --x11           Expose X11 socket inside the container."
}


for opt in "$@"; do
	case "$opt" in
		"--help" | "--usage")
			usage
			exit 0
			;;

		"--homedir")
			transparent_homedir
			shift
			;;
		"--map-user")
			map_user
			shift
			;;
		"--ssh-agent")
			ssh_agent
			shift
			;;
		"--utf8")
			utf8_support
			shift
			;;
		"--x11")
			x11_socket
			shift
			;;
		*)
			# add unknown options as raw podman options.
			podman_run_options+=("$1")
			shift
			;;
	esac
done

# print all options quoted
if [[ ${#podman_run_options[@]} -gt 0 ]]; then
	printf "'%s' " "${podman_run_options[@]}"
fi
