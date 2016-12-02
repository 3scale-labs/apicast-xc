MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER_PROJECT_PATH := /home/user/app
APICAST_XC_VERSION := $(shell cat apicast_xc.rockspec | grep 'version' | cut -d ' ' -f 3 | tr -d '"')
NAME := xc.lua

.PHONY: default build test bash

default: test

build:
	docker build -t xc.lua .

test: build
	docker run --rm --name $(NAME) xc.lua

bash: build
	docker run --rm --name $(NAME) -it -v $(PROJECT_PATH):$(DOCKER_PROJECT_PATH) xc.lua /bin/bash

apicast.xc:
	cp apicast_xc.rockspec apicast_xc-$(APICAST_XC_VERSION).rockspec
	luarocks make --local apicast_xc-$(APICAST_XC_VERSION).rockspec
	rm apicast_xc-$(APICAST_XC_VERSION).rockspec

clean:
	docker rm --force $(NAME)
