#!/bin/bash

SUCCEEDED=0
TARGET_PATH=

function cleanup {
    if [ $SUCCEEDED -eq 0 ];then
        [ -z "$TARGET_PATH" ] || rm  -rf "$TARGET_PATH"
    fi
}
trap cleanup EXIT SIGINT SIGTERM SIGHUP SIGQUIT

function removeProjectGroup() {
ruby <<-EORUBY
require 'rubygems'
require 'xcodeproj'

\$project_path='$1'
\$project = Xcodeproj::Project.open(\$project_path)

def findGroup(name)
    components = name.split '/'
    current_groups = \$project.groups
    result = []
    while components.size != 0
        c = components.delete_at(0)
        g = nil
        current_groups.each do |group|
            if group.name == c || group.path == c
                g = group
                break
            end
        end
        return nil if g.nil?
        result.push g
        current_groups = g.children
    end
        
    return result
end

target = findGroup('$2')
if !target.nil? && target.size > 0
  target.last.remove_from_project
  \$project.save(\$project_path)
end
EORUBY
[ $? -eq 0 ] || exit 1
}

# TODO
function removeProjectFile() { 
ruby <<-EORUBY
require 'rubygems'
require 'xcodeproj'

\$project_path='$1'
\$project = Xcodeproj::Project.open(\$project_path)

def findGroup(name)
    components = name.split '/'
    file_name = components.delete_at(components.length - 1)
    current_groups = \$project.groups
    result = []
    while components.size != 0
        c = components.delete_at(0)
        g = nil
        current_groups.each do |group|
            if group.name == c || group.path == c
                g = group
                break
            end
        end
        return nil if g.nil?
        result.push g
        current_groups = g.children
    end

    files = []
    result.last.files.each do |file|
        if file.file_ref.path == file_name
            files.push file
        end
    end

    return files
end

target = findGroup('$2')
if !target.nil? && target.size > 0
  target.last.remove_from_project
  \$project.save(\$project_path)
end
EORUBY
[ $? -eq 0 ] || exit 1
}

function removeProjectBuildPhase() {
ruby <<-EORUBY
require 'rubygems'
require 'xcodeproj'

\$project_path='$1'
\$project = Xcodeproj::Project.open(\$project_path)

def findPhase(name)
  result = []
  \$project.targets.each do |target|
    target.build_phases.grep(Xcodeproj::Project::Object::PBXShellScriptBuildPhase).each do |phase|
      if phase.name == name
        result.push phase
      end
    end
  end
  return result
end

phases = findPhase('$2')
if !phases.nil? && phases.size > 0
  phases.each do |phase|
    phase.remove_from_project
  end
  \$project.save(\$project_path)
end
EORUBY
[ $? -eq 0 ] || exit 1
}

function removeProjectCompileSource() {
ruby <<-EORUBY
require 'rubygems'
require 'xcodeproj'

\$project_path='$1'
\$project = Xcodeproj::Project.open(\$project_path)

def findSource(name)
  result = []
  \$project.targets.each do |target|
    target.build_phases.grep(Xcodeproj::Project::Object::PBXSourcesBuildPhase).each do |phase|
      phase.files.each do |file|
        if file.file_ref.path == name
          result.push file
        end
      end
    end
  end
  return result
end

targets = findSource('$2')
if !targets.nil? && targets.size > 0
  targets.each do |target|
    target.remove_from_project
  end
  \$project.save(\$project_path)
end
EORUBY
[ $? -eq 0 ] || exit 1
}


function replaceTextInFile() {
    local FROM="$1"
    local TO="$2"
    local WHERE="$3"
    [ -f "$WHERE" ] || return
    ruby \
        -e "text = File.read('$WHERE')" \
        -e "new_contents = text.gsub(%r{$FROM}m, '$TO')" \
        -e "File.open('$WHERE', 'w') { |file| file.puts new_contents }"
}

function removePod() {
    local POD_NAME=$1
    replaceTextInFile "\\s*pod\\s+.${POD_NAME}.(,[^\\n]+)?" "" "$TARGET_PATH/Podfile"
}

function moveItem() {
    local ITEM="$1"
    local SRC="$(echo $ITEM | tr '@' ' ')"
    local DST=$(ruby -e "print '$ITEM'.sub! 'BOOTSTRAPAPP', '${NEW_NAME}'" | tr '@' ' ')
    if [ "$SRC" != "$DST" ]; then
        echo "Renaming $SRC -> $DST"
        mv "$SRC" "$DST" || exit 1
    fi
}

