#!/bin/bash

function main {
    if [ "$1" != "nginx" ]; then
        args=$(getopt -n "$(basename $0)" -o h --long help,debug,version -- "$@")
        eval set --"$args"
        while true; do
            case "$1" in
                -h | --help ) print_usage; shift ;;
                --debug ) DEBUG=true; shift ;;
                --version ) print_version; shift ;;
                --) shift ; break ;;
                * ) break ;;
            esac
        done
        shift $((OPTIND-1))
        nginx_config
	for arg; do
            VHOST=${arg//:/ }
            if [ ! -f /etc/nginx/sites-available/$VHOST ]; then
                vhost_config "$VHOST"
		ln -sf /etc/nginx/sites-available/$VHOST /etc/nginx/sites-enabled/$VHOST
            fi
            if [ ! -d /var/www/$VHOST ]; then
                mkdir -m 755 -p /var/www/$VHOST/{cgi-bin,htdocs,logs,tmp}
		cp -pr /usr/share/nginx/html/* /var/www/$VHOST/htdocs/
                chown -R www-data:www-data /var/www/$VHOST/{cgi-bin,htdocs,tmp}
            fi
            touch /var/www/$VHOST/logs/php.log
            chown -R www-data:www-data /var/www/$VHOST/logs/php.log
        done
        exec nginx -g 'daemon off;'
    else
        nginx_config
        exec "$@"
    fi
}

function print_usage {
cat << EOF
Usage: "$(basename $0)" [Options]... [Vhosts]...

  -h  --help     display this help and exit

      --debug    output debug information
      --version  output version information and exit

E-mail bug reports to: <developer@wilke.systems>.
EOF
exit
}

function print_version {
cat << EOF

MIT License

Copyright (c) 2017 Wilke.Systems

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF
exit
}

function vhost_config {
cat << EOF > /etc/nginx/conf.d/upstream.conf
upstream fcgiwrap {
	server unix:/run/fcgiwrap/fcgiwrap.socket;
}
upstream php5 {
	server unix:/run/php5/php5-fpm.sock;
}
upstream php7 {
	server unix:/run/php7/php7.0-fpm.sock;
}
EOF
HTTP_STATUS_CODES=(
    400 "Bad Request"
    401 "Unauthorized"
    402 "Payment Required"
    403 "Forbidden"
    404 "Not Found"
    405 "Method Not Allowed"
    406 "Not Acceptable"
    407 "Proxy Authentication Required"
    408 "Request Timeout"
    409 "Conflict"
    410 "Gone"
    411 "Length Required"
    412 "Precondition Failed"
    413 "Payload Too Large"
    414 "URI Too Long"
    415 "Unsupported Media Type"
    416 "Range Not Satisfiable"
    417 "Expectation Failed"
    418 "I'm a teapot"
    421 "Misdirected Request"
    422 "Unprocessable Entity"
    423 "Locked"
    424 "Failed Dependency"
    426 "Upgrade Required"
    428 "Precondition Required"
    429 "Too Many Requests"
    431 "Request Header Fields Too Large"
    444 "No Response"
    451 "Unavailable For Legal Reasons"
    495 "SSL Certificate Error"
    496 "SSL Certificate Required"
    497 "HTTP Request Sent to HTTPS Port"
    500 "Internal Server Error"
    501 "Not Implemented"
    502 "Bad Gateway"
    503 "Service Unavailable"
    504 "Gateway Timeout"
    505 "HTTP Version Not Supported"
    506 "Variant Also Negotiates"
    507 "Insufficient Storage"
    508 "Loop Detected"
    509 "Bandwidth Limit Exceeded"
    510 "Not Extended"
    511 "Network Authentication Required"
)
COUNT=0
echo "# Error Pages" > /etc/nginx/snippets/error.conf
while [ "x${HTTP_STATUS_CODES[COUNT]}" != "x" ]
do
   echo "error_page ${HTTP_STATUS_CODES[COUNT]} /error/${HTTP_STATUS_CODES[COUNT]}/index.html;" >> /etc/nginx/snippets/error.conf
   if [ ! -d /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]} ]; then
       mkdir -p /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]}
       echo "<html>" > /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]}/index.html
       echo "<head><title>${HTTP_STATUS_CODES[COUNT]} ${HTTP_STATUS_CODES[COUNT+1]}</title></head>" >> /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]}/index.html
       echo "<body bgcolor=\"white\">" >> /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]}/index.html
       echo "<center><h1>${HTTP_STATUS_CODES[COUNT]} ${HTTP_STATUS_CODES[COUNT+1]}</h1></center>" >> /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]}/index.html
       echo "<hr><center>$NGINX_SERVER</center>" >> /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]}/index.html
       echo "</body>" >> /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]}/index.html
       echo "</html>" >> /usr/share/nginx/error/${HTTP_STATUS_CODES[COUNT]}/index.html
   fi
   COUNT=$(($COUNT+2))
done
cat << EOF >> /etc/nginx/snippets/error.conf

location ^~ /error/ {
	internal;
	root /usr/share/nginx;
}
EOF
cat << EOF > /etc/nginx/snippets/letsencrypt-acme-challenge.conf
location ^~ /.well-known/acme-challenge/ {
	default_type "text/plain";
	root /var/www/default;
	allow all;
}
location = /.well-known/acme-challenge/ {
	return 404;
}
EOF
cat << EOF > /etc/nginx/snippets/autoconfig.conf
location ^~ /.well-known/autoconfig {
	root /var/www/default;
	index index.php;
	try_files \$uri \$uri/ /autoconfig/index.php?\$args;
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass php7;
	}
	allow all;
}
location ~* ^/autoconfig {
	root /var/www/default;
	index index.php;
	try_files \$uri \$uri/ /autoconfig/index.php?\$args;
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass php7;
	}
}
EOF
cat << EOF > /etc/nginx/snippets/autodiscover.conf
location ~* ^/autodiscover {
	root /var/www/default;
	index index.php;
	try_files \$uri \$uri/ /autodiscover/index.php?\$args;
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass php7;
	}
}
EOF
cat << EOF > /etc/nginx/snippets/phpmyadmin.conf
location /phpmyadmin {
	root /var/www/default;
	index index.php;
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass php7;
	}
}
EOF
cat << EOF > /etc/nginx/sites-available/$1
server {
	listen 80;
	listen [::]:80;

	server_name $1 *.$1;

	root /var/www/$1/htdocs;
	index default.html index.php index.php5 index.php7 index.html index.htm;

	include snippets/error.conf;
	include snippets/autoconfig.conf;
	include snippets/autodiscover.conf;
	include snippets/letsencrypt-acme-challenge.conf;

	location / {
		try_files \$uri \$uri/ =404;
	}

	location /cgi-bin {
		root /var/www/$1;
		index index.html index.htm index.cgi index.pl index.sh;
	 	location ~ \.(cgi|pl|sh)$ {
			gzip off;
			include /etc/nginx/fastcgi.conf;
			fastcgi_pass fcgiwrap;
	 	}
	}

	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_param PHP_VALUE "error_log=/var/www/$1/logs/php.log;";
 		fastcgi_pass php7;
	}

	location ~ \.php5$ {
		include snippets/fastcgi-php.conf;
		fastcgi_param PHP_VALUE "error_log=/var/www/$1/logs/php.log;";
		fastcgi_pass php5;
	}

	location ~ \.php7$ {
		include snippets/fastcgi-php.conf;
		fastcgi_param PHP_VALUE "error_log=/var/www/$1/logs/php.log;";
 		fastcgi_pass php7;
	}


	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;
}
EOF
if [ -f /etc/letsencrypt/live/$1/cert.pem ]; then
cat << EOF > /etc/nginx/sites-available/$1
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	server_name www.$1;

	client_max_body_size 0;

	root /var/www/$1/htdocs;
	index default.html index.php index.php5 index.php7 index.html index.htm;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

	add_header Strict-Transport-Security max-age=15768000;

	include snippets/error.conf;
	include snippets/autoconfig.conf;
	include snippets/autodiscover.conf;
	include snippets/letsencrypt-acme-challenge.conf;

	location / {
		try_files \$uri \$uri/ =404;
	}

	location /cgi-bin {
		root /var/www/$1;
		index index.html index.htm index.cgi index.pl index.sh;
		location ~ \.(cgi|pl|sh)$ {
			gzip off;
			include /etc/nginx/fastcgi.conf;
			fastcgi_pass fcgiwrap;
		}
	}

	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_param PHP_VALUE "error_log=/var/www/$1/logs/php.log;";
		fastcgi_pass php7;
	}

	location ~ \.php5$ {
		include snippets/fastcgi-php.conf;
		fastcgi_param PHP_VALUE "error_log=/var/www/$1/logs/php.log;";
		fastcgi_pass php5;
	}

	location ~ \.php7$ {
		include snippets/fastcgi-php.conf;
		fastcgi_param PHP_VALUE "error_log=/var/www/$1/logs/php.log;";
		fastcgi_pass php7;
	}

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;
}

server {
	listen 80;
	listen [::]:80;

	server_name $1 *.$1;

	root /var/www/default;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	return 301 https://www.$1\$request_uri;
}

server {
	listen 443;
	listen [::]:443;

	server_name $1 *.$1;

	root /var/www/default;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

        add_header Strict-Transport-Security max-age=15768000;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	return 301 https://www.$1\$request_uri;
}
EOF
fi
if [ -f /etc/letsencrypt/live/$1/cert.pem -a -d /var/www/$1/htdocs/fileadmin -a -d /var/www/$1/htdocs/typo3conf ]; then
cat << EOF > /etc/nginx/sites-available/$1
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	server_name www.$1;

	client_max_body_size 0;

	disable_symlinks off;

	root /var/www/$1/htdocs;
	index index.php;

 	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

        add_header Strict-Transport-Security max-age=15768000;

	include snippets/autoconfig.conf;
	include snippets/autodiscover.conf;
	include snippets/letsencrypt-acme-challenge.conf;

        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }

        location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
        }

        location / {
                try_files \$uri \$uri/ /index.php?\$args;
        }

        location /typo3_src {
                deny all;
        }

        location /typo3temp/logs {
                deny all;
        }

        location ~* ^/fileadmin/(.*/)?_recycler_/ {
                deny all;
        }

        location ~* ^/fileadmin/templates/.*(\.txt|\.ts)$ {
                deny all;
        }

        location ~* ^/typo3conf/ext/[^/]+/Resources/Private/ {
                deny all;
        }

        location ~ /\. {
                deny all;
                access_log off;
                log_not_found off;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_intercept_errors on;
                fastcgi_pass php7;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
                expires max;
                log_not_found off;
        }

        access_log /var/www/$1/logs/access.log;
        error_log /var/www/$1/logs/error.log warn;
}

