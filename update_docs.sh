#!/bin/bash


VENV_NAME=env_odoo_forum_user_profile

NOTEBOOK_NAME="Forum User Profile.ipynb"


SELF=$(python3 -c "import os; print(os.path.realpath('${BASH_SOURCE[0]}'))")
SCRIPT_DIR="$(dirname "${SELF}")"
ENV_BIN="${SCRIPT_DIR}/${VENV_NAME}/bin/"

export JUPYTER_CONFIG_DIR="${SCRIPT_DIR}/.jupyter"


DOCS_DIR="${SCRIPT_DIR}/docs"


##
# Generate HTML
##
"${ENV_BIN}jupyter-nbconvert" "${NOTEBOOK_NAME}" \
  --config "${JUPYTER_CONFIG_DIR}/jupyter_lab_config.py" \
  --to html --output-dir="${DOCS_DIR}" --output="index" --template OGP_classic


##
# Update the `images/` folder
##
cp -rf images/ "${DOCS_DIR}"

##
# Generate PDF
##
"${ENV_BIN}jupyter-nbconvert" "${NOTEBOOK_NAME}" \
  --embed-images --to pdf --output-dir="${DOCS_DIR}"


##
# Update custom 404 page
##
UPDATED_404_TODAY=$(python3 <<EOF
import os
from datetime import datetime as dt
from datetime import timedelta as td
print((dt.now() - dt.fromtimestamp(os.path.getctime("docs/404.html"))) < td(days=1))
EOF
)
# Rate limiting to one download per day:
if [ "${UPDATED_404_TODAY}" != "True" ];then
    echo "Updating custom 404 page"
    rm -f "${DOCS_DIR}/404.html"
    curl --output "${DOCS_DIR}/404.html" "https://raw.githubusercontent.com/sentinel-1/sentinel-1.github.io/master/docs/404.html"
else
    echo "SKIPPING custom 404 page update"
fi


##
# Commit the "Generate updated docs" if requested
##
if [ "${1}" == "commit" ];then
    echo
    echo "** You requested to make the \"Generate updated docs\" commit in addition."
    echo
    while true;do
        read -p "Do you want to continue? [Y/n] " yn
        case ${yn} in
            [Yy]*) break ;;
            [Nn]*) echo "Abort."; exit -1 ;;
        esac
    done
    echo " - Resetting the git staging area"
    git reset
    echo " - Adding the ./docs/ directory to the git staging area"
    git add ./docs/
    echo " - Making the \"Generate updated docs\" commit"
    git commit -m "Generate updated docs"
    echo " - done commiting the \"Generate updated docs\""
else
    echo "** You did NOT request to make the \"Generate updated docs\" commit in addition."
    echo " - Pass the \"commit\" as an argument to this script in order to request the commit."
fi

