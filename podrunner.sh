#!/bin/bash
# podrunner.sh - wrapper around `podman run` for common integration cases.
#
# Copyright (c) 2019, Bas van der Lei
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
set -euo pipefail

podman_run_options=()

# add_option adds to podman_run_options unless they already exist.
function add_option
{
	local nopts="$#"
	local opts=("$@")
	if [[ "$nopts" -lt 1 ]]; then
		# noop
		return
	elif [[ "${#podman_run_options[@]}" -ge "$nopts" ]]; then
		local last=$(( "${#podman_run_options[@]}" - "$nopts" ))
		for (( i=0; i<=last; i++ )); do
			slice=("${podman_run_options[@]:${i}:$nopts}")
			if [[ "${opts[*]}" == "${slice[*]}" ]]; then
				# already there
				return
			fi
		done
	fi
	podman_run_options+=("${opts[@]}")
}

# libvirtd exposes the libvird socket inside the container.
function libvirtd
{
	if [[ -d /run/libvirt ]]; then
		add_option --volume /run/libvirt:/run/libvirt
		add_option --security-opt "label=disable"
	else
		echo "error: libvirt directory not found" >&2
		return 1
	fi
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

# pulseaudio exposes pulseaudio socket and config.
function pulseaudio_socket
{
	local socket="${XDG_RUNTIME_DIR}/pulse/native"
	if [[ -S "$socket" ]]; then
		add_option --volume "/etc/machine-id:/etc/machine-id:ro"
		add_option --env "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"
		add_option --volume "${socket}:${socket}"
		add_option --security-opt "label=disable"
	else
		echo "error: pulseaudio socket not found" >&2
		return 1
	fi
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
	add_option --security-opt "label=disable"
}

# utf8_support enables generic utf-8 in most containers.
function utf8_support
{
	add_option --env "LANG=C.UTF-8"
	add_option --env "TERM=${TERM}"
}

# wayland_socket exposes the wayland socket inside the container.
function wayland_socket
{
	local socket="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
	if [[ -S "${socket}" ]] && [[ -f "${socket}.lock" ]] ; then
		add_option --env "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"
		add_option --env "WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
		add_option --volume "${socket}:${socket}"
		add_option --volume "${socket}.lock:${socket}.lock"
	else
		echo "error: wayland socket not found" >&2
		return 1
	fi
	add_option --security-opt "label=disable"
}

# x11_socket exposes the x11 socket inside the container.
function x11_socket
{
	local socket_dir=/tmp/.X11-unix
	if [[ -d "$socket_dir" ]]; then
		add_option --env "DISPLAY=${DISPLAY}"
		add_option --volume "${socket_dir}:${socket_dir}"
		# add direct rendering device if it exists.
		if [[ -d /dev/dri ]]; then
			add_option --device /dev/dri
		fi
		add_option --security-opt "label=disable"
	else
		echo "error: x11 socket dir not found" >&2
		return 1
	fi
}

# usage prints help.
function usage
{
	echo "Usage: podrunner.sh [OPTION...] -- [PODMAN RUN OPTIONS...]"
	echo ""
	echo "  --homedir       Make homedir transparent inside the container."
	echo "  --libvirtd      Expose libvirtd socket inside the container."
	echo "  --map-user      Map host user to user with same uid inside the container."
	echo "  --pulseaudio    Expose pulseaudio sound server inside the container."
	echo "  --ssh-agent     Expose ssh-agent inside the container."
	echo "  --utf8          Enable basic UTF8 support in most containers."
	echo "  --wayland       Expose Wayland socket inside the container."
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
		"--libvirtd")
			libvirtd
			shift
			;;
		"--map-user")
			map_user
			shift
			;;
		"--pulseaudio")
			pulseaudio_socket
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
		"--wayland")
			wayland_socket
			shift
			;;
		"--x11")
			x11_socket
			shift
			;;
		"--")
			shift
			break
			;;
		*)
			echo "unknown option $1" >&2
			exit 1
			;;
	esac
done

exec podman run "${podman_run_options[@]}" "$@"
