#!/bin/bash
#
# +----------------------------------------------------------------------------+
# |                           libguru-base.EXAMPLE.sh                          | 
# +----------------------------------------------------------------------------+
#
# This is an example script on how a libguru-base enabled script should look
# like. You can use it as a template, add your stuff to it, and in the end you
# will get all the goodies of libguru-base.
# 
# The ordering of stuff in here is really important. This is the proper order:
# * first, your global stuff and your default built-in configuration goes at
#   the top 
# * followed by your custom command-line parsing function (see an example in
#   this file)
# * then, include the libguru-base (you can copy/paste this section, no
#   modifications needed here)
# * then, include all your functions. If you have any checkers/validators, put
#   them here too.
# * your libguru-base empowered init. For an example, see this file.
# * your main stuff
#
# If this file seems a bit un-organized, you are reading it the wrong way (e.g.
# not in vim). Reload it in vim, type ":set modeline" (without the quotes), and
# ":e" (again without the quotes). This will set the proper stuff (see end of
# file). Do type ":help folds" to read up on vim folding technique.  Hint: use
# "zo" to open, "zc" to close individual folds.

# Global stuff
# Default configuration #{{{
#
set -o pipefail

# Default configuration
CONF_MY_BOOLEAN=""                                                              # this eihter has a value, or it doesn't
CONF_MY_VALUE=""                                                                # the value of this has some meaning
CONF_DEPS="awk sed grep"                                                        # none of this is really used here
#}}}

# libguru-base.sh initialization
# Command-line parsing and help#{{{
#
# Parse the command line arguments and build a running configuration from them.
#
# Note that this function should be called like this: >parse_args "$@"< and
# *NOT* like this: >parse_args $@< (without the ><, of course). The second
# variant will work but it will cause havoc if the arguments contain spaces!
#
parse_args() {
  local short_args="a:,b,c:,d,h,n,p,s,v"
  local long_args="boolean-parameter,config:,debug,no-check-deps,no-abort,help,print-config,print-valid-config,syslog,simulate,value-parameter:,verbose"
  local g; g=$(getopt -n $CONF_SCRIPT_NAME -o $short_args -l $long_args -- "$@") || die "Could not parse arguments, aborting."
  log_debug "args: $args, getopt: $g"

  eval set -- "$g"
  while true; do
    local a; a="$1"

    # This is the end of arguments, set the stuff we didn't parse (the
    # non-option arguments, e.g. the stuff without the dashes (-))
    if [ "$a" = "--" ] ; then
      shift
      CONF_NONOPTION_ARGUMENTS="$@"
      return 0

    # This is the config file.
    elif [ "$a" = "-c" -o "$a" = "--config" ] ; then
      shift; CONF_FILE="$1"

    # The debug switch.
    elif [ "$a" = "-d" -o "$a" = "--debug" ] ; then
      CONF_DO_DEBUG="true"

    # Do not abort on non-fatal errors, issue a warning instead.
    elif [ "$a" = "--no-abort" ] ; then
      CONF_DONT_ABORT="true"

    # Do not check dependencies.
    elif [ "$a" = "--no-check-deps" ] ; then
      CONF_DONT_CHECK_DEPS="true"

    # Help.
    elif [ "$a" = "-h" -o "$a" = "--help" ] ; then
      CONF_DO_PRINT_HELP="true"

    # Print the current configuration.
    elif [ "$a" = "-p" -o "$a" = "--print-config" ] ; then
      CONF_DO_PRINT_CONFIG="true"

    # Print the current valid configuration.
    elif [ "$a" = "--print-valid-config" ] ; then
      CONF_DO_PRINT_VALID_CONFIG="true"

    # Syslog
    elif [ "$a" = "--syslog" ]; then
      CONF_DO_SYSLOG="true"

    # Simulate
    elif [ "$a" = "-n" -o "$a" = "--simulate" ]; then
      CONF_DO_SIMULATE="true"

    # Verbosity
    elif [ "$a" = "-v" -o "$a" = "--verbose" ]; then
      CONF_DO_VERBOSE="true"

    # my boolean parameter
    elif [ "$a" = "-b" -o "$a" = "--my-boolean-param" ]; then
      CONF_MY_BOOLEAN="true"

    # my value parameter
    elif [ "$a" = "-a" -o "$a" = "--my-value-param" ]; then
      shift; CONF_MY_VALUE="$1"

    # Dazed and confused...
    else
      die -e "I apparently know about the '$a' argument, but I don't know what to do with it.\nAborting. This is an error in the script. Bug the author, if he is around."
    fi

    shift
  done

  return 0
}

