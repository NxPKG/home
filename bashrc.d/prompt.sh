# this sets up my custom prompt (PS1 + PS0), including my custom titlebar string (in known-supported terminals)

_docker-pkg_history_1() {
	history 1 | sed -r 's/^[ ]*[0-9]+[ ]+//'
}
_docker-pkg_titlebar_cmd() {
	_docker-pkg_history_1 | awk -v len=50 '
		{
			if (length($0) > len)
				print substr($0, 1, len-3) "...";
			else
				print;
		}
	'
}
if ! command -v __git_ps1 > /dev/null; then
	if [ -s /usr/share/git/git-prompt.sh ]; then
		# Gentoo is fun: https://bugs.gentoo.org/477920 + https://bugs.gentoo.org/507480
		source /usr/share/git/git-prompt.sh
	fi
fi
export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWSTASHSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM=1
_docker-pkg_prompt_extra() {
	local extraBits=

	if [ "${#DIRSTACK[@]}" -gt 1 ]; then
		[ -z "$extraBits" ] || extraBits+='; '
		extraBits+="pushd:${#DIRSTACK[@]}"
	fi

	if [ -n "${WSL_DISTRO_NAME:-}" ]; then
		[ -z "$extraBits" ] || extraBits+='; '
		extraBits+="wsl:$WSL_DISTRO_NAME"
	fi

	if [ -n "${DOCKER_HOST:-}" ]; then
		[ -z "$extraBits" ] || extraBits+='; '
		extraBits+="$DOCKER_HOST"
	fi

	if [ -n "${BASHBREW_ARCH:-}" ]; then
		[ -z "$extraBits" ] || extraBits+='; '
		extraBits+="bashbrew:$BASHBREW_ARCH"
	fi

	# see above for where we try a little harder to ensure __git_ps1 is set (but ignore errors here in case it doesn't or it fails)
	local gitBits; gitBits="$(__git_ps1 '%s' 2>/dev/null || :)"
	if [ -n "$gitBits" ]; then
		[ -z "$extraBits" ] || extraBits+='; '
		extraBits+="$gitBits"
	fi

	if [ -n "$extraBits" ]; then
		printf ' (%s) ' "$extraBits"
	fi
}

# set a fancy prompt (non-color, unless we know we "want" color)
color=
case "${TERM:-}" in
	xterm-color | *-256color | vt220) color=1 ;;
	*)
		if command -v tput > /dev/null && tput setaf 1 &> /dev/null; then
			color=1
		fi
		;;
esac
declare -A colors=(
	[reset]=''
	[date]='' # HH:MM:SS
	[recap]='' # ... $ command ...
	[user]='' # docker-pkg@...
	[host]='' # ...@xyz
	[colon]='' # :
	[path]='' # ~/docker/...
	[extra]='' # (master=)
)
# these two have to be separate because they're used from a function (after "colors" is unset)
_docker-pkg_dollar_color= # $
_docker-pkg_dollar_color_failed= # $ (when the previous command failed)
if [ -n "$color" ]; then
	colors=(
		[reset]='\e[m'

		[date]='\e[1;30m' #'\e[37m' # HH:MM:SS
		[recap]='\e[0;30m' # ... $ command ...
		[user]='\e[0;32m' # docker-pkg@...
		[host]='\e[1;32m' # ...@xyz
		[colon]='\e[1;30m' # :
		[path]='\e[1;34m' # ~/docker/...
		[extra]='\e[0;32m' # (master=)

		[non_docker-pkg_user]='\e[4;93m' # steam@..., root@..., etc
	)
	_docker-pkg_dollar_color='\e[0;31m' # $
	_docker-pkg_dollar_color_failed='\e[1;33m' # $ (when the previous command failed)
	numColors="$(tput colors 2>/dev/null || :)"
	case "${numColors:-8}" in
		256)
			colors[date]='\e[0;38;5;56m'
			colors[recap]='\e[0;38;5;237m'
			colors[user]='\e[0;38;5;23m'
			colors[host]='\e[1;38;5;46m'
			colors[colon]='\e[0;38;5;166m'
			colors[path]='\e[0;38;5;26m'
			colors[extra]='\e[0;38;5;100m'
			colors[non_docker-pkg_user]='\e[4;38;5;15m'
			_docker-pkg_dollar_color='\e[0;38;5;201m'
			_docker-pkg_dollar_color_failed='\e[1;38;5;220m'
			;;
	esac
	unset numColors
fi

# TODO make "docker-pkg" here customizable
user="$(id -un 2>/dev/null || :)"
if [ "$user" != 'docker-pkg' ] && [ -n "${colors[non_docker-pkg_user]:-}" ]; then
	# if I'm not "docker-pkg" make it more obvious
	colors[user]="${colors[non_docker-pkg_user]}"
fi
unset user

_docker-pkg_prompt_dollar_color() {
	if [ "$1" = '0' ]; then
		echo -e "$_docker-pkg_dollar_color"
	else
		# if the previous command failed, change the prompt color
		echo -e "$_docker-pkg_dollar_color_failed"
	fi
}

# "$?" in PS1 is silly, and each subshell clobbers the previous $? value, so we have to propagate that exit code through _every_ subshell for all subshells to get it
# more succinctly,
#     PS1='$(echo $?) $(echo $?) $ '
# would lead to a prompt of
#     '1 0 $ '
# (following a command whose exit code was 1)
#     PS1='$(_docker-pkg_ps1 echo $?) $(_docker-pkg_ps1 echo $?) $ '
# would lead to a prompt of
#     '1 1 $ '
# (which is what we would expect and intend instead)
_docker-pkg_ps1() {
	local ret="$?"
	"$@" || :
	return "$ret"
}

dateFormat='%H:%M:%S'

PS1=
PS1+='\['${colors[date]}'\]\D{'"$dateFormat"'}\['${colors[recap]}'\] ... \$ $(_docker-pkg_ps1 _docker-pkg_history_1)\['${colors[reset]}'\]'$'\n'
PS1+='\['${colors[user]}'\]\u@\['${colors[host]}'\]\h\['${colors[colon]}'\]:\['${colors[path]}'\]\w\['${colors[extra]}'\]$(_docker-pkg_ps1 _docker-pkg_prompt_extra)\[$(_docker-pkg_ps1 _docker-pkg_prompt_dollar_color "$?")\]\$\['${colors[reset]}'\] '

# PS0: http://stromberg.dnsalias.org/~strombrg/PS0-prompt/
PS0=${colors[date]}'\D{'"$dateFormat"'}'${colors[recap]}' ... \$ $(_docker-pkg_history_1)'${colors[reset]}$'\n'

if [ -z "${colors[date]:-}" ]; then
	# if we have no date colors, add more whitespace to visually compensate
	PS1='\n'"$PS1"
	PS0+='\n'
fi

unset color colors dateFormat

# if this is an xterm set the title to user@host:dir
case "${TERM:-}" in
	xterm* | rxvt*)
		titlebarBits='\e]0;[\h] $(_docker-pkg_ps1 _docker-pkg_titlebar_cmd) {\u, \w}\a'
		PS0+="$titlebarBits"
		PS1+="\[$titlebarBits\]"
		unset titlebarBits
		;;
esac
