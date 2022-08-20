#!/bin/bash


VENV_NAME=env_odoo_forum_user_profile


if [ -z "`which python3`" ];then
	echo "Is Python 3 installed in your system?" >&2
	exit 1
fi

SELF=$(python3 -c "import os; print(os.path.realpath('${BASH_SOURCE[0]}'))")
SCRIPT_DIR="$(dirname "${SELF}")"
SCRIPT_DIR_NAME="`basename ${SCRIPT_DIR}`"
ENV_BIN="${SCRIPT_DIR}/${VENV_NAME}/bin/"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

export JUPYTER_CONFIG_DIR="${SCRIPT_DIR}/.jupyter"


if [[ ! -d "${ENV_BIN}" ]];then
	rm -rf "${JUPYTER_CONFIG_DIR}"
	echo -e "\n*** Initializing virtual Python environment\n"
	cd "${SCRIPT_DIR}" &&
	python3 -m venv "${VENV_NAME}" &&
	"${ENV_BIN}pip" install -U pip &&
	"${ENV_BIN}pip" install -U setuptools wheel || exit 1
	
	REQUIREMENTS_FILE="requirements.txt"
	echo " ** Installing dependencies from '${REQUIREMENTS_FILE}'..."
	"${ENV_BIN}pip" install -r ${REQUIREMENTS_FILE} || exit 1


	if [[ ! -f "${ENV_BIN}jupyter-lab" ]];then
		echo -e "\n*** WARNING: jupyterlab was not installed via the \"$(basename ${REQUIREMENTS_FILE})\"..."
		echo -e "*** Installing default version of jupyterlab\n"
		"${ENV_BIN}pip" install jupyterlab || exit 4
	fi

	echo -e "\n*** Generating jupyterlab configuration\n"
	EXT_CONFIG_FILE="${JUPYTER_CONFIG_DIR}/lab/user-settings/@jupyterlab/notebook-extension/tracker.jupyterlab-settings"
	THEME_CONFIG_FILE="${JUPYTER_CONFIG_DIR}/lab/user-settings/@jupyterlab/apputils-extension/themes.jupyterlab-settings"
	"${ENV_BIN}jupyter-lab" --generate-config &&
	mkdir -p "`dirname ${EXT_CONFIG_FILE}`" &&
	cat <<EOF >> "${EXT_CONFIG_FILE}" &&
{
  "maxNumberOutputs": 700,
  "codeCellConfig": {
    "rulers": [
      72,
      79,
      99
    ]
  }
}
EOF
	mkdir -p "`dirname ${THEME_CONFIG_FILE}`" &&
	cat <<EOF >> "${THEME_CONFIG_FILE}" &&
{
    // Theme
    // @jupyterlab/apputils-extension:themes
    // Theme manager settings.
    // *************************************

    // Selected Theme
    // Application-level visual styling theme
    "theme": "JupyterLab Dark"
}
EOF
	cat <<EOF >> "${JUPYTER_CONFIG_DIR}/jupyter_lab_config.py" &&


###
## refference: https://jupyter-notebook.readthedocs.io/en/v6.4.8/extending/savehooks.html
###

import io
import os
from jupyter_server.utils import to_api_path

_script_exporter = None

def script_post_save(model, os_path, contents_manager, **kwargs):
    """convert notebooks to Python script after save with nbconvert

    replaces 'jupyter notebook --script'
    """
    from nbconvert.exporters.script import ScriptExporter

    if model['type'] != 'notebook':
        return

    global _script_exporter

    if _script_exporter is None:
        _script_exporter = ScriptExporter(parent=contents_manager)

    log = contents_manager.log

    base, ext = os.path.splitext(os_path)
    script, resources = _script_exporter.from_filename(os_path)
    script_fname = base + resources.get('output_extension', '.txt')
    log.info("Saving script /%s", to_api_path(script_fname, contents_manager.root_dir))

    with io.open(script_fname, 'w', encoding='utf-8') as f:
        f.write(script)

c.FileContentsManager.post_save_hook = script_post_save


##
# referrence: https://nbconvert.readthedocs.io/en/6.5.0/nbconvert_library.html#Example
##

from traitlets import Integer
from nbconvert.preprocessors import Preprocessor
from datetime import datetime, timezone

class ISO8601DateTimeNow(Preprocessor):
    """This preprocessor makes the current time in ISO 8601 format available for use in templates"""

    def preprocess(self, nb, resources):
        iso_now = datetime.utcnow().replace(microsecond=0, tzinfo=timezone.utc).isoformat()
        self.log.info(f'ISO8601DateTimeNow now(): resources["iso8610_datetime_utcnow"] = {iso_now}')
        resources["iso8610_datetime_utcnow"] = iso_now
        return nb, resources

c.HTMLExporter.preprocessors = [ISO8601DateTimeNow]


EOF
	sed -i.bak 's/^.*\(c.ServerApp.max_body_size.*=.*[0-9]\).*$/\10/g' "${JUPYTER_CONFIG_DIR}/jupyter_lab_config.py" &&
	sed -i.bak 's/^.*\(c.ServerApp.max_buffer_size.*=.*[0-9]\).*$/\10/g' "${JUPYTER_CONFIG_DIR}/jupyter_lab_config.py" &&
	rm -f "${JUPYTER_CONFIG_DIR}/jupyter_lab_config.py.bak" || exit 5
	

fi

if [[ ! -f "${ENV_BIN}jupyter-lab" ]];then
	echo -e "\n*** ERROR: could not find the jupyter-lab..."
	exit 6
fi

export PATH=${ENV_BIN}:$PATH

echo -e "\n*** STARTING Jupyter Lab (PID=$$)...\n"
echo $$ > "${JUPYTER_CONFIG_DIR}/jupyter-lab.pid"
exec "${ENV_BIN}jupyter-lab" --notebook-dir "${ROOT_DIR}" --LabApp.default_url /lab?file-browser-path="/${SCRIPT_DIR_NAME}"



