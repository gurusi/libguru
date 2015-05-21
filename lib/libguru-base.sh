#!/bin/bash
#
# +----------------------------------------------------------------------------+
# |                       libguru-base.sh                                      |
# +----------------------------------------------------------------------------+
#
# If this file seems a bit un-organized, you are reading it the wrong way (e.g.
# not in vim). Reload it in vim, type ":set modeline" (without the quotes), and
# ":e" (again without the quotes). This will set the proper stuff (see end of
# file). Do type ":help folds" to read up on vim folding technique.  Hint: use
# "zo" to open, "zc" to close individual folds.

# Global stuff
# Global definitions #{{{
#
set -o pipefail

#}}}
# Default configuration#{{{
#
# This stuff needs to get initialized immediately
CONF_SCRIPT_NAME="$(basename $0)"

# If these variables are unset, set them to empty value. This way, we can
# import the configuration from the running shell environment. Note that some
# common variables in here (such as CONF_DO_SIMULATE etc) get exported into the
# environment. See the "init" section for details.
# 
CONF_DONT_ABORT=${CONF_DONT_ABORT:-""}
CONF_DONT_CHECK_DEPS=${CONF_DONT_CHECK_DEPS:-""}
CONF_DO_DEBUG=${CONF_DO_DEBUG:-""}
CONF_DO_PRINT_CONFIG=""
CONF_DO_PRINT_VALID_CONFIG=""
CONF_DO_PRINT_HELP=""
CONF_DO_SIMULATE=${CONF_DO_SIMULATE:-""}
CONF_DO_SYSLOG=${CONF_DO_SYSLOG:-""}
CONF_DO_VERBOSE=${CONF_DO_VERBOSE:-""}
CONF_FILE=""
CONF_MAIL_BODY="${CONF_MAIL_BODY:-""}"
CONF_MAIL_FROM="${CONF_MAIL_FROM:-""}"
CONF_MAIL_SUBJECT="${CONF_MAIL_SUBJECT:-$CONF_SCRIPT_NAME at $(hostname -f)}"
CONF_MAIL_TO="${CONF_MAIL_TO:-""}"
CONF_DEPS="logger mailx $CONF_DEPS"
#}}}

# Functions
# Logging and mailing #{{{
#
# NOTE: this logging stuff is confusing. Here's a rule of thumb on how to use
# it properly:
#   * use "say" if you want a message on the console but not logged anywhere
#   * use "log" if you want a message to be output on the console and logged
#
# Check if the first argument given is in fact a valid switch to the echo bash
# builtin.
#
is_echo_switch() {
  case "$1" in
    -n)
      return 0
    ;;
    -e)
      return 0
    ;;
    -E)
      return 0
    ;;
    *)
      return 1
    ;;
  esac
}

# Say something on standard output.
#
say() {
  echo $@
}

# Say something to standard error.
#
say_stderr() {
  echo $@ >&2
}

# Say something if we are in debug mode.
#
say_debug() {
  [ -n "$CONF_DO_DEBUG" ] && say "$*"
}

# Say something to standard error if we are in debug mode.
#
say_debug_stderr() {
  [ -n "$CONF_DO_DEBUG" ] && say "$*"
}

# Do the actual act of logging of stuff to syslog.
#
log_to_syslog() {
  # do not log empty lines
  [ -z "$*" ] && return 0

  # get rid of the switch to echo command (if it exists)
  is_echo_switch $1 && shift

  # log!
  logger -t "$CONF_SCRIPT_NAME" -- "$*"
}

# Log. This is what you should call, because it does all the magic in the
# background (e.g. determines if we are logging to syslog, mail etc).
#
log() {
  say $@
  [ -n "$CONF_DO_SYSLOG" ] && log_to_syslog $@
  [ -n "$CONF_MAIL_TO" ] && append_to_mail_body $@
}

# Log, but to stderr instead of stdout. This is what you should call, because
# it does all the magic in the background (e.g. determines if we are logging to
# syslog, mail etc).
#
log_stderr() {
  say_stderr $@
  [ -n "$CONF_DO_SYSLOG" ] && log_to_syslog $@
  [ -n "$CONF_MAIL_TO" ] && append_to_mail_body $@
}

# Log a "warning" type of message. This is what you should call. 
#
log_warning() {
  # Figure out if we need to prepend the switch to echo command
  if is_echo_switch $1; then
    local switch="$1"; shift
    log_stderr $switch "Warning: " $@
  # ..or not, just do the logging
  else
    log_stderr "Warning: " $@
  fi
}