# Print the help stuff
# 
print_help() {
  cat <<HERE
Usage: $CONF_SCRIPT_NAME [option ...] <something>

[option] is one of the following. Options are optional (doh!):
  -a, --my-value-param   : My parameter that holds a particular value, current: "$CONF_MY_VALUE"
  -b, --my-boolean-param : My parameter that is either on or off, Current: "$CONF_MY_BOOLEAN"

  Configuration stuff:
  -c, --config         : Path to config file, current: "$CONF_FILE"
  -p, --print-config   : Print the current configuration, then exit. Current: "$CONF_DO_PRINT_CONFIG"
  --print-valid-config : Print the configuration after all checks have passed, 
                         current: "$CONF_DO_PRINT_VALID_CONFIG"

  General:
  -h, --help      : This text, current: "$CONF_DO_PRINT_HELP"
  -v, --verbose   : I am a human, so be more verbose. not suitable as a machine
                    input, current "$CONF_DO_VERBOSE"
  --syslog        : Log to syslog, too. Current: "$CONF_DO_SYSLOG"
  --no-check-deps : Don't check dependencies to external programs, current: "$CONF_DONT_CHECK_DEPS"
  --no-abort      : Don't abort on non-fatal errors, issue a warning instead.
                    Current: "$CONF_DONT_ABORT"
  -d, --debug     : Enable debug output, current: "$CONF_DO_DEBUG"
  -n, --simulate  : Don't actually do anything, just report what would have been
                    done, current: "$CONF_DO_SIMULATE"

Due to nature of things, the configuration values in here might not be correct. 
Run "$CONF_SCRIPT_NAME -p" to see the full configuration.
HERE
  return 0
}
#}}}
# Include the libguru-base.sh #{{{
#
files="libguru-base.sh"; directories="/usr/local/lib/guru /usr/lib/guru"
for f in $files; do
  included=""
  for d in $directories; do
    path="$d/$f"; [ -x "$path" ] && {
      . $path
      included="true"
    }
  done
  [ -z "$included" ] && {
    echo "Could not include library '$f' from anywhere in paths '$directories', aborting."
    exit 1
  }
done
unset files f directories d included
#}}}

# Script functions
# Checker/validator functions#{{{
#
check_CONF_MY_BOOLEAN() {
  if [ -z "$CONF_MY_BOOLEAN" ]; then
    log "CONF_MY_BOOLEAN is *NOT* set."
  else
    log "CONF_MY_BOOLEAN is SET."
  fi
  # always return success!
  return 0
}

check_CONF_MY_VALUE() {
  if [ -z "$CONF_MY_VALUE" ]; then
    log "CONF_MY_VALUE is not set. This is an error."
    return 1
  else
    log "CONF_MY_VALUE has the following value: \"$CONF_MY_VALUE\"."
    return 0
  fi
}
#}}}

# Go go go!
# Init#{{{
#
# Then, let's check the actual configuration.
check_CONF_MY_BOOLEAN; errors=$(( $errors + $? ))
check_CONF_MY_VALUE; errors=$(( $errors + $? ))

# Stop if there are any errors in the configuration.
[ "$errors" -gt 0 ] && die "$errors error(s) found in the configuration, aborting."
unset errors

# Print the config after validation.
[ -n "$CONF_DO_PRINT_VALID_CONFIG" ] && {
  print_config
  exit 0
}
#}}}
# Do the actual work#{{{
#
log "CONF_NONOPTION_ARGUMENTS has the following value: \"$CONF_NONOPTION_ARGUMENTS\"."

exit 0
#}}}

# vim: set tabstop=2 shiftwidth=2 expandtab colorcolumn=80 foldmethod=marker foldcolumn=3 foldlevel=0:

