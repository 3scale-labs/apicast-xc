MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
DOCKER_PROJECT_PATH := /home/user/app
NAME := apicast-xc

.PHONY: default build test bash

default: test

build:
	docker build -t apicast-xc .

test: build
	docker run --rm --name $(NAME) apicast-xc

bash: build
	docker run --rm --name $(NAME) -it -v $(PROJECT_PATH):$(DOCKER_PROJECT_PATH) apicast-xc /bin/bash

clean:
	docker rm --force $(NAME)