# Log an "error" type of message. It does the background magic, too.
#
log_error() {
  # Figure out if we need to prepend the switch to echo command
  if is_echo_switch $1; then
    local switch="$1"; shift
    log_stderr $switch "ERROR: " $@
  # ..or not, just do the logging
  else
    log_stderr "ERROR: " $@
  fi
}

# Log "debug" type of message. It does the background magic, too.
#
log_debug() {
  [ -n "$CONF_DO_DEBUG" ] && {
   log_stderr "debug: " $@
   [ -n "$CONF_MAIL_TO" ] && append_to_mail_body $@
  }
}

do_mail() {
  [ -n "$CONF_MAIL_TO" ]
}

create_mail_body() {
  # create the mail body file
  CONF_MAIL_BODY=$(mktemp) || {
    log_error "Could not create mail body tempfile."
    return 1
  }
 log_debug "Created mail body tempfile: '$CONF_MAIL_BODY'."
}

# Appends stuff to mail body.
#
append_to_mail_body() {
  # get rid of the switch to echo command (if it exists)
  is_echo_switch $1 && shift
  echo "$*" >> $CONF_MAIL_BODY
}

remove_mail_body() {
  [ -n "$CONF_MAIL_BODY" ] && {
    rm "$CONF_MAIL_BODY"
  }
}

# Sends a mail, cleans up afterwards.
#
send_mail() {
  # see the "parameter expansion" section of the bash(1) manpage for details on
  # this lambada.
  [ -n "$CONF_MAIL_TO" -a -f "$CONF_MAIL_BODY" -a -n "$CONF_MAIL_SUBJECT" ] && {
    cat "$CONF_MAIL_BODY" | mailx ${CONF_MAIL_FROM:+-r$CONF_MAIL_FROM} -s "$CONF_MAIL_SUBJECT" $CONF_MAIL_TO
    remove_mail_body
  }
}

#}}}
# Run, exec, die #{{{

# Die gracefully.
#
die() {
  log_stderr "$@ Aborting."
  # send mail if so inclined
  [ -n "$CONF_MAIL_TO" ] && { 
    CONF_MAIL_SUBJECT="ERROR: $CONF_MAIL_SUBJECT"
    send_mail
  }
  exit 255
}

# Die gracefully or warn if we are in dont-abort mode.
# 
die_or_warn() {
  if dont_abort; then
    log_warning "$@"
  else
    die "$@"
  fi
}

# Are we in debug mode?
#
do_debug() {
  [ -n "$CONF_DO_DEBUG" ]
}

# Are we in verbose mode?
#
do_verbose() {
  [ -n "$CONF_DO_VERBOSE" ]
}

# Are we in no-abort mode?
#
dont_abort() {
  [ -n "$CONF_DONT_ABORT" ]
}

# Are we in simulate mode?
#
do_simulate() {
  [ -n "$CONF_DO_SIMULATE" ]
}

# Run the specified command
#
run() {
  [ -z "$*" ] && {
    log_warning "Nothing to execute."
    return 0
  }
  local command="$*"
  eval $command
  local retval=$?
  [ "$retval" -gt 0 ] && log_error "$run failed."
  return $retval
}

#}}}
# Configuration handling#{{{
#
# Print the current configuration. 
# 
print_config() {
  say "Current configuration:" 
  local varname varvalue
  for varname in ${!CONF_*}; do
    say "  $varname=\"${!varname}\""
  done
  return 0
}

# Parse the command line arguments and see if we've got a configuration file.
#
parse_args_for_config_file() {
  local opt
  for opt in $@; do
    [ "$1" = "-c" -o "$1" = "--config" ] && {
      shift; CONF_FILE="$1"       
      return 0
    }
    shift
  done
  return 0
}

# Build a running configuration from the configuration file.
#
load_conffile() {
  local errors=0 fn="$1"
  if [ -z "$fn" ]; then
    return 0
  elif [ ! -e "$fn" ]; then
    log_error "Configuration file '$fn' does not exist."
    errors=$(( $errors + 1 ))
  elif [ ! -f "$fn" ]; then
    log_error "Configuration file '$fn' is not a file."
    errors=$(( $errors + 1 ))
  elif [ ! -r "$fn" ]; then
    log_error "Configuration file '$fn' is not readable."
    errors=$(( $errors + 1 ))
  else 
    # Fix the dash(1) stupidity when sourcing files in the current directory
    [ "$(dirname $fn)" = "." ] && fn="./$fn"

    # Do the stuff
    . $fn || { 
      log_error "Could not load configuration file '$fn'."
      errors=$(( $errors + 1 ))
    }
  fi
  return $errors
}
#}}}
# Checkers and initializers #{{{

