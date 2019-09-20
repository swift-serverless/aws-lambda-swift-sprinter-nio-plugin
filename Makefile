SWIFT_DOCKER_IMAGE=swift:latest
SWIFT_PACKAGE=aws-lambda-swift-sprinter-nio-plugin
MOUNT_ROOT="$(shell pwd)/.."

swift_test:
	docker run \
			--rm \
			--volume "$(MOUNT_ROOT):/src" \
			--workdir "/src" \
			$(SWIFT_DOCKER_IMAGE) \
			/bin/bash -c "cd $(SWIFT_PACKAGE); swift test"