function removeFolders() {
    find "$TARGET" -type d -name "*.xcuserdatad" -exec rm -rf {} \;
}

function renameFolders() {
    FOUND=$(find "${TARGET}" -type d -name '*BOOTSTRAPAPP*' | tr ' ' '@' | sort | head -n 1)
    while [ ! -z "$FOUND"  ] ; do
        moveItem "$FOUND"
        FOUND=$(find "${TARGET}" -type d -name '*BOOTSTRAPAPP*' | tr ' ' '@' | sort | head -n 1)
    done
}

function renameFiles() {
    FOUND=$(find "${TARGET}" -type f -name '*BOOTSTRAPAPP*' | tr ' ' '@' | sort | head -n 1)
    while [ ! -z "$FOUND"  ] ; do
        moveItem "$FOUND"
        FOUND=$(find "${TARGET}" -type f -name '*BOOTSTRAPAPP*' | tr ' ' '@' | sort | head -n 1)
    done
}

function renameInFiles() {
    local FOUND

    echo "Replacing BOOTSTRAPAPP..."
    FOUND=$(find "${TARGET}" -type f \( -name "*.swift" \
                                        -o  -name "*.m" \
                                        -o  -name "*.h" \
                                        -o  -name "*.md" \
                                        -o  -name "*.yml" \
                                        -o  -name "*.plist" \
                                        -o  -name "*.strings" \
                                        -o  -name "generator" \
                                        -o  -name "Rambafile" \
                                        -o  -name "Makefile_Models" \
                                        -o  -name "LICENSE" \
                                        -o  -name "*.pbxproj" \
                                        -o  -name "*.xcworkspacedata" \
                                        -o  -name "*.xcscheme" \
                                        -o  -name "Podfile"  \) \
                                        -exec grep -l BOOTSTRAPAPP {} \; | tr ' ' '@')
    for ITEM in $FOUND; do
        NAME="$(echo $ITEM | tr '@' ' ')"
        echo "Updating $NAME"
        sed -i '' -e "s/BOOTSTRAPAPP/$NEW_NAME/g" "$NAME" || { echo "Error in $NAME";  exit 1; }
    done

    echo "Replacing AUTHOR..."
    local AUTHOR="$(id -F)"
    FOUND=$(find "${TARGET}" -type f \( -name "*.swift" \
                                        -o  -name "*.m" \
                                        -o  -name "*.h" \
                                        -o  -name "*.md" \
                                        -o  -name "*.yml" \
                                        -o  -name "*.plist" \
                                        -o  -name "*.strings" \
                                        -o  -name "generator" \
                                        -o  -name "Rambafile" \
                                        -o  -name "Makefile_Models" \
                                        -o  -name "LICENSE" \
                                        -o  -name "*.pbxproj" \
                                        -o  -name "*.xcworkspacedata" \
                                        -o  -name "*.xcscheme" \
                                        -o  -name "Podfile"  \) \
                                        -exec grep -l __AUTHOR__ {} \; | tr ' ' '@')
    for ITEM in $FOUND; do
        NAME="$(echo $ITEM | tr '@' ' ')"
        echo "Updating $NAME"
        sed -i '' -e "s/__AUTHOR__/$AUTHOR/g" "$NAME" || { echo "Error in $NAME";  exit 1; }
    done

    echo "Replacing YEAR..."
    local YEAR=$(date +"%Y")
    FOUND=$(find "${TARGET}" -type f \( -name "*.swift" \
                                        -o  -name "*.m" \
                                        -o  -name "*.h" \
                                        -o  -name "*.md" \
                                        -o  -name "*.yml" \
                                        -o  -name "*.plist" \
                                        -o  -name "*.strings" \
                                        -o  -name "generator" \
                                        -o  -name "Rambafile" \
                                        -o  -name "LICENSE" \
                                        -o  -name "*.pbxproj" \
                                        -o  -name "*.xcworkspacedata" \
                                        -o  -name "*.xcscheme" \
                                        -o  -name "Makefile_Models" \
                                        -o  -name "Podfile"  \) \
                                        -exec grep -l __YEAR__ {} \; | tr ' ' '@')
    for ITEM in $FOUND; do
        NAME="$(echo $ITEM | tr '@' ' ')"
        echo "Updating $NAME"
        sed -i '' -e "s/__YEAR__/$YEAR/g" "$NAME" || { echo "Error in $NAME";  exit 1; }
    done

    echo "Replacing ORGANIZATION..."
    local ORGANIZATION="$AUTHOR"
    if /usr/libexec/PlistBuddy -c 'Print :PBXCustomTemplateMacroDefinitions:ORGANIZATIONNAME' "$HOME/Library/Preferences/com.apple.Xcode.plist" &>/dev/null ;then
        ORGANIZATION=$(/usr/libexec/PlistBuddy -c 'Print :PBXCustomTemplateMacroDefinitions:ORGANIZATIONNAME' "$HOME/Library/Preferences/com.apple.Xcode.plist")
    fi

    if [ -n "$ORGANIZATION" ]; then
        FOUND=$(find "${TARGET}" -type f \( -name "*.swift" \
                                        -o  -name "*.m" \
                                        -o  -name "*.h" \
                                        -o  -name "*.md" \
                                        -o  -name "*.yml" \
                                        -o  -name "*.plist" \
                                        -o  -name "*.strings" \
                                        -o  -name "generator" \
                                        -o  -name "Rambafile" \
                                        -o  -name "Makefile_Models" \
                                        -o  -name "LICENSE" \
                                        -o  -name "*.pbxproj" \
                                        -o  -name "*.xcworkspacedata" \
                                        -o  -name "*.xcscheme" \
                                        -o  -name "Podfile"  \) \
                                        -exec grep -l __ORGANIZATION__ {} \; | tr ' ' '@')
        for ITEM in $FOUND; do
            NAME="$(echo $ITEM | tr '@' ' ')"
            echo "Updating $NAME"
            sed -i '' -e "s/__ORGANIZATION__/$ORGANIZATION/g" "$NAME" || { echo "Error in $NAME";  exit 1; }
        done

        FOUND=$(find "${TARGET}" -type f -exec grep -l "__ORGANIZATION NAME__" {} \; | tr ' ' '@')
        for ITEM in $FOUND; do
            NAME="$(echo $ITEM | tr '@' ' ')"
            echo "Updating $NAME"
            sed -i '' -e "s/__ORGANIZATION NAME__/$ORGANIZATION/g" "$NAME" || { echo "Error in $NAME";  exit 1; }
        done
    fi
}

