How To Make An Amazing Custom Menu Bar For Your Mac With Sketchybar
​
 Summarize
​
January 8, 2024
Checkout My Wallpaper Pack For This Custom Menu Bar: Waves Wallpaper Pack

Take a look at my youtube video for in-depth explanations of all of the code in this blog post.

You can find my current sketchybar config and the rest of my dotfiles here: dotfiles

Open a terminal window

Open a terminal window on your mac. Could be the default terminal or something else like iTerm2 which is what I’m currently using.

Install homebrew

Run the following command:

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
If necessary, when prompted, enter your password here and press enter. If you haven’t installed the XCode Command Line Tools, when prompted, press enter and homebrew will install this as well.

Add to path (only apple silicon macbooks)

After installing, add it to the path. This step shouldn’t be necessary on Intel macs.

Run the following two commands to do so:

echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
Install sketchybar

Run the following two commands:

brew tap FelixKratz/formulae
brew install sketchybar
Run these commands to add default ~/.config/sketchybar example configuration:

mkdir -p ~/.config/sketchybar
cp /opt/homebrew/opt/sketchybar/share/sketchybar/examples/sketchybarrc ~/.config/sketchybar/sketchybarrc
mkdir ~/.config/sketchybar/plugins
cp -r /opt/homebrew/opt/sketchybar/share/sketchybar/examples/plugins/ ~/.config/sketchybar/plugins/
chmod +x ~/.config/sketchybar/plugins/*
Install default nerd font

Run the following two commands:

brew tap homebrew/cask-fonts
brew install font-hack-nerd-font
Install command line JSON processor (jq)

Run the following command to install jq:

Hide the default MacOs menu bar

For MacOs Sonoma: System Settings -> Control Center-> Automatically hide and show the menu bar -> Always

For MacOs Ventura: System Settings -> Desktop & Dock -> Automatically hide and show the menu bar -> Always

For Pre MacOS Ventura: System Preferences -> Dock & Menu Bar -> Automatically hide and show the menu bar (checked)

Startup sketchybar

Run the following command:

brew services start sketchybar
Make yabai window manager aware of sketchybar (optional)

Only necessary if you’re using Yabai

Open .config/yabai/yabairc in your editor of choice and add this line:

yabai -m config external_bar all:32:0
32 is for the height of sketchybar. If you change the height of sketchybar also change this number.

Run the following command on the terminal to restart yabai:

Use rectangle & set a gap for it instead of using yabai (optional)

An alternative to using Yabai (Yabai is a better option in my opinion)

Install Rectangle with homebrew.

brew install --cask rectangle
Execute this command so that Rectangle defines a gap to the top of the screen:

defaults write com.knollsoft.Rectangle screenEdgeGapTop -int 32
Restart Rectangle if already running.

Install VSCode (optional)

Install with homebrew:

brew install --cask visual-studio-code
Open sketchybar config with editor of choice

Navigate to ~/.config/sketchybar on your terminal.

Open with editor of choice.

For Vim use:

For Neovim use:

For VSCode use:

Add #!/bin/bash to sketchybarrc

In your editor, open sketchybarrc file.

To the top add this shebang line:

This is so that bash is used to interpret/execute the commands in the sketchybarrc file.

Add colors.sh file

Create colors.sh file under the sketchybar folder

Add the following to this file:

#!/bin/bash

export WHITE=0xffffffff

# -- Teal Scheme --
export BAR_COLOR=0xff001f30
export ITEM_BG_COLOR=0xff003547
export ACCENT_COLOR=0xff2cf9ed

# -- Gray Scheme --
# export BAR_COLOR=0xff101314
# export ITEM_BG_COLOR=0xff353c3f
# export ACCENT_COLOR=0xffffffff

# -- Purple Scheme --
# export BAR_COLOR=0xff140c42
# export ITEM_BG_COLOR=0xff2b1c84
# export ACCENT_COLOR=0xffeb46f9

# -- Red Scheme ---
# export BAR_COLOR=0xff23090e
# export ITEM_BG_COLOR=0xff591221
# export ACCENT_COLOR=0xffff2453

# -- Blue Scheme ---
# export BAR_COLOR=0xff021254
# export ITEM_BG_COLOR=0xff093aa8
# export ACCENT_COLOR=0xff15bdf9

# -- Green Scheme --
# export BAR_COLOR=0xff003315
# export ITEM_BG_COLOR=0xff008c39
# export ACCENT_COLOR=0xff1dfca1


# -- Orange Scheme --
# export BAR_COLOR=0xff381c02
# export ITEM_BG_COLOR=0xff99440a
# export ACCENT_COLOR=0xfff97716

# -- Yellow Scheme --
# export BAR_COLOR=0xff2d2b02
# export ITEM_BG_COLOR=0xff8e7e0a
# export ACCENT_COLOR=0xfff7fc17
The variables in this file will be used to setup the colors of the bar.

Checkout My Wallpaper Pack To Match With These Colors: Waves Wallpaper Pack

To use a colorscheme for the bar, uncomment the color variables for it and comment the ones you’re not using.

To explore more colors you can use the sketchybar color picker.

Now make this file an executable by running this command in a terminal window:

chmod +x ~/.config/sketchybar/colors.sh
Source colors.sh in sketchybarrc

Open sketchybarrc in your editor.

Add the following line to the top of sketchybarrc to load the color variables in colors.sh:

#!/bin/bash

source "$CONFIG_DIR/colors.sh" # Loads all defined colors
Now modify sketchybarrc to use the new variables from the colors.sh file like so:

##### Bar Appearance #####
# Configuring the general appearance of the bar, these are only some of the
# options available. For all options see:
# https://felixkratz.github.io/SketchyBar/config/bar
# If you are looking for other colors, see the color picker:
# https://felixkratz.github.io/SketchyBar/config/tricks#color-picker

sketchybar --bar height=37        \
                 blur_radius=30   \
                 position=top     \
                 sticky=off       \
                 padding_left=10  \
                 padding_right=10 \
                 color=$BAR_COLOR

##### Changing Defaults #####
# We now change some default values that are applied to all further items
# For a full list of all available item properties see:
# https://felixkratz.github.io/SketchyBar/config/items

sketchybar --default icon.font="Hack Nerd Font:Bold:17.0"  \
                     icon.color=$WHITE                 \
                     label.font="Hack Nerd Font:Bold:14.0" \
                     label.color=$WHITE                \
                     padding_left=5                    \
                     padding_right=5                   \
                     label.padding_left=4              \
                     label.padding_right=4             \
                     icon.padding_left=4               \
                     icon.padding_right=4
Save your changes.

On a terminal window run the following to reload sketchybar and see your changes:

Install SF Pro Font & SF Symbols

Install the SF Pro font which is the font for MacOs:

Install SF Symbols which is an icons/symbols library made for SF Pro:

brew install --cask sf-symbols
Update Default Fonts In sketchybarrc

In sketchybarrc change default fonts to the following:

##### Changing Defaults #####
# We now change some default values that are applied to all further items
# For a full list of all available item properties see:
# https://felixkratz.github.io/SketchyBar/config/items

sketchybar --default icon.font="SF Pro:Semibold:15.0"  \
                     icon.color=$WHITE                 \
                     label.font="SF Pro:Semibold:15.0" \
                     label.color=$WHITE                \
                     padding_left=5                    \
                     padding_right=5                   \
                     label.padding_left=4              \
                     label.padding_right=4             \
                     icon.padding_left=4               \
                     icon.padding_right=4
Clear default items in sketchybar

Open the sketchybarrc file and remove the following highlighted lines to clear the default items in the bar:

##### Adding Mission Control Space Indicators #####
# Now we add some mission control spaces:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item
# to indicate active and available mission control spaces

SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10")

for i in "${!SPACE_ICONS[@]}"
do
  sid=$(($i+1))
  sketchybar --add space space.$sid left                                 \
             --set space.$sid space=$sid                                 \
                              icon=${SPACE_ICONS[i]}                     \
                              background.color=0x44ffffff                \
                              background.corner_radius=5                 \
                              background.height=20                       \
                              background.drawing=off                     \
                              label.drawing=off                          \
                              script="$PLUGIN_DIR/space.sh"              \
                              click_script="yabai -m space --focus $sid"
done

##### Adding Left Items #####
# We add some regular items to the left side of the bar
# only the properties deviating from the current defaults need to be set

sketchybar --add item space_separator left                         \
           --set space_separator icon=                            \
                                 padding_left=10                   \
                                 padding_right=10                  \
                                 label.drawing=off                 \
                                                                   \
           --add item front_app left                               \
           --set front_app       script="$PLUGIN_DIR/front_app.sh" \
                                 icon.drawing=off                  \
           --subscribe front_app front_app_switched

##### Adding Right Items #####
# In the same way as the left items we can add items to the right side.
# Additional position (e.g. center) are available, see:
# https://felixkratz.github.io/SketchyBar/config/items#adding-items-to-sketchybar

# Some items refresh on a fixed cycle, e.g. the clock runs its script once
# every 10s. Other items respond to events they subscribe to, e.g. the
# volume.sh script is only executed once an actual change in system audio
# volume is registered. More info about the event system can be found here:
# https://felixkratz.github.io/SketchyBar/config/events

sketchybar --add item clock right                              \
           --set clock   update_freq=10                        \
                         icon=                                \
                         script="$PLUGIN_DIR/clock.sh"         \
                                                               \
           --add item volume right                             \
           --set volume  script="$PLUGIN_DIR/volume.sh"        \
           --subscribe volume volume_change                    \
                                                               \
           --add item battery right                            \
           --set battery script="$PLUGIN_DIR/battery.sh"       \
                         update_freq=120                       \
           --subscribe battery system_woke power_source_change

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
In a terminal window run the following to reload sketchybar:

Add calendar item to bar

Add the following highlighted lines to your sketchybarrc file.

# --- Right Side Items ---

sketchybar --add item calendar right \
           --set calendar icon=􀧞  \
                          label="$(date +'%a %d %b %I:%M %p')"

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Find the date command man page for formatting options here

In a terminal window run the following to reload sketchybar:

Add default background to items

In sketchybarrc add/modify these lines to the default item settings to setup a default background for items:

##### Changing Defaults #####
# We now change some default values that are applied to all further items
# For a full list of all available item properties see:
# https://felixkratz.github.io/SketchyBar/config/items

sketchybar --default icon.font="SF Pro:Semibold:15.0"  \
                     icon.color=$WHITE                 \
                     label.font="SF Pro:Semibold:15.0" \
                     label.color=$WHITE                \
                     background.color=$ITEM_BG_COLOR       \
                     background.corner_radius=5            \
                     background.height=24                  \
                     padding_left=5                        \
                     padding_right=5                       \
                     label.padding_left=4                  \
                     label.padding_right=10                \
                     icon.padding_left=10                  \
                     icon.padding_right=4
Make bar taller

In sketchybarrc modify this line:


##### Bar Appearance #####
# Configuring the general appearance of the bar, these are only some of the
# options available. For all options see:
# https://felixkratz.github.io/SketchyBar/config/bar
# If you are looking for other colors, see the color picker:
# https://felixkratz.github.io/SketchyBar/config/tricks#color-picker

sketchybar --bar height=37        \
                 blur_radius=30   \
                 position=top     \
                 sticky=off       \
                 padding_left=10  \
                 padding_right=10 \
                 color=$BAR_COLOR
Save your changes and run this in terminal:

Remember to update your yabairc or run the rectangle command to respect this change as we did earlier.

Add calendar.sh plugin

Remove the clock.sh file under ~/.config/sketchybar/plugins.

Add calendar.sh file in ~/.config/sketchybar/plugins.

In terminal run the following to make executable:

chmod +x ~/.config/sketchybar/plugins/calendar.sh
Add following code to plugins/calendar.sh:

#!/bin/bash

sketchybar --set $NAME label="$(date +'%a %d %b %I:%M %p')"
Open sketchybarrc and modify the calendar item to look like so:

# --- Right Side Items ---

sketchybar --add item calendar right \
           --set calendar icon=􀧞  \
                          update_freq=30 \
                          script="$PLUGIN_DIR/calendar.sh"

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Move calendar item to separate file

Create new directory called items under ~/.config/sketchybar.

Add a file called calendar.sh to ~/.config/sketchybar/items.

Make this file an executable by executing this in terminal:

chmod +x ~/.config/sketchybar/items/calendar.sh
Add calendar item code to items/calendar.sh like so:

#!/bin/bash

sketchybar --add item calendar right \
           --set calendar icon=􀧞  \
                          update_freq=30 \
                          script="$PLUGIN_DIR/calendar.sh"
Open sketchybarrc

Add the following line to sketchybarrc:

#!/bin/bash

source "$CONFIG_DIR/colors.sh" # Loads all defined colors

# This is a demo config to show some of the most important commands more easily.
# This is meant to be changed and configured, as it is intentionally kept sparse.
# For a more advanced configuration example see my dotfiles:
# https://github.com/FelixKratz/dotfiles

PLUGIN_DIR="$CONFIG_DIR/plugins"
ITEM_DIR="$CONFIG_DIR/items"
Replace calendar item code with the following near the bottom of sketchybarrc:

# --- Right Side Items ---
source $ITEM_DIR/calendar.sh

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Save your changes and reload sketchybar by running:

Add volume item to bar

Add volume.sh file under ~/.config/sketchybar/items

Make this file an executable by running:

chmod +x ~/.config/sketchybar/items/volume.sh
Add the following code to volume.sh:

#!/bin/bash

sketchybar --add item volume right \
           --set volume script="$PLUGIN_DIR/volume.sh" \
           --subscribe volume volume_change \
Open ~/.config/sketchybar/plugins/volume.sh in your editor.

Modify the code to use SF Symbol icons like so:

#!/bin/sh

# The volume_change event supplies a $INFO variable in which the current volume
# percentage is passed to the script.

if [ "$SENDER" = "volume_change" ]; then
  VOLUME=$INFO

  case $VOLUME in
    [6-9][0-9]|100) ICON="􀊩"
    ;;
    [3-5][0-9]) ICON="􀊥"
    ;;
    [1-9]|[1-2][0-9]) ICON="􀊡"
    ;;
    *) ICON="􀊣"
  esac

  sketchybar --set $NAME icon="$ICON" label="$VOLUME%"
fi
Open sketchybarrc and add the following to add the item to the bar:

# --- Right Side Items ---
source $ITEM_DIR/calendar.sh
source $ITEM_DIR/volume.sh

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Save changes and reload sketchybar by executing:

Add battery item to the bar

Add battery.sh file under ~/.config/sketchybar/items

Make this file an executable by running:

chmod +x ~/.config/sketchybar/items/battery.sh
Add the following code to battery.sh:

#!/bin/bash

sketchybar --add item battery right \
           --set battery update_freq=120 \
                         script="$PLUGIN_DIR/battery.sh" \
           --subscribe battery system_woke power_source_change
Open ~/.config/sketchybar/plugins/battery.sh in your editor.

Modify the code to use SF Symbol icons like so:

#!/bin/sh

PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

if [ $PERCENTAGE = "" ]; then
  exit 0
fi

case ${PERCENTAGE} in
  9[0-9]|100) ICON="􀛨"
  ;;
  [6-8][0-9]) ICON="􀺸"
  ;;
  [3-5][0-9]) ICON="􀺶"
  ;;
  [1-2][0-9]) ICON="􀛩"
  ;;
  *) ICON="􀛪"
esac

if [[ $CHARGING != "" ]]; then
  ICON="􀢋"
fi

# The item invoking this script (name $NAME) will get its icon and label
# updated with the current battery status
sketchybar --set $NAME icon="$ICON" label="${PERCENTAGE}%"
Open sketchybarrc and add the following to add the item to the bar:

# --- Right Side Items ---
source $ITEM_DIR/calendar.sh
source $ITEM_DIR/volume.sh
source $ITEM_DIR/battery.sh

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Save changes and reload sketchybar by executing:

Add cpu item to the bar

Add cpu.sh file under ~/.config/sketchybar/items

Make this file an executable by running:

chmod +x ~/.config/sketchybar/items/cpu.sh
Add the following code to cpu.sh:

#!/bin/bash

sketchybar --add item cpu right \
           --set cpu  update_freq=2 \
                      icon=􀧓  \
                      script="$PLUGIN_DIR/cpu.sh"
Add cpu.sh file under ~/.config/sketchybar/plugins

Make this file an executable by running:

chmod +x ~/.config/sketchybar/plugins/cpu.sh
Open ~/.config/sketchybar/plugins/cpu.sh and add the following code to it:

#!/bin/bash

CORE_COUNT=$(sysctl -n machdep.cpu.thread_count)
CPU_INFO=$(ps -eo pcpu,user)
CPU_SYS=$(echo "$CPU_INFO" | grep -v $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
CPU_USER=$(echo "$CPU_INFO" | grep $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")

CPU_PERCENT="$(echo "$CPU_SYS $CPU_USER" | awk '{printf "%.0f\n", ($1 + $2)*100}')"

sketchybar --set $NAME label="$CPU_PERCENT%"
Open sketchybarrc and add the following to add the item to the bar:

# --- Right Side Items ---
source $ITEM_DIR/calendar.sh
source $ITEM_DIR/volume.sh
source $ITEM_DIR/battery.sh
source $ITEM_DIR/cpu.sh

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Save changes and reload sketchybar by executing:

Install and setup sketchybar-app-font

Run the following command to install the sketchybar-app-font:

curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v1.0.16/sketchybar-app-font.ttf -o $HOME/Library/Fonts/sketchybar-app-font.ttf
Run the following command to add icon_map_fn.sh to ~/.config/sketchybar/plugins:

curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/download/v1.0.20/icon_map_fn.sh -o ~/.config/sketchybar/plugins/icon_map_fn.sh
Open the icon_map_fn.sh file now found in ~/.config/sketchybar/plugins and add the following to the end of the file:

icon_map "$1"

echo "$icon_result"
Make this file an executable by running the following in terminal:

chmod +x ~/.config/sketchybar/plugins/icon_map_fn.sh
Add front app item to the bar

Add front_app.sh file under ~/.config/sketchybar/items

Make this file an executable by running:

chmod +x ~/.config/sketchybar/items/front_app.sh
Add the following code to front_app.sh:

#!/bin/bash

sketchybar --add item front_app left \
           --set front_app       background.color=$ACCENT_COLOR \
                                 icon.color=$BAR_COLOR \
                                 icon.font="sketchybar-app-font:Regular:16.0" \
                                 label.color=$BAR_COLOR \
                                 script="$PLUGIN_DIR/front_app.sh"            \
           --subscribe front_app front_app_switched
Open ~/.config/sketchybar/plugins/front_app.sh modify the following to add the app icon to the front app:

#!/bin/sh

# Some events send additional information specific to the event in the $INFO
# variable. E.g. the front_app_switched event sends the name of the newly
# focused application in the $INFO variable:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar --set $NAME label="$INFO" icon="$($CONFIG_DIR/plugins/icon_map_fn.sh "$INFO")"
fi
Open sketchybarrc and add the following to add the item to the bar:

# -- Left Side Items --
source $ITEM_DIR/front_app.sh

# --- Right Side Items ---
source $ITEM_DIR/calendar.sh
source $ITEM_DIR/volume.sh
source $ITEM_DIR/battery.sh
source $ITEM_DIR/cpu.sh

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Save changes and reload sketchybar by executing:

Add spaces to the bar

Add spaces.sh file under ~/.config/sketchybar/items

Make this file an executable by running:

chmod +x ~/.config/sketchybar/items/spaces.sh
Add the following code to spaces.sh:

#!/bin/bash

SPACE_SIDS=(1 2 3 4 5 6 7 8 9 10)

for sid in "${SPACE_SIDS[@]}"
do
  sketchybar --add space space.$sid left                                 \
             --set space.$sid space=$sid                                 \
                              icon=$sid                                  \
                              label.font="sketchybar-app-font:Regular:16.0" \
                              label.padding_right=20                     \
                              label.y_offset=-1                          \
                              script="$PLUGIN_DIR/space.sh"
done
Open ~/.config/sketchybar/plugins/space.sh and replace the code with the following:

#!/bin/sh

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

source "$CONFIG_DIR/colors.sh" # Loads all defined colors

if [ $SELECTED = true ]; then
  sketchybar --set $NAME background.drawing=on \
                         background.color=$ACCENT_COLOR \
                         label.color=$BAR_COLOR \
                         icon.color=$BAR_COLOR
else
  sketchybar --set $NAME background.drawing=off \
                         label.color=$ACCENT_COLOR \
                         icon.color=$ACCENT_COLOR
fi
Open sketchybarrc and add the following to add the item to the bar:

# -- Left Side Items --
source $ITEM_DIR/spaces.sh
source $ITEM_DIR/front_app.sh

# --- Right Side Items ---
source $ITEM_DIR/calendar.sh
source $ITEM_DIR/volume.sh
source $ITEM_DIR/battery.sh
source $ITEM_DIR/cpu.sh

##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Save changes and reload sketchybar by executing:

Add space separator item & active app icons per space

Open the spaces.sh file under ~/.config/sketchybar/items.

Add the following code to it:

#!/bin/bash

SPACE_SIDS=(1 2 3 4 5 6 7 8 9 10)

for sid in "${SPACE_SIDS[@]}"
do
  sketchybar --add space space.$sid left                                 \
             --set space.$sid space=$sid                                 \
                              icon=$sid                                  \
                              label.font="sketchybar-app-font:Regular:16.0" \
                              label.padding_right=20                     \
                              label.y_offset=-1                          \
                              script="$PLUGIN_DIR/space.sh"
done

sketchybar --add item space_separator left                             \
           --set space_separator icon="􀆊"                                \
                                 icon.color=$ACCENT_COLOR \
                                 icon.padding_left=4                   \
                                 label.drawing=off                     \
                                 background.drawing=off                \
                                 script="$PLUGIN_DIR/space_windows.sh" \
           --subscribe space_separator space_windows_change
Add a new file called space_windows.sh under ~/.config/plugins

Make this file an executable by running:

chmod +x ~/.config/sketchybar/plugins/space_windows.sh
Add the following code to this file:

#!/bin/bash

if [ "$SENDER" = "space_windows_change" ]; then
  space="$(echo "$INFO" | jq -r '.space')"
  apps="$(echo "$INFO" | jq -r '.apps | keys[]')"

  icon_strip=" "
  if [ "${apps}" != "" ]; then
    while read -r app
    do
      icon_strip+=" $($CONFIG_DIR/plugins/icon_map_fn.sh "$app")"
    done <<< "${apps}"
  else
    icon_strip=" —"
  fi

  sketchybar --set space.$space label="$icon_strip"
fi
Save changes and reload sketchybar by executing:

Add media item to the bar (for current song playing)

Add media.sh file under ~/.config/sketchybar/items

Make this file an executable by running:

chmod +x ~/.config/sketchybar/items/media.sh
Add the following code to items/media.sh:

#!/bin/bash

sketchybar --add item media e \
           --set media label.color=$ACCENT_COLOR \
                       label.max_chars=20 \
                       icon.padding_left=0 \
                       scroll_texts=on \
                       icon=􀑪             \
                       icon.color=$ACCENT_COLOR   \
                       background.drawing=off \
                       script="$PLUGIN_DIR/media.sh" \
           --subscribe media media_change
Add media.sh file under ~/.config/sketchybar/plugins

Make this file an executable by running:

chmod +x ~/.config/sketchybar/plugins/media.sh
Open ~/.config/sketchybar/plugins/media.sh and add the following code to it:

#!/bin/bash

STATE="$(echo "$INFO" | jq -r '.state')"
if [ "$STATE" = "playing" ]; then
  MEDIA="$(echo "$INFO" | jq -r '.title + " - " + .artist')"
  sketchybar --set $NAME label="$MEDIA" drawing=on
else
  sketchybar --set $NAME drawing=off
fi
Open sketchybarrc and add the following to add the item to the bar:

# -- Left Side Items --
source $ITEM_DIR/spaces.sh
source $ITEM_DIR/front_app.sh

# -- Right Side Of Notch Items --
source $ITEM_DIR/media.sh

# -- Right Side Items --
source $ITEM_DIR/calendar.sh
source $ITEM_DIR/volume.sh
source $ITEM_DIR/battery.sh
source $ITEM_DIR/cpu.sh


##### Finalizing Setup #####
# The below command is only needed at the end of the initial configuration to
# force all scripts to run the first time, it should never be run in an item script.

sketchybar --update
Save changes and reload sketchybar by executing:

YOU’RE DONE! 🚀
