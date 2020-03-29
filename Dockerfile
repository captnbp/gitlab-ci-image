FROM    ubuntu:18.04

COPY    ./install_tools.sh /usr/local/bin/install_tools.sh

RUN     /usr/local/bin/install_tools.sh