function genApp() {

    if [ -n "$2" ]; then
        TARGET=$(dirname "$1")
        NEW_NAME=$2
        TARGET_PATH="$1"
    else
        TARGET=$(dirname "$1")
        NEW_NAME=$(basename "$1")
        TARGET_PATH="$TARGET/$NEW_NAME"
    fi

    [ -n "$TARGET" ] || { echo "ERROR: Invalid arguments"; exit 1; }
    [ -n "$NEW_NAME" ] || { echo "ERROR: Invalid arguments"; exit 1; }

    [ ! -d "$TARGET_PATH" ] || { TARGET_PATH=; echo "ERROR: $TARGET_PATH already exists"; exit 1; }

    local REPO="https://github.com/ladeiko/ios-project-generator-BOOTSTRAPAPP.git"
    local LOCAL_REPO="$HOME/.code-tools/BOOTSTRAPAPP"

    mkdir -p "$(dirname $LOCAL_REPO)" || exit 1

    if [ -d "$LOCAL_REPO/.git" ]; then
        ( cd "$LOCAL_REPO" && git fetch --all ) || exit 1
        ( cd "$LOCAL_REPO" && git reset --hard origin/master ) || exit 1
        ( cd "$LOCAL_REPO" && git pull origin master ) || exit 1
    else
        rm -rf "$LOCAL_REPO"
        git clone "$REPO" "$LOCAL_REPO" || exit 1
    fi

    cp -R "$LOCAL_REPO" "$TARGET_PATH"
    rm -rf "$TARGET_PATH/.git"

    removeFolders
    renameFolders
    renameFiles
    renameInFiles

    if [ $USING_COREDATA -eq 0 ]; then
        removeProjectGroup "$TARGET_PATH/$NEW_NAME.xcodeproj" "$NEW_NAME/Sources/Entities"
        removeProjectGroup "$TARGET_PATH/$NEW_NAME.xcodeproj" "$NEW_NAME/Sources/Services/Database"
        removeProjectBuildPhase "$TARGET_PATH/$NEW_NAME.xcodeproj" "[CUSTOM GENERATED] Generate Database Models"
        removeProjectCompileSource "$TARGET_PATH/$NEW_NAME.xcodeproj" "Model.xcdatamodeld"
        removeProjectCompileSource "$TARGET_PATH/$NEW_NAME.xcodeproj" "DatabaseService.swift"
        removeProjectCompileSource "$TARGET_PATH/$NEW_NAME.xcodeproj" "DatabaseServiceImpl.swift"
        removeProjectCompileSource "$TARGET_PATH/$NEW_NAME.xcodeproj" "DBObject.swift"
        removePod 'MagicalRecord'
        rm -rf "$TARGET_PATH/$NEW_NAME/Sources/Entities"
        rm -rf "$TARGET_PATH/$NEW_NAME/Sources/Services/Database"
        rm -rf "$TARGET_PATH/Scripts/Makefile_Models"
        rm -rf "$TARGET_PATH/Scripts/PONSOTemplates"
        rm -rf "$TARGET_PATH/Scripts/mogenerator"
        replaceTextInFile "\\s+// <DATABASE_SERVICE_CODE BEGIN>.+// <DATABASE_SERVICE_CODE END>" "" "$TARGET_PATH/$NEW_NAME/Sources/Services/ServicesImpl.swift"
    else
        echo "Using CoreData"
    fi

    if [ $USING_RSWIFT -eq 0 ]; then
        removeProjectBuildPhase "$TARGET_PATH/$NEW_NAME.xcodeproj" "[CUSTOM GENERATED] R.swift"
        removeProjectGroup "$TARGET_PATH/$NEW_NAME.xcodeproj" "$NEW_NAME/Resources/Generated/R.swift"
        removeProjectCompileSource "$TARGET_PATH/$NEW_NAME.xcodeproj" "R.generated.swift"
        rm -rf "$NEW_NAME/Resources/Generated/R.swift"
        removePod 'R.swift'
    else
        echo "Using R.swift"
    fi

    if [ $USING_SWIFTGEN -eq 0 ]; then
        removeProjectBuildPhase "$TARGET_PATH/$NEW_NAME.xcodeproj" "[CUSTOM GENERATED] SwiftGen"
        removeProjectGroup "$TARGET_PATH/$NEW_NAME.xcodeproj" "$NEW_NAME/Resources/Generated/SwiftGen"
        removeProjectCompileSource "$TARGET_PATH/$NEW_NAME.xcodeproj" "strings.swift"
        removeProjectCompileSource "$TARGET_PATH/$NEW_NAME.xcodeproj" "assets-images.swift"
        rm -rf "$NEW_NAME/Resources/Generated/SwiftGen"
        removePod 'SwiftGen'
    else
        echo "Using SwiftGen"
    fi

    ( cd "$TARGET_PATH" && pod install ) || exit 1

    if command -v generamba>/dev/null; then
        ( cd "$TARGET_PATH" && generamba template install && touch ".TemplatesInstalled") || exit 1
        if [ -z "$(generamba version | grep -o ladeiko)" ]; then
            echo "WARN: Please install generamba from https://github.com/ladeiko/Generamba"
        fi
    fi

    open "$TARGET_PATH/$NEW_NAME.xcworkspace"
}

