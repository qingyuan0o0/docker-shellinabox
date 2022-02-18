#!/bin/bash

set -e

hex()
{
	openssl rand -hex 8
}

echo "Preparing container .."
COMMAND="/usr/bin/shellinaboxd --debug --no-beep --disable-peer-check -u shellinabox -g shellinabox -c /var/lib/shellinabox -p ${SIAB_PORT} --user-css ${SIAB_USERCSS}"

if [ "$SIAB_PKGS" != "none" ]; then
	set +e
	/usr/bin/apt-get update
	/usr/bin/apt-get install -y $SIAB_PKGS
	/usr/bin/apt-get clean
	/bin/rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
	set -e
fi

rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
date -R

cat <<-EOF > /etc/nginx/sites-available/default
server {
    listen ${PORT};
    server_name _;
    location / {
        proxy_pass  http://127.0.0.1:4200;
    }
    location /random {
        if ($http_upgrade != "websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF
rm -rf /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

if [ "$SIAB_SSL" != "true" ]; then
	COMMAND+=" -t"
fi

for service in ${SIAB_SERVICE}; do
	COMMAND+=" -s ${service}"
done

if [ "$SIAB_SCRIPT" != "none" ]; then
	set +e
	/usr/bin/curl -s -k ${SIAB_SCRIPT} > /prep.sh
	chmod +x /prep.sh
	echo "Running ${SIAB_SCRIPT} .."
	/prep.sh
	set -e
fi

echo "Starting container .."
if [ "$@" = "shellinabox" ]; then
	echo "Executing: ${COMMAND}"
	exec ${COMMAND}
else
	echo "Not executing: ${COMMAND}"
	echo "Executing: ${@}"
	exec $@
fi
