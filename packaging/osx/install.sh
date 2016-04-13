#!/bin/bash
# Datadog Agent install script for Mac OS X.
set -e
logfile=ddagent-install.log
dmg_file=/tmp/datadog-agent.dmg
dmg_url="https://s3.amazonaws.com/dd-agent/datadogagent.dmg"

# Root user detection
if [ $(echo "$UID") = "0" ]; then
    sudo_cmd=''
else
    sudo_cmd='sudo'
fi

# get real user (in case of sudo)
real_user=`logname`
export TMPDIR=`sudo -u $real_user getconf DARWIN_USER_TEMP_DIR`
cmd_real_user="sudo -Eu $real_user"

# In order to install with the right user
rm -f /tmp/datadog-install-user
echo $real_user > /tmp/datadog-install-user

function on_error() {
    printf "\033[31m$ERROR_MESSAGE
It looks like you hit an issue when trying to install the Agent.

Troubleshooting and basic usage information for the Agent are available at:

    http://docs.datadoghq.com/guides/basic_agent_usage/

If you're still having problems, please send an email to support@datadoghq.com
with the contents of ddagent-install.log and we'll do our very best to help you
solve your problem.\n\033[0m\n"
}
trap on_error ERR

if [ -n "$DD_API_KEY" ]; then
    apikey = $DD_API_KEY
else
    apikey = "netsil"
fi

if [ -n "$DD_URL" ]; then
    dd_url = $DD_URL
else
    dd_url = "http://localhost:2001/"
fi

$dd_url = echo $dd_url | sed -i '' -e "s/\//\\\\\//g"

# Install the agent
printf "\033[34m\n* Downloading datadog-agent\n\033[0m"
rm -f $dmg_file
curl $dmg_url > $dmg_file
printf "\033[34m\n* Installing datadog-agent, you might be asked for your sudo password...\n\033[0m"
$sudo_cmd hdiutil detach "/Volumes/datadog_agent" >/dev/null 2>&1 || true
printf "\033[34m\n    - Mounting the DMG installer...\n\033[0m"
$sudo_cmd hdiutil attach "$dmg_file" -mountpoint "/Volumes/datadog_agent" >/dev/null
printf "\033[34m\n    - Unpacking and copying files (this usually takes about a minute) ...\n\033[0m"
cd / && $sudo_cmd /usr/sbin/installer -pkg `find "/Volumes/datadog_agent" -name \*.pkg 2>/dev/null` -target / >/dev/null
printf "\033[34m\n    - Unmounting the DMG installer ...\n\033[0m"
$sudo_cmd hdiutil detach "/Volumes/datadog_agent" >/dev/null

# Set the configuration
if egrep 'api_key:( APIKEY)?$' "/opt/datadog-agent/etc/datadog.conf" > /dev/null 2>&1; then
    printf "\033[34m\n* Adding your API key and dd_url to the Agent configuration: datadog.conf\n\033[0m\n"
    $sudo_cmd sh -c "sed -i '' -e 's/api_key:.*/api_key: $apikey/g' -e 's/dd_url:.*/dd_url: $dd_url/g' \"/opt/datadog-agent/etc/datadog.conf\""
    $sudo_cmd chown $real_user:admin "/opt/datadog-agent/etc/datadog.conf"
    $sudo_cmd chmod 640 /opt/datadog-agent/etc/datadog.conf
    printf "\033[34m* Restarting the Agent...\n\033[0m\n"
    $cmd_real_user "/opt/datadog-agent/bin/datadog-agent" restart >/dev/null
else
    printf "\033[34m\n* Keeping old datadog.conf configuration file\n\033[0m\n"
fi

# Starting the app
$cmd_real_user open -a 'Datadog Agent.app'