function usage() {
    local SCRIPT_NAME=ios-project-generator
    echo ""
    echo "Show help:"
    echo "  $SCRIPT_NAME --help"
    echo "  $SCRIPT_NAME -h"
    echo ""
    echo "Generate iOS project:"
    echo "  $SCRIPT_NAME --app path-to-ios-project-folder"
    echo "  $SCRIPT_NAME [--type viper] --app path-to-ios-project-folder"
    echo "  $SCRIPT_NAME --app path-to-ios-project-folder --name ProjectName"
    echo "  $SCRIPT_NAME [--type viper] --app path-to-ios-project-folder --name ProjectName"
    echo ""
    echo "When you want to use database with coredata store pass --coredata:"
    echo "  $SCRIPT_NAME [--type viper] --app path-to-ios-project-folder --name ProjectName --coredata"
    echo ""
    echo "To add R.swift (https://github.com/mac-cain13/R.swift) support just add --rswift"
    echo "To add SwiftGen (https://github.com/SwiftGen/SwiftGen) support just add --swiftgen"
    echo ""
    echo "  Current supported application types: viper"
    echo "  By default 'viper' application type is used"
    echo ""
}

ACTION=
TYPE=viper
USING_COREDATA=0
USING_RSWIFT=0
USING_SWIFTGEN=0

