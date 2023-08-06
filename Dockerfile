FROM    debian:12

ENV     DEBIAN_FRONTEND noninteractive 

COPY    ./install_tools.sh /usr/local/bin/install_tools.sh

RUN     /usr/local/bin/install_tools.sh

COPY    ./trivy-markdown*.tpl /usr/local/share/trivy/templates/