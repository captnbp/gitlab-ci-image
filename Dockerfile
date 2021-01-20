FROM golang:1.14 AS tfplantool

ENV BASE="hashicorp/terraform:0.14.1"
ENV TFPLANTOOL="v0.1.0"

WORKDIR /tfplantool

RUN git clone --branch $TFPLANTOOL --depth 1 https://gitlab.com/mattkasa/tfplantool.git .
RUN sed -i -e "/github\.com\/hashicorp\/terraform/s/ v.*\$/ v$(echo "$BASE" | sed -e "s/^.*://")/" go.mod
RUN go get -d -v ./...
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o tfplantool .

FROM    ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive 

COPY	--from=tfplantool /tfplantool/tfplantool /usr/bin/tfplantool

COPY    ./install_tools.sh /usr/local/bin/install_tools.sh

RUN     /usr/local/bin/install_tools.sh
