#!/bin/sh
###################################################################################
############## Lemonbar script, pipe to lemonbar from command line ################
###################################################################################
# bash ~/.config/i3/lemonbar/lemonbar.sh | lemonbar -f "FontAwesome-12" -f "Droid Sans-12" -B \#AA000000 | while read line; do eval "${line}"; done

NETWORK_DELAY=600

clock() {
    date '+ %B %d, %Y   %l:%M %p '
}

battery() {
    BATC=/sys/class/power_supply/BAT1/capacity
    BATS=/sys/class/power_supply/BAT1/status

    test "`cat $BATS`" = "Charging" && echo -n '+' || echo -n '-'

    sed -n p $BATC
}

bitcoin() {
    buy=`curl -s https://blockchain.info/ticker | jq '.USD.buy' | xargs printf "%.*f\n" 2`
    #blockcount=`curl -s https://blockexplorer.com/api/status\?q=getBlockCount | jq '.blockcount'`
    #blockcount=`curl -s https://blockchain.info/ticker | jq '.USD.buy' | xargs printf "%.*f\n" 0`
    #printf " 1 BTC = $%s  Blocks: %s" "$buy" "$blockcount"
    printf " 1 BTC = $%s" "$buy"
}

volume() {
    #VOL=`amixer get Master | sed -n 'N;s/^.*\[\([0-9]\+\).*$/\1/p'`
    VOL=`pactl list sinks | grep "Volume: " | awk 'NR == 3' | awk '{print $5}'`
    VOL=`echo ${VOL::-1}`
    GREEN=`echo "255 - ($VOL*255/100)" | bc`
    RED=`echo "255 - $GREEN" | bc`
    printf "%%{F#%02x%02x00}$VOL%%%%{F#FFFFFF}" "$RED" "$GREEN"
}

cpuload() {
    LINE=`ps -eo pcpu |grep -vE '^\s*(0.0|%CPU)' |sed -n '1h;$!H;$g;s/\n/ +/gp'`
    bc <<< $LINE
}

coretemp() {
    ALL_TEMPS=(`sensors | grep "Core [[:digit:]]"`)
    CORE0=${ALL_TEMPS[2]:1}
    CORE1=${ALL_TEMPS[11]:1}
    CORE2=${ALL_TEMPS[20]:1}
    CORE3=${ALL_TEMPS[29]:1}
    printf "   ${CORE0} | ${CORE1} | ${CORE2} | ${CORE3}"
}

#disk() {
#    SPACE=`df -lh -x tmpfs -x devtmpfs --output=avail,target | grep -v "/media/" | grep "/" | cut -d " " -f 2`
#    printf " ${SPACE}"
#}

memory() {
    MEM=(`free -mh | grep "Mem:"`)
    MEM_USED=${MEM[2]}
    MEM_TOTAL=${MEM[1]}
    printf "   ${MEM_USED} / ${MEM_TOTAL}"
}

network() {
    read lo int1 int2 <<< `ip link | sed -n 's/^[0-9]: \(.*\):.*$/\1/p'`
    if iwconfig $int1 >/dev/null 2>&1; then
        wifi=$int1
        eth0=$int2
    else
        wifi=$int2
        eth0=$int1
    fi
    ip link show $eth0 | grep 'state UP' >/dev/null && int=$eth0 ||int=$wifi

    #int=eth0

    ping -c 1 8.8.8.8 >/dev/null 2>&1 && 
        echo "$int connected" || echo "$int disconnected"
}

netspeed() {
    TEXT=`awk '{if(l1){print int(($2-l1)/1024)"kB/s",int(($10-l2)/1024)"kB/s"} else{l1=$2; l2=$10;}}' \
        <(grep enp2s0 /proc/net/dev) <(sleep 1; grep enp2s0 /proc/net/dev)`
    UP=`echo $TEXT | cut -d' ' -f2`
    DOWN=`echo $TEXT | cut -d' ' -f1`
    echo " ${DOWN}   ${UP}"
}