check_CONF_SCRIPT_NAME() {
  [ -z "$CONF_SCRIPT_NAME" ] && {
    log_warning "Script name not set."
  }
  return 0
}

check_CONF_DO_DEBUG() {
  do_debug && log_warning "Running in debug mode."
  return 0
}

check_CONF_DONT_ABORT() {
  dont_abort && log_warning "Will not abort on errors."
  return 0
}

check_CONF_DEPS() {
  local errors=0

  # skip the check if so inclined
  [ -n "$CONF_DONT_CHECK_DEPS" ] && {
    log_warning "Skipping dependency check for external programs."
    return 0
  }
  
  # no deps?
  [ -z "$CONF_DEPS" ] && {
    log_warning "No dependencies to external programs defined. This is weird. Bug the developer of this script, if he is around."
    return 0
  }

  # do tha check
  local bin
  for bin in $CONF_DEPS; do
    which "$bin" 2>&1 > /dev/null || {
      log_error "External program '$bin' not found anywhere in PATH ($PATH)."
      errors=$(( $errors + 1 ))
    }
  done
  return $errors
}

check_CONF_MAIL_TO() {
  [ -n "$CONF_MAIL_TO" ] && {
    create_mail_body
  }
  return 0
}
#}}}

# Init
# Init#{{{

# Do the whole command line arguments/configuration-file/help lambada in the
# proper order. First, parse the command line arguments to see if the user has
# given us a configuration file.
parse_args_for_config_file "$@"

# Check if we've got a configuration file via the command-line switches. If so,
# load it. 
[ -n "$CONF_FILE" ] && {
  load_conffile "$CONF_FILE" || die "Could not load configuration file '$CONF_FILE'."
}

# Parse the arguments *again* because by convention they should override the
# stuff given in the configuration file. This time, parse all of the arguments.
# 
# WARNING: this function should be implemetned by the script; for an example on
# how to do it properly, see the example at the end of this file.
parse_args "$@"

# Do the help thing if the user so wishes.
[ -n "$CONF_DO_PRINT_HELP" ] && {
  print_help
  remove_mail_body
  exit 0
}

# Print the config.
[ -n "$CONF_DO_PRINT_CONFIG" ] && {
  print_config
  remove_mail_body
  exit 0
}

# We apparently have some configuration now, let's check its sanity. First the
# boilerplate stuff.
errors=0
check_CONF_SCRIPT_NAME; errors=$(( $errors +$? ))
check_CONF_DEPS; errors=$(( $errors + $? ))
check_CONF_DO_DEBUG; errors=$(( $errors + $? ))
check_CONF_MAIL_TO; errors=$(( $errors + $? ))

# Stop if there are any errors in the configuration.
[ "$errors" -gt 0 ] && die "$errors error(s) found in the configuration, aborting."
unset errors

#}}}