server {
	listen 80;
	listen [::]:80;

	server_name $1 *.$1;

	root /var/www/default;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	return 301 https://www.$1\$request_uri;
}

server {
	listen 443;
	listen [::]:443;

	server_name $1 *.$1;

	root /var/www/default;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

        add_header Strict-Transport-Security max-age=15768000;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	return 301 https://www.$1\$request_uri;
}

EOF
fi
if [ -f /etc/letsencrypt/live/$1/cert.pem -a -f /var/www/$1/htdocs/bin/magento -a -d /var/www/$1/htdocs/pub/opt/magento ]; then
cat << EOF > /etc/nginx/sites-available/$1
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	server_name www.$1;

	root /var/www/$1/htdocs/pub;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

        add_header Strict-Transport-Security max-age=15768000;

	include snippets/autoconfig.conf;
	include snippets/autodiscover.conf;
	include snippets/letsencrypt-acme-challenge.conf;

	index index.php;
	autoindex off;
	charset UTF-8;
	error_page 404 403 = /errors/404.php;
	#add_header "X-UA-Compatible" "IE=Edge";

	# PHP entry point for setup application
	location ~* ^/setup(\$|/) {
		root /var/www/$1/htdocs;
		location ~ ^/setup/index.php {
			fastcgi_pass   php7;

			fastcgi_param  PHP_FLAG  "session.auto_start=off \\n suhosin.session.cryptua=off";
			fastcgi_param  PHP_VALUE "memory_limit=768M \\n max_execution_time=600";
			fastcgi_read_timeout 600s;
			fastcgi_connect_timeout 600s;

			fastcgi_index  index.php;
			fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
			include        fastcgi_params;
		}

		location ~ ^/setup/(?!pub/). {
			deny all;
		}

		location ~ ^/setup/pub/ {
			add_header X-Frame-Options "SAMEORIGIN";
		}
	}

	# PHP entry point for update application
	location ~* ^/update(\$|/) {
		root /var/www/$1/htdocs;

		location ~ ^/update/index.php {
			fastcgi_split_path_info ^(/update/index.php)(/.+)\$;
			fastcgi_pass   php7;
			fastcgi_index  index.php;
			fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
			fastcgi_param  PATH_INFO        \$fastcgi_path_info;
			include        fastcgi_params;
		}

		# Deny everything but index.php
		location ~ ^/update/(?!pub/). {
			deny all;
		}

		location ~ ^/update/pub/ {
			add_header X-Frame-Options "SAMEORIGIN";
		}
	}

	location / {
		try_files \$uri \$uri/ /index.php\$is_args\$args;
	}

	location /pub/ {
		location ~ ^/pub/media/(downloadable|customer|import|theme_customization/.*\.xml) {
			deny all;
		}
		alias /var/www/$1/htdocs/pub/;
		add_header X-Frame-Options "SAMEORIGIN";
	}

	location /static/ {
		# Uncomment the following line in production mode
		# expires max;

		# Remove signature of the static files that is used to overcome the browser cache
		location ~ ^/static/version {
			rewrite ^/static/(version\d*/)?(.*)\$ /static/\$2 last;
		}

		location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)\$ {
			add_header Cache-Control "public";
			add_header X-Frame-Options "SAMEORIGIN";
			expires +1y;

			if (!-f \$request_filename) {
				rewrite ^/static/?(.*)\$ /static.php?resource=\$1 last;
			}
		}
		location ~* \.(zip|gz|gzip|bz2|csv|xml)\$ {
			add_header Cache-Control "no-store";
			add_header X-Frame-Options "SAMEORIGIN";
			expires    off;

			if (!-f \$request_filename) {
				rewrite ^/static/?(.*)\$ /static.php?resource=\$1 last;
			}
		}
		if (!-f \$request_filename) {
			rewrite ^/static/?(.*)\$ /static.php?resource=\$1 last;
		}
		add_header X-Frame-Options "SAMEORIGIN";
	}

	location /media/ {
		try_files \$uri \$uri/ /get.php\$is_args\$args;

		location ~ ^/media/theme_customization/.*\.xml {
			deny all;
		}

		location ~* \.(ico|jpg|jpeg|png|gif|svg|js|css|swf|eot|ttf|otf|woff|woff2)\$ {
			add_header Cache-Control "public";
			add_header X-Frame-Options "SAMEORIGIN";
			expires +1y;
			try_files \$uri \$uri/ /get.php\$is_args\$args;
		}
		location ~* \.(zip|gz|gzip|bz2|csv|xml)\$ {
			add_header Cache-Control "no-store";
			add_header X-Frame-Options "SAMEORIGIN";
			expires    off;
			try_files \$uri \$uri/ /get.php\$is_args\$args;
		}
		add_header X-Frame-Options "SAMEORIGIN";
	}

	location /media/customer/ {
		deny all;
	}

	location /media/downloadable/ {
		deny all;
	}

	location /media/import/ {
		deny all;
	}

	# PHP entry point for main application
	location ~ (index|get|static|report|404|503)\.php\$ {
		try_files \$uri =404;
		fastcgi_pass   php7;
		fastcgi_buffers 1024 4k;

		fastcgi_param  PHP_FLAG  "session.auto_start=off \\n suhosin.session.cryptua=off";
		fastcgi_param  PHP_VALUE "memory_limit=768M \\n max_execution_time=18000";
		fastcgi_read_timeout 600s;
		fastcgi_connect_timeout 600s;

		fastcgi_index  index.php;
		fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
		include        fastcgi_params;
	}

	gzip on;
	gzip_disable "msie6";

	gzip_comp_level 6;
	gzip_min_length 1100;
	gzip_buffers 16 8k;
	gzip_proxied any;
	gzip_types
	    text/plain
	    text/css
	    text/js
	    text/xml
	    text/javascript
	    application/javascript
	    application/x-javascript
	    application/json
	    application/xml
	    application/xml+rss
	    image/svg+xml;
	gzip_vary on;

	# Banned locations (only reached if the earlier PHP entry point regexes don't match)
	location ~* (\.php\$|\.htaccess\$|\.git) {
		deny all;
	}

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;
}

