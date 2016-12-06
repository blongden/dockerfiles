#!/bin/bash
set -xe

mkdir -p /home/build/.hem/gems/ && chown -R build:build /home/build/.hem/

# Ensure the hem settings files exists by running confd before continuing
source /usr/local/share/bootstrap/setup.sh
source /usr/local/share/bootstrap/run_confd.sh

# install DB and assets
if [ -L "$0" ] ; then
    DIR="$(dirname "$(readlink -f "$0")")" ;
else
    DIR="$(dirname "$0")" ;
fi

source /usr/local/share/bootstrap/common_functions.sh

# Install composer and npm dependencies
bash "$DIR/../install_magento.sh";

# Default Docker public address
if [ -z "$PUBLIC_ADDRESS" ]; then
    export PUBLIC_ADDRESS=http://magento_web.docker/
fi

set +e
is_hem_project
set -e
IS_HEM=$?
if [ "$IS_HEM" -eq 0 ]; then
  # Run HEM
  export HEM_RUN_ENV="${HEM_RUN_ENV:-local}"
  as_build "hem --non-interactive --skip-host-checks assets download"
fi

# Install assets
export DATABASE_NAME=magentodb
export DATABASE_USER=magento
export DATABASE_PASSWORD=magento
export DATABASE_ROOT_PASSWORD=magento
export DATABASE_HOST=database

bash "$DIR/install_database.sh"

echo "DELETE from core_config_data WHERE path LIKE 'web/%base_url';
DELETE from core_config_data WHERE path LIKE 'system/full_page_cache/varnish%';
INSERT INTO core_config_data VALUES (NULL, 'default', '0', 'web/unsecure/base_url', '$PUBLIC_ADDRESS');
INSERT INTO core_config_data VALUES (NULL, 'default', '0', 'web/secure/base_url', '$PUBLIC_ADDRESS');
INSERT INTO core_config_data VALUES (NULL, 'default', '0', 'system/full_page_cache/varnish/access_list', 'varnish');
INSERT INTO core_config_data VALUES (NULL, 'default', '0', 'system/full_page_cache/varnish/backend_host', 'varnish');
INSERT INTO core_config_data VALUES (NULL, 'default', '0', 'system/full_page_cache/varnish/backend_port', '80');" |  mysql -h$DATABASE_HOST -u$DATABASE_USER -p$DATABASE_PASSWORD $DATABASE_NAME || exit 1

bash "$DIR/install_assets.sh"

if [ -f "$DIR/install_custom.sh" ]; then
  source "$DIR/install_custom.sh"
fi

