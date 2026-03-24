#!/bin/bash

PANEL_EDITION="intl"
EDITION_FILE=".selected_edition"

osCheck=$(uname -a)
if [[ $osCheck =~ 'x86_64' ]]; then
    architecture="amd64"
elif [[ $osCheck =~ 'arm64' ]] || [[ $osCheck =~ 'aarch64' ]]; then
    architecture="arm64"
elif [[ $osCheck =~ 'armv7l' ]]; then
    architecture="armv7"
elif [[ $osCheck =~ 'ppc64le' ]]; then
    architecture="ppc64le"
elif [[ $osCheck =~ 's390x' ]]; then
    architecture="s390x"
elif [[ $osCheck =~ 'riscv64' ]]; then
    architecture="riscv64"
else
    echo "Unsupported system architecture. Please use a supported OS/architecture listed in the official documentation."
    exit 1
fi

if [[ ! ${INSTALL_MODE} ]]; then
    INSTALL_MODE="stable"
else
    if [[ ${INSTALL_MODE} != "dev" && ${INSTALL_MODE} != "stable" ]]; then
        echo "Invalid INSTALL_MODE: ${INSTALL_MODE}. Supported values are: dev, stable."
        exit 1
    fi
fi

GITHUB_ORG="tinohostvn"
GITHUB_REPO="tinohost-agent"
GITHUB_API="https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}"

if [[ "${INSTALL_MODE}" == "dev" ]]; then
    VERSION=$(curl -s "${GITHUB_API}/releases" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "\(.*\)".*/\1/')
else
    VERSION=$(curl -s "${GITHUB_API}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
fi

if [[ "x${VERSION}" == "x" ]]; then
    echo "Failed to fetch the latest version (mode: ${INSTALL_MODE}). Please try again later."
    exit 1
fi

PACKAGE_FILE_NAME="tinohost-${VERSION}-linux-${architecture}.tar.gz"
PACKAGE_DOWNLOAD_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download/${VERSION}/${PACKAGE_FILE_NAME}"
HASH_FILE_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download/${VERSION}/checksums.txt"
EXPECTED_HASH=$(curl -sL "$HASH_FILE_URL" | grep "$PACKAGE_FILE_NAME" | awk '{print $1}')

if [[ -f ${PACKAGE_FILE_NAME} ]]; then
    actual_hash=$(sha256sum "$PACKAGE_FILE_NAME" | awk '{print $1}')
    if [[ "$EXPECTED_HASH" == "$actual_hash" ]]; then
        echo "Local package found and checksum verified. Skipping download."
        rm -rf tinohost-${VERSION}-linux-${architecture}
        tar zxf ${PACKAGE_FILE_NAME}
        cd tinohost-${VERSION}-linux-${architecture}
        echo "$PANEL_EDITION" > "$EDITION_FILE"
        /bin/bash install.sh
        exit 0
    else
        echo "Local package checksum mismatch. Redownloading package."
        rm -f ${PACKAGE_FILE_NAME}
    fi
fi

echo "Preparing to download TinoHost ${VERSION} (${architecture}, mode: ${INSTALL_MODE})."
echo "Download URL: ${PACKAGE_DOWNLOAD_URL}"

curl -sLO ${PACKAGE_DOWNLOAD_URL}
if [[ ! -f ${PACKAGE_FILE_NAME} ]]; then
    echo "Package download failed. Please check network connectivity and retry."
    exit 1
fi

tar zxf ${PACKAGE_FILE_NAME}
if [[ $? != 0 ]]; then
    echo "Package extraction failed. The downloaded file may be incomplete or corrupted."
    rm -f ${PACKAGE_FILE_NAME}
    exit 1
fi
cd tinohost-${VERSION}-linux-${architecture}
echo "$PANEL_EDITION" > "$EDITION_FILE"

/bin/bash install.sh