# Examples
# EXAMPLE: Parse the command line arguments and build a running configuration from them.#{{{
#
# Note that this function should be called like this: >parse_args "$@"< and
# *NOT* like this: >parse_args $@< (without the ><, of course). The second
# variant will work but it will cause havoc if the arguments contain spaces!
#
#parse_args() {
  #local short_args="c:,d,h,n,p,t:,v"
  #local long_args="config:,debug,destination:,no-check-deps,no-abort,help,print-config,print-valid-config,syslog,simulate,verbose"
  #local g; g=$(getopt -n $CONF_SCRIPT_NAME -o $short_args -l $long_args -- "$@") || die "Could not parse arguments, aborting."
  #log_debug "args: $args, getopt: $g"

  #eval set -- "$g"
  #while true; do
    #local a; a="$1"

    ## This is the end of arguments, set the stuff we didn't parse (the
    ## non-option arguments, e.g. the stuff without the dashes (-))
    #if [ "$a" = "--" ] ; then
      #shift
      #while [ $# -gt 1 ]; do
        #CONF_LOG_FILES="$CONF_LOG_FILES $1"
        #shift
      #done
      #return 0

    ## This is the config file.
    #elif [ "$a" = "-c" -o "$a" = "--config" ] ; then
      #shift; CONF_FILE="$1"

    ## The debug switch.
    #elif [ "$a" = "-d" -o "$a" = "--debug" ] ; then
      #CONF_DO_DEBUG="true"

    ## Do not abort on non-fatal errors, issue a warning instead.
    #elif [ "$a" = "--no-abort" ] ; then
      #CONF_DONT_ABORT="true"

    ## Do not check dependencies.
    #elif [ "$a" = "--no-check-deps" ] ; then
      #CONF_DONT_CHECK_DEPS="true"

    ## Help.
    #elif [ "$a" = "-h" -o "$a" = "--help" ] ; then
      #CONF_DO_PRINT_HELP="true"

    ## Print the current configuration.
    #elif [ "$a" = "-p" -o "$a" = "--print-config" ] ; then
      #CONF_DO_PRINT_CONFIG="true"

    ## Print the current configuration.
    #elif [ "$a" = "--print-valid-config" ] ; then
      #CONF_DO_PRINT_VALID_CONFIG="true"

    ## Syslog
    #elif [ "$a" = "--syslog" ]; then
      #CONF_DO_SYSLOG="true"

    ## Verbosity
    #elif [ "$a" = "-v" -o "$a" = "--verbose" ]; then
      #CONF_DO_VERBOSE="true"

    ## Simulate
    #elif [ "$a" = "-n" -o "$a" = "--simulate" ]; then
      #CONF_DO_SIMULATE="true"

    ## Destination
    #elif [ "$a" = "-t" -o "$a" = "--move-to" ]; then
      #shift; CONF_MOVE_TO="$1"

    ## Dazed and confused...
    #else
      #die -e "I apparently know about the '$a' argument, but I don't know what to do with it.\nAborting. This is an error in the script. Bug the author, if he is around."
    #fi

    #shift
  #done

  #return 0
#}#}}}
# EXAMPLE: A help function#{{{
# Print the help stuff
# 
#print_help() {
  #cat <<HERE
#Usage: $CONF_SCRIPT_NAME [option ...] [ <file> ... ]

#These options are MANDATORY:
  #-t, --move-to : The destination directory to move logs to, Current: "$CONF_MOVE_TO"

#[option] is one of the following. Options are optional (doh!):
  #Configuration stuff:
  #-c, --config         : Path to config file, current: "$CONF_FILE"
  #-p, --print-config   : Print the current configuration, then exit. Current: "$CONF_DO_PRINT_CONFIG"
  #--print-valid-config : Print the configuration after all checks have passed, 
                         #current: "$CONF_DO_PRINT_VALID_CONFIG"

  #General:
  #-h, --help      : This text, current: "$CONF_DO_PRINT_HELP"
  #-v, --verbose   : I am a human, so be more verbose. not suitable as a machine
                    #input, current "$CONF_DO_VERBOSE"
  #--syslog        : Log to syslog, too. Current: "$CONF_DO_SYSLOG"
  #--no-check-deps : Don't check dependencies to external programs, current: "$CONF_DONT_CHECK_DEPS"
  #--no-abort      : Don't abort on non-fatal errors, issue a warning instead.
                    #Current: "$CONF_DONT_ABORT"
  #-d, --debug     : Enable debug output, current: "$CONF_DO_DEBUG"
  #-n, --simulate  : Don't actually do anything, just report what would have been
                    #done, current: "$CONF_DO_SIMULATE"

#Due to nature of things, the configuration values in here might not be correct. 
#Run "$CONF_SCRIPT_NAME -p" to see the full configuration.
#HERE
  #return 0
#}
#}}}
# EXAMPLE: a sample init section from an actual script that uses libguru-base.sh#{{{
#
## Then, let's check the actual configuration.
#check_CONF_LOG_DIR; errors=$(( $errors + $? ))
#check_CONF_LOGFILE_PCRE; errors=$(( $errors + $? ))
#check_CONF_DATE_FROM; errors=$(( $errors + $? ))
#check_CONF_DATE_TO; errors=$(( $errors + $?))

## check the date interval
#[ -n "$CONF_DATE_FROM" -a -n "$CONF_DATE_TO" ] && {
  #check_date_interval "$CONF_DATE_FROM" "$CONF_DATE_TO"; errors=$(( $errors + $? ))
#}

## Stop if there are any errors in the configuration.
#[ "$errors" -gt 0 ] && die "$errors error(s) found in the configuration, aborting."
#unset errors

## Print the config after validation.
#[ -n "$CONF_DO_PRINT_VALID_CONFIG" ] && {
  #print_config
  #exit 0
#}
#}}}

# vim: set tabstop=2 shiftwidth=2 expandtab colorcolumn=80 foldmethod=marker foldcolumn=3 foldlevel=0:
