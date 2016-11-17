MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER_PROJECT_PATH := /home/user/app
APICAST_XC_VERSION := $(shell cat apicast_xc.rockspec | grep 'version' | cut -d ' ' -f 3 | tr -d '"')
NAME := apicast-xc

.PHONY: default build test bash

default: test

build:
	docker build -t apicast-xc .

test: build
	docker run --rm --name $(NAME) apicast-xc

bash: build
	docker run --rm --name $(NAME) -it -v $(PROJECT_PATH):$(DOCKER_PROJECT_PATH) apicast-xc /bin/bash

apicast.xc:
	cp apicast_xc.rockspec apicast_xc-$(APICAST_XC_VERSION).rockspec
	luarocks make --local apicast_xc-$(APICAST_XC_VERSION).rockspec
	rm apicast_xc-$(APICAST_XC_VERSION).rockspec

clean:
	docker rm --force $(NAME)