server {
	listen 80;
	listen [::]:80;

	server_name $1 *.$1;

	root /var/www/default;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	return 301 https://www.$1\$request_uri;
}

server {
	listen 443;
	listen [::]:443;

	server_name $1 *.$1;

	root /var/www/default;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

        add_header Strict-Transport-Security max-age=15768000;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	return 301 https://www.$1\$request_uri;
}

EOF
fi
if [ -f /etc/letsencrypt/live/$1/cert.pem -a -f /var/www/$1/htdocs/wp-config.php -a -d /var/www/$1/htdocs/wp-admin ]; then
cat << EOF > /etc/nginx/sites-available/$1
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;

	server_name www.$1;

	client_max_body_size 0;

	root /var/www/$1/htdocs;
	index index.php;

        ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

        add_header Strict-Transport-Security max-age=15768000;

	include snippets/autoconfig.conf;
	include snippets/autodiscover.conf;
	include snippets/letsencrypt-acme-challenge.conf;

        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }

        location = /robots.txt {
                allow all;
                log_not_found off;
                access_log off;
        }

        location / {
                try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_intercept_errors on;
                fastcgi_pass php7;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
                expires max;
                log_not_found off;
        }

	location ~ ([^/]*)sitemap(.*).x(m|s)l$ {
		rewrite ^/sitemap.xml$ /sitemap_index.xml permanent;
		rewrite ^/([a-z]+)?-?sitemap.xsl$ /index.php?xsl=\$1 last;
		rewrite ^/sitemap_index.xml$ /index.php?sitemap=1 last;
		rewrite ^/([^/]+?)-sitemap([0-9]+)?.xml$ /index.php?sitemap=\$1&sitemap_n=\$2 last;
		rewrite ^/news-sitemap.xml$ /index.php?sitemap=wpseo_news last;
		rewrite ^/locations.kml$ /index.php?sitemap=wpseo_local_kml last;
		rewrite ^/geo-sitemap.xml$ /index.php?sitemap=wpseo_local last;
		rewrite ^/video-sitemap.xsl$ /index.php?xsl=video last;
	}

        access_log /var/www/$1/logs/access.log;
        error_log /var/www/$1/logs/error.log warn;
}