nowplaying() {
    cur=`mpc current`
    # this line allow to choose whether the output will scroll or not
    test "$1" = "scroll" && PARSER='skroll -n20 -d0.5 -r' || PARSER='cat'
    test -n "$cur" && $PARSER <<< $cur || echo "- stopped -"
}

# Pause: dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Pause
# Play: dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Play
# Play/Pause: dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause
# Get Metadata: dbus-send --print-reply --session --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata'
# Get artist: dbus-send --print-reply --session --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata' | grep -A 2 "xesam:artist" | grep "string " | tail -1 | sed "s/string //" | tr -d '"' | sed "s/^[ \t]*//"
# Get title: dbus-send --print-reply --session --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata' | grep -A 1 "xesam:title" | tail -1 | sed "s/^[ \t]*variant[ \t]*string //" | tr -d '"'
spotify() {
    if pgrep spotify > /dev/null; then
        ARTIST=`dbus-send --print-reply --session --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata' 2>/dev/null | grep -A 2 "xesam:artist" | grep "string " | tail -1 | sed "s/string //" | tr -d '"' | sed "s/^[ \t]*//"`
        TITLE=`dbus-send --print-reply --session --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata' 2>/dev/null | grep -A 1 "xesam:title" | tail -1 | sed "s/^[ \t]*variant[ \t]*string //" | tr -d '"'`
        echo "$ARTIST - $TITLE"
    else
        echo "[Not Running]"
    fi
}

wifi() {
    IP=`hostname -I`
    echo "%{F#009933}${IP}%{F#FFFFFF}"
}

workspaces() {
    echo `i3-msg -t get_workspaces | jq '.[] | select(.focused==true).name' | cut -d"\"" -f2`
}

gpu() {
    echo `gpustat | grep "\[0\]" | cut -d"|" -f3 | sed 's: / :M/:g' | sed "s: ::g" | sed "s:B::g"`
}

gpu2() {
    echo `gpustat | grep "\[0\]" | cut -d"|" -f2 | sed "s: ::g" | sed "s:,:   :g" | sed "s:':°:g"`
}

# This loop will fill a buffer with our infos, and output it to stdout.
loops=$NETWORK_DELAY
btctext=""
while :; do
    barout=""
    buf=""

    # Update bitcoin text if enough time has elapsed
    if [ "$loops" -ge "$NETWORK_DELAY" ]; then
        btctext="$(bitcoin)"
        loops=0
    fi

    # Left align
    buf="${buf}%{l}"
    #buf="${buf}%{B#086caa} $(workspaces) %{B#000000} "
    buf="${buf} ${btctext} "
    buf="${buf} $(coretemp) "
    buf="${buf} $(memory)  "
    buf="${buf}  $(gpu) | $(gpu2)"

    # Center align
    buf="${buf}%{c}"
    buf="${buf} %{F#009933}%{F#FFFFFF} $(spotify)"

    # Right align
    buf="${buf}%{r}"
    buf="${buf} $(netspeed)  "
    #buf="${buf} $(disk) "
    buf="${buf}  $(cpuload)%  "
    buf="${buf}  $(wifi)  "
    buf="${buf} %{A:pactl set-sink-volume 1 -5%:}%{A3:pactl set-sink-volume 1 +5%:}%{A2:pavucontrol&:} $(volume)%{A}%{A}%{A}  "
    buf="${buf} %{A:gsimplecal&:}$(clock)%{A}  "

    Monitors=$(xrandr | grep -o "^.* connected" | sed "s/ connected//")
    tmp=0                                                                       
    for m in $(echo "$Monitors"); do                                        
        barout+="%{S${tmp}}$buf"        
        let tmp=$tmp+1                                                          
    done

    echo $barout
    loops=$((loops+1))
    sleep 1 # The HUD will be updated every second
done