while [ "$1" != "" ]; do
    PARAM="$1"
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;

        --app)
            ACTION=app
            shift
            APP_PATH="$1"
            ;;

        --name)
            shift
            APP_NAME="$1"
            ;;

        --type)
            shift
            TYPE="$1"
            ;;

        --coredata)
            USING_COREDATA=1
            ;;

        --rswift)
            USING_RSWIFT=1
            USING_SWIFTGEN=0
            ;;

        --swiftgen)
            USING_SWIFTGEN=1
            USING_RSWIFT=0
            ;;                        

        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

case $ACTION in
    app)
        case $TYPE in
            viper)
                genApp "$APP_PATH" "$APP_NAME"
                SUCCEEDED=1
            ;;
            *)
                echo "ERROR: Unsupported application type '$TYPE'";
                usage
            ;;
        esac
    ;;

    *)
        echo "Enter app name:"
        read APP_NAME

        [[ -n "$APP_NAME" ]] || { echo "ERROR: Empty name"; exit 1; }

        APP_PATH=$(pwd)/$APP_NAME

        declare -a COREDATA_ACTION_OPTIONS

        USE_COREDATA_YES="Use CoreData"
        USE_COREDATA_NO="Skip"
        USE_COREDATA_CANCEL="CANCEL"

        COREDATA_ACTION_OPTIONS[${#COREDATA_ACTION_OPTIONS[*]}]=$USE_COREDATA_YES;
        COREDATA_ACTION_OPTIONS[${#COREDATA_ACTION_OPTIONS[*]}]=$USE_COREDATA_NO;
        COREDATA_ACTION_OPTIONS[${#COREDATA_ACTION_OPTIONS[*]}]=$USE_COREDATA_CANCEL;

        select opt in "${COREDATA_ACTION_OPTIONS[@]}"; do
            case $opt in
                $USE_COREDATA_YES )
                    USING_COREDATA=1
                    break
                ;;
                $USE_COREDATA_NO )
                    break
                ;;
                $USE_COREDATA_CANCEL )
                    exit 1
                ;;
            esac
        done

        declare -a SWIFTGEN_RWIFT_ACTION_OPTIONS

        SWIFTGEN_RWIFT_ACTION_SWIFTGEN="Use SwiftGen"
        SWIFTGEN_RWIFT_ACTION_RSWIFT="Use R.swift"
        SWIFTGEN_RWIFT_ACTION_OPTIONS_NO="Skip"
        SWIFTGEN_RWIFT_ACTION_OPTIONS_CANCEL="CANCEL"

        SWIFTGEN_RWIFT_ACTION_OPTIONS[${#SWIFTGEN_RWIFT_ACTION_OPTIONS[*]}]=$SWIFTGEN_RWIFT_ACTION_SWIFTGEN;
        SWIFTGEN_RWIFT_ACTION_OPTIONS[${#SWIFTGEN_RWIFT_ACTION_OPTIONS[*]}]=$SWIFTGEN_RWIFT_ACTION_RSWIFT;
        SWIFTGEN_RWIFT_ACTION_OPTIONS[${#SWIFTGEN_RWIFT_ACTION_OPTIONS[*]}]=$SWIFTGEN_RWIFT_ACTION_OPTIONS_NO;
        SWIFTGEN_RWIFT_ACTION_OPTIONS[${#SWIFTGEN_RWIFT_ACTION_OPTIONS[*]}]=$SWIFTGEN_RWIFT_ACTION_OPTIONS_CANCEL;

        select opt in "${SWIFTGEN_RWIFT_ACTION_OPTIONS[@]}"; do
            case $opt in
                $SWIFTGEN_RWIFT_ACTION_SWIFTGEN )
                    USING_SWIFTGEN=1
                    break
                ;;
                
                $SWIFTGEN_RWIFT_ACTION_RSWIFT )
                    USING_RSWIFT=1
                    break
                ;;

                $SWIFTGEN_RWIFT_ACTION_OPTIONS_NO )
                    break
                ;;

                $SWIFTGEN_RWIFT_ACTION_OPTIONS_CANCEL )
                    exit 1
                ;;

            esac
        done

        genApp "$APP_PATH" "$APP_NAME"
        SUCCEEDED=1
    ;;
esac
