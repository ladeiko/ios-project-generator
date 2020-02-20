#!/usr/bin/env bash

SOURCE_URL=https://github.com/ladeiko/ios-project-generator.git
INSTALL_PATH=$HOME/.code-tools/ios-project-generator
TARGET=$HOME/.code-tools/bin/ios-project-generator

if [ -d ${INSTALL_PATH}/.git ]; then    
    ( cd ${INSTALL_PATH} && git fetch --all ) || exit 1
    ( cd ${INSTALL_PATH} && git reset --hard origin/master ) || exit 1
    ( cd ${INSTALL_PATH} && git pull origin master ) || exit 1
else
    mkdir -p $(dirname ${INSTALL_PATH})
    git clone ${SOURCE_URL} ${INSTALL_PATH}
fi

grep -q '.code-tools/bin' $HOME/.bashrc || {
    echo "export PATH=\$HOME/.code-tools/bin:\$PATH" >> ~/.bashrc    
}

mkdir -p $(dirname ${TARGET})
echo 'if ping -q -c 1 -W 1 github.com >/dev/null; then' > "$TARGET"
echo "  ( cd ${INSTALL_PATH} && git fetch --all ) || exit 1" >> "$TARGET"
echo "  ( cd ${INSTALL_PATH} && git reset --hard origin/master ) || exit 1" >> "$TARGET"
echo "  ( cd ${INSTALL_PATH} && git pull origin master ) || exit 1" >> "$TARGET"
echo 'fi' >> "$TARGET"
echo "${INSTALL_PATH}/gen.sh \$@" >> "$TARGET"
chmod +x "$TARGET"

export PATH=$HOME/.code-tools/bin:$PATH
