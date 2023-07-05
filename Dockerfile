FROM    ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive 

COPY    ./install_tools.sh /usr/local/bin/install_tools.sh

RUN     /usr/local/bin/install_tools.sh