server {
	listen 80;
	listen [::]:80;

	server_name $1 *.$1;

	root /var/www/default;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	return 301 https://www.$1\$request_uri;
}

server {
	listen 443;
	listen [::]:443;

	server_name $1 *.$1;

	root /var/www/default;

	ssl_certificate /etc/letsencrypt/live/$1/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$1/privkey.pem;

        add_header Strict-Transport-Security max-age=15768000;

	rewrite_log on;

	access_log /var/www/$1/logs/access.log;
	error_log /var/www/$1/logs/error.log warn;

	return 301 https://www.$1\$request_uri;
}
EOF
fi
}

function nginx_config {
    [ "$DEBUG" = "true" ] && set -x

    # openssl dhparam -outform PEM -2|-5 1024|1536|2048|3072|4096|6144|7680|8192 >> /etc/nginx/dhparams.pem

    if [ ! -z "$NGINX_DEFAULT_ROOT" -a "$NGINX_DEFAULT_ROOT" != "/var/www/html" ]; then
        if [ -f /etc/nginx/sites-available/default ]; then
            sed -i -e "s/root \(.*\);/root ${NGINX_DEFAULT_ROOT////\\/};/" /etc/nginx/sites-available/default
            mkdir -m 755 -p $NGINX_DEFAULT_ROOT
            if [ -f /usr/share/nginx/html/index.html ]; then
                if [ ! -f $NGINX_DEFAULT_ROOT/index.nginx-debian.html -a ! -f $NGINX_DEFAULT_ROOT/index.html ]; then
                    cp -p /usr/share/nginx/html/index.html "$NGINX_DEFAULT_ROOT/index.nginx-debian.html"
                fi
            fi
        fi
        if [ -d /var/www/html ]; then
            rm -rf /var/www/html
        fi
    fi

    if [ ! -z "$NGINX_GZIP" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip \(.*\);/gzip \1;/" -e "s/gzip \(.*\);/gzip ${NGINX_GZIP,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_DISABLE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_disable \(.*\);/gzip_disable \1;/" -e "s/gzip_disable \(.*\);/gzip_disable ${NGINX_GZIP_DISABLE,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_VARY" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_vary \(.*\);/gzip_vary \1;/" -e "s/gzip_vary \(.*\);/gzip_vary ${NGINX_GZIP_VARY,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_PROXIED" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_proxied \(.*\);/gzip_proxied \1;/" -e "s/gzip_proxied \(.*\);/gzip_proxied ${NGINX_GZIP_PROXIED,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_COMP_LEVEL" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_comp_level \(.*\);/gzip_comp_level \1;/" -e "s/gzip_comp_level \(.*\);/gzip_comp_level ${NGINX_GZIP_COMP_LEVEL,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_BUFFERS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_buffers \(.*\);/gzip_buffers \1;/" -e "s/gzip_buffers \(.*\);/gzip_buffers ${NGINX_GZIP_BUFFERS,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_HTTP_VERSION" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_http_version \(.*\);/gzip_http_version \1;/" -e "s/gzip_http_version \(.*\);/gzip_http_version ${NGINX_GZIP_HTTP_VERSION,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GZIP_TYPES" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# gzip_types \(.*\);/gzip_types \1;/" -e "s/gzip_types \(.*\);/gzip_types ${NGINX_GZIP_TYPES////\\/};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_KEEPALIVE_TIMEOUT" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# keepalive_timeout \(.*\);/keepalive_timeout \1;/" -e "s/keepalive_timeout \(.*\);/keepalive_timeout $NGINX_KEEPALIVE_TIMEOUT;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_MULTI_ACCEPT" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# multi_accept \(.*\);/multi_accept \1;/" -e "s/multi_accept \(.*\);/multi_accept ${NGINX_MULTI_ACCEPT,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_PID" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# pid \(.*\);/pid \1;/" -e "s/pid \(.*\);/pid ${NGINX_PID////\\/};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_GID" -a -z "${NGINX_GID//[0-9]/}" -a "$NGINX_GID" != "$(id --group www-data)" ]; then
        groupmod -g $NGINX_GID www-data
    fi

    if [ ! -z "$NGINX_UID" -a -z "${NGINX_UID//[0-9]/}" -a "$NGINX_UID" != "$(id --user www-data)" ]; then
        usermod -u $NGINX_UID www-data
    fi

    if [ ! -z "$NGINX_SENDFILE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# sendfile \(.*\);/sendfile \1;/" -e "s/sendfile \(.*\);/sendfile ${NGINX_SENDFILE,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SERVER" ]; then
        echo "more_set_headers 'Server: $NGINX_SERVER';" > /etc/nginx/conf.d/more_set_headers.conf
    fi

    if [ ! -z "$NGINX_SERVER_NAME_IN_REDIRECT" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# server_name_in_redirect \(.*\);/server_name_in_redirect \1;/" -e "s/server_name_in_redirect \(.*\);/server_name_in_redirect ${NGINX_SERVER_NAME_IN_REDIRECT,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SERVER_NAMES_HASH_BUCKET_SIZE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# server_names_hash_bucket_size \(.*\);/server_names_hash_bucket_size \1;/" -e "s/server_names_hash_bucket_size \(.*\);/server_names_hash_bucket_size $NGINX_SERVER_NAMES_HASH_BUCKET_SIZE;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SERVER_NAMES_HASH_MAX_SIZE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "server_names_hash_max_size " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/server_names_hash_bucket_size \(.*\);/server_names_hash_bucket_size \1;\n\tserver_names_hash_max_size $NGINX_SERVER_NAMES_HASH_MAX_SIZE;/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/server_names_hash_max_size \(.*\);/server_names_hash_max_size ${NGINX_SERVER_NAMES_HASH_MAX_SIZE};/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SERVER_TOKENS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# server_tokens \(.*\);/server_tokens \1;/" -e "s/server_tokens \(.*\);/server_tokens ${NGINX_SERVER_TOKENS,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_SSL_PREFER_SERVER_CIPHERS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;/" -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers ${NGINX_SSL_PREFER_SERVER_CIPHERS,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_RESOLVER_TIMEOUT" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "resolver_timeout " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tresolver_timeout \"$NGINX_RESOLVER_TIMEOUT\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/resolver_timeout \(.*\);/resolver_timeout \"${NGINX_RESOLVER_TIMEOUT}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_RESOLVER" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "resolver " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tresolver \"$NGINX_RESOLVER\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/resolver \(.*\);/resolver \"${NGINX_RESOLVER}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_STAPLING_VERIFY" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_stapling_verify " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_stapling_verify $NGINX_SSL_STAPLING_VERIFY;/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_stapling_verify \(.*\);/ssl_stapling_verify ${NGINX_SSL_STAPLING_VERIFY};/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_STAPLING" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_stapling " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_stapling $NGINX_SSL_STAPLING;/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_stapling \(.*\);/ssl_stapling ${NGINX_SSL_STAPLING};/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_SESSION_TICKETS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_session_tickets " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_session_tickets $NGINX_SSL_SESSION_TICKETS;/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_session_tickets \(.*\);/ssl_session_tickets ${NGINX_SSL_SESSION_TICKETS};/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_SESSION_CACHE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_session_cache " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_session_cache \"$NGINX_SSL_SESSION_CACHE\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_session_cache \(.*\);/ssl_session_cache \"${NGINX_SSL_SESSION_CACHE}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_SESSION_TIMEOUT" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_session_timeout " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_session_timeout $NGINX_SSL_SESSION_TIMEOUT;/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_session_timeout \(.*\);/ssl_session_timeout ${NGINX_SSL_SESSION_TIMEOUT};/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_DHPARAM" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_dhparam " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_dhparam \"${NGINX_SSL_DHPARAM////\\/}\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_dhparam \(.*\);/ssl_dhparam \"${NGINX_SSL_DHPARAM////\\/}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_ECDH_CURVE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_ecdh_curve " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_ecdh_curve \"$NGINX_SSL_ECDH_CURVE\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_ecdh_curve \(.*\);/ssl_ecdh_curve \"${NGINX_SSL_ECDH_CURVE}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_CIPHERS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_ciphers " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_ciphers \"$NGINX_SSL_CIPHERS\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_ciphers \(.*\);/ssl_ciphers \"${NGINX_SSL_CIPHERS}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_TRUSTED_CERTIFICATE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_trusted_certificate " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_trusted_certificate \"${NGINX_SSL_TRUSTED_CERTIFICATE////\\/}\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_trusted_certificate \(.*\);/ssl_trusted_certificate \"${NGINX_SSL_TRUSTED_CERTIFICATE////\\/}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_CERTIFICATE_KEY" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_certificate_key " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_certificate_key \"${NGINX_SSL_CERTIFICATE_KEY////\\/}\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_certificate_key \(.*\);/ssl_certificate_key \"${NGINX_SSL_CERTIFICATE_KEY////\\/}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_CERTIFICATE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            if [ $(grep -c "ssl_certificate " /etc/nginx/nginx.conf) -eq 0 ]; then
                sed -i -e "s/ssl_prefer_server_ciphers \(.*\);/ssl_prefer_server_ciphers \1;\n\tssl_certificate \"${NGINX_SSL_CERTIFICATE////\\/}\";/" /etc/nginx/nginx.conf
            else
                sed -i -e "s/ssl_certificate \(.*\);/ssl_certificate \"${NGINX_SSL_CERTIFICATE////\\/}\";/" /etc/nginx/nginx.conf
            fi
        fi
    fi

    if [ ! -z "$NGINX_SSL_PROTOCOLS" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# ssl_protocols \(.*\);/ssl_protocols \1;/" -e "s/ssl_protocols \(.*\);/ssl_protocols $NGINX_SSL_PROTOCOLS;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_TCP_NODELAY" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# tcp_nodelay \(.*\);/tcp_nodelay \1;/" -e "s/tcp_nodelay \(.*\);/tcp_nodelay ${NGINX_TCP_NODELAY,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_TCP_NOPUSH" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# tcp_nopush \(.*\);/tcp_nopush \1;/" -e "s/tcp_nopush \(.*\);/tcp_nopush ${NGINX_TCP_NOPUSH,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_TYPES_HASH_MAX_SIZE" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# types_hash_max_size \(.*\);/types_hash_max_size \1;/" -e "s/types_hash_max_size \(.*\);/types_hash_max_size $NGINX_TYPES_HASH_MAX_SIZE;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_USER" ]; then
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# user \(.*\);/user \1;/" -e "s/user \(.*\);/user ${NGINX_USER,,};/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_WORKER_CONNECTIONS" ]; then
        if [ ! -z "${NGINX_WORKER_CONNECTIONS//[0-9]/}" ]; then
            NGINX_WORKER_CONNECTIONS=$((65535/$(grep processor /proc/cpuinfo | wc -l)))
        fi
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# worker_connections \(.*\);/worker_connections \1;/" -e "s/worker_connections \(.*\);/worker_connections $NGINX_WORKER_CONNECTIONS;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ ! -z "$NGINX_WORKER_PROCESSES" ]; then
        if [ ! -z "${NGINX_WORKER_PROCESSES//[0-9]/}" ]; then
            WORKER_PROCESSES=auto
        fi
        if [ -f /etc/nginx/nginx.conf ]; then
            sed -i -e "s/# worker_processes \(.*\);/worker_processes \1;/" -e "s/worker_processes \(.*\);/worker_processes $NGINX_WORKER_PROCESSES;/" /etc/nginx/nginx.conf
        fi
    fi

    if [ -f /etc/nginx/sites-available/default ]; then
        sed -i -e "s/# listen 443 ssl default_server;/listen 443 ssl default_server http2;/" /etc/nginx/sites-available/default;
        sed -i -e "s/# listen \[::\]:443 ssl default_server;/listen [::]:443 ssl default_server http2;/" /etc/nginx/sites-available/default
        sed -i -e "s/# include snippets\/snakeoil.conf;/include snippets\/snakeoil.conf;/" /etc/nginx/sites-available/default
    fi

    if [ -d /etc/docker-entrypoint.d ]; then
        for NGINX_PACKAGE in /etc/docker-entrypoint.d/*.tar.gz; do
            tar xfz $NGINX_PACKAGE -C /
        done
    fi
}

main "$@"
