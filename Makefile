THIS_FILE:=$(lastword $(MAKEFILE_LIST))
teamspeak_version:=3.13.6

build:
# Pull prebuilt image from https://hub.docker.com/_/teamspeak
# https://github.com/TeamSpeak-Systems/teamspeak-linux-docker-images/blob/master/alpine/Dockerfile
# You can audit 3.13.6 -> https://hub.docker.com/layers/teamspeak/library/teamspeak/3.13.6/images/sha256-27dc484b08bf1f1dfe6d4c7d381e0ac2ff1fd55832d4f04bd0a4da8cdb9bf9bb?context=explore
	docker pull teamspeak:$(teamspeak_version)

configure: build
# Useful for initial spin-up.
# This will dump the server query admin + admin account credentials to $(pwd)/backup/keys.txt
	@mkdir -p backup
	@id=$(shell docker volume ls --quiet --filter=name=ts3db | wc -l); \
	if [ $$id = 0 ]; then \
		docker run -it -e TS3SERVER_LICENSE=accept --name "ts3-docker-config" \
			--mount type=volume,source=ts3db,destination=/var/ts3server/ \
			--mount type=bind,source="$(shell pwd)/scripts/init.sh",destination=/opt/init.sh \
			--entrypoint="/bin/sh" teamspeak:$(teamspeak_version) /opt/init.sh; \
		docker cp ts3-docker-config:/var/ts3server/keys.txt backup/; \
		docker container rm ts3-docker-config; \
	else \
		echo "ts3db docker volume already exists. If you meant to reconfigure, run make clean first."; \
	fi

run: build
# Run in the foreground, useful for testing.
	docker run --rm -it -e TS3SERVER_LICENSE=accept --name "ts3-docker-run" \
		--mount type=volume,source=ts3db,destination=/var/ts3server/ \
		-p 9987:9987/udp \
		-p 10011:10011/tcp \
		teamspeak:$(teamspeak_version)

deploy: build
	docker run -d -e TS3SERVER_LICENSE=accept --name "ts3-docker-deploy" \
		--restart unless-stopped \
		--mount type=volume,source=ts3db,destination=/var/ts3server/ \
		-p 9987:9987/udp \
		-p 10011:10011/tcp \
		teamspeak:$(teamspeak_version)

stop:
	@ids=$(shell docker container ls --quiet --filter=name=ts3-docker-deploy); \
	if [ -z "$$ids" ]; then \
		echo "No container to stop."; \
	else \
		echo "Stopping container."; \
		docker container stop --time 30 $$ids; \
	fi

sleep: build
# Run in the background for a short period, primarily to gain access to the docker volume.
	docker run --rm -d -e TS3SERVER_LICENSE=accept --name "ts3-docker-sleep" \
		--mount type=volume,source=ts3db,destination=/var/ts3server/ \
		-p 9987:9987/udp \
		-p 10011:10011/tcp \
		--entrypoint="" \
		teamspeak:$(teamspeak_version) /bin/sleep 30

backup: sleep
# This dumps the database + credentials to $(PWD)/backup. 
	@mkdir -p backup
	@docker cp ts3-docker-sleep:/var/ts3server/ts3server.sqlitedb backup/
	@docker cp ts3-docker-sleep:/var/ts3server/keys.txt backup/
	@docker container stop -t 1 ts3-docker-sleep

restore: sleep
# This restores the database file from $(pwd)/backup to the docker volume.
	@docker cp backup/ts3server.sqlitedb ts3-docker-sleep:/var/ts3server/
	@docker cp backup/keys.txt ts3-docker-sleep:/var/ts3server/
	@docker container stop -t 1 ts3-docker-sleep

clean: stop
# This blows everything away including the docker volume and $(pwd)/backup
# Use this wisely.
	@echo "Removing container ts3-docker-deploy"
	@docker container rm -f ts3-docker-deploy 2> /dev/null
	@echo "Removing volume ts3db"
	@docker volume rm -f ts3db > /dev/null
	@echo "Removing image teamspeak:$(teamspeak_version)"
	@docker image rm -f teamspeak:$(teamspeak_version) 2> /dev/null
	@rm -f backup