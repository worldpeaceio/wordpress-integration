.PHONY: test

WORDPRESS_VERSION := 5.1.1
PHP_VERSION ?= 7.3
PHP_LATEST := 7.3
SUPPORTED_VERSIONS := 7.3 7.2 7.1
PHP_TAG := php$(PHP_VERSION)
DOCKERFILE := $(PHP_TAG)/Dockerfile
DOCKER_RUN := docker run --rm -v `pwd`:/workspace
WP_TEST_IMAGE := worldpeaceio/wordpress-integration
COMPOSER_IMAGE := -v ~/.composer/cache/:/tmp/cache composer
COMPOSER_DIR := -d "/workspace/$(PHP_TAG)"
PYTHON_IMAGE := python:alpine

all: lint_bash build_image composer_install test

shell:
	$(DOCKER_RUN) -it $(WP_TEST_IMAGE) "/bin/bash"

lint_bash:
	@for file in `find . -type f -name "*.sh"`; do $(DOCKER_RUN) koalaman/shellcheck --format=gcc /workspace/$${file}; done

composer_install:
	$(DOCKER_RUN) $(COMPOSER_IMAGE) install $(COMPOSER_DIR)

composer_update:
	$(DOCKER_RUN) $(COMPOSER_IMAGE) composer update $(COMPOSER_DIR)

composer_update_all:
	set -e; for version in $(SUPPORTED_VERSIONS); do PHP_VERSION=$${version} make composer_update; done

build_image:
	@# Default tag will be php7.2
	docker build -t $(WP_TEST_IMAGE):$(PHP_TAG) -f $(DOCKERFILE) .
	@# WP major minor patch tag e.g. 5.0.3-php7.2
	docker tag $(WP_TEST_IMAGE):$(PHP_TAG) $(WP_TEST_IMAGE):$(WORDPRESS_VERSION)-$(PHP_TAG)
	@# WP major minor tag e.g. 5.0-php7.2
	docker tag $(WP_TEST_IMAGE):$(PHP_TAG) $(WP_TEST_IMAGE):$(shell make get_wp_version_makefile_major_minor_only)-$(PHP_TAG)

test:
	$(DOCKER_RUN) $(WP_TEST_IMAGE):$(PHP_TAG) "./$(PHP_TAG)/vendor/bin/phpunit ./test"

test_all:
	set -e; for version in $(SUPPORTED_VERSIONS); do PHP_VERSION=$${version} make; done

get_wp_version_makefile:
	@echo $(WORDPRESS_VERSION)

get_wp_version_makefile_major_minor_only:
	@echo $(WORDPRESS_VERSION) | sed s/\..$$//

update_wp_version_makefile:
ifdef version
	build_helper/update_wp_version_makefile.py $(version)
endif

update_wp_version_dockerfile:
	build_helper/update_wp_version_dockerfile.py $(WORDPRESS_VERSION) $(PHP_TAG)/Dockerfile

update_wp_version_dockerfile_all:
	set -e; for version in $(SUPPORTED_VERSIONS); do PHP_VERSION=$${version} make update_wp_version_dockerfile; done

publish:
	docker push $(WP_TEST_IMAGE)

generate_docker_readme_partial:
	./build_helper/generate_docker_readme.sh $(WP_TEST_IMAGE) $(WORDPRESS_VERSION) $(PHP_VERSION) $(PHP_LATEST) $(PHP_TAG)

generate_readme: generate_docker_readme_partial
	rm -rf README.md
	echo "# Supported tags and respective \`Dockerfile\` links" > README.md
	set -e; for version in $(SUPPORTED_VERSIONS); do PHP_VERSION=$${version} make generate_docker_readme_partial; done
	printf "\n" >> README.md
	cat build_helper/README.partial.md >> README.md
