# NOTE: I've used as guidelines for Makefile following pages:
# * https://dev.to/flpslv/using-makefiles-to-build-and-publish-docker-containers-7c8
# * https://jmkhael.io/makefiles-for-your-dockerfiles/

#Import environment
$(shell test ! -e default_env && echo "" > default_env)
include default_env
env       ?= default

$(shell test ! -e make_env-$(env) && echo "" > make_env-$(env))
include make_env-$(env)

#Dockerfile vars
target    ?= vivado
version   ?= 2020.1
suffix    ?= -$(env)
base      ?= ubuntu
base_ver  ?= 18.04
distr_libs?= "libx11-6"
add_apps  ?= ""
# NOTE: Borrowed GUI libs list from https://github.com/phwl/docker-vivado for add_apps in make_env-default
distr_data?= Distribs/Xilinx_Unified_2020.1_0602_1208
workspace = $(target)-$(version)$(suffix)
user_id   = $(shell id -u)

#Make vars
IMAGENAME =  $(target)
REPO      =  godhart

DISTRFULLNAME=$(REPO)/$(IMAGENAME)-distr-$(base)-$(base_ver):$(version)
CONFFULLNAME=$(REPO)/$(IMAGENAME)$(suffix)-conf:$(version)
INSTALLFULLNAME=$(REPO)/$(IMAGENAME)$(suffix)-install:$(version)
IMAGEFULLNAME=$(REPO)/$(IMAGENAME)$(suffix):$(version)

DISTR_DATA=  $(distr_data)
WORKSPACE =  $(workspace)

IMPORT_PATH = $(WORKSPACE)/$(WORKSPACE).tar 

.PHONY: debug help distr conf install image all tar import prune clean clean_all \
	default_env \
	version test_sim test_synth simulate bitstream \
	bash tcl gui \
	check_conf check_license

.DEFAULT_GOAL := image

all: distr conf image

debug:
	@echo "env             = $(env)"
	@echo "  -- Docker vars --"
	@echo "target          = $(target)"
	@echo "version         = $(version)"
	@echo "suffix          = $(suffix)"
	@echo "base            = $(base)"
	@echo "base_ver        = $(base_ver)"
	@echo "distr_libs      = $(distr_libs)"
	@echo "add_apps        = $(add_apps)"
	@echo "distr_data      = $(distr_data)"
	@echo "workspace       = $(workspace)"
	@echo "user_id         = $(user_id)"
	@echo "  -- Make vars --"
	@echo "IMAGENAME       = $(IMAGENAME)"
	@echo "REPO            = $(REPO)"
	@echo "DISTRFULLNAME   = $(DISTRFULLNAME)"
	@echo "CONFFULLNAME    = $(CONFFULLNAME)"
	@echo "INSTALLFULLNAME = $(INSTALLFULLNAME)"
	@echo "IMAGEFULLNAME   = $(IMAGEFULLNAME)"
	@echo "DISTR_DATA      = $(DISTR_DATA)"
	@echo "WORKSPACE       = $(WORKSPACE)"
	@echo "PWD             = $(PWD)"

help:
	@echo "Run with 'make <target> [argument1=<value1>] [argument2=<value2>] ...'"
	@echo "Makefile arguments:"
	@echo ""
	@echo "env          - Make Environment Suffix Name"
	@echo ""
	@echo "Overriding make enironment (consider making new make_env for long term):"
	@echo "-e target    - Override Target Software Name"
	@echo "-e version   - Override Target Software Version"
	@echo "-e suffix    - Override Image Suffix Name"
	@echo "-e base      - Override Base Image"
	@echo "-e base_ver  - Override Base Image Version"
	@echo "-e distr_libs- Override Required Libs List before installation"
	@echo "-e distr_data- Override Distributive Location"
	@echo "-e add_apps  - Override Additional Apps List after installation"
	@echo ""
	@echo "Makefile targets:"
	@echi "default_env  - Set default environment for following makes"
	@echo "debug        - Debug make itself - print actual variables values"
	@echo "distr        - Prepare distr image with distributive data"
	@echo " -- NOTE: conf,install,image,tar depends on distr image but won't make it"
	@echo "conf         - Prepare configuration file for installation"
	@echo "install      - Make image with taret software installed"
	@echo "image        - Make final image with all additional apps and user setup"
	@echo "all          - Make distr, conf and then final image"
	@echo "tar          - Export final image into tar to share with others"
	@echo "import       - Imports tar as final image"
	@echo "prune        - Remove all docker images"
	@echo "clean        - prune + remove build artifacts"
	@echo "clean_all    - clean + remove exported image"
	@echo " -- NOTE: all below depends on final image but won't make it"
	@echo "version      - Print installed software version"
	@echo "test_sim     - Test simulation"
	@echo "test_synth   - Test synthesis"
	@echo "test_clean   - Clean tests data"
	@echo "simulate     - Do simulation (not yet)"
	@echo "bitstream    - Make bitstream (not yet)"

# TODO: download distr data
default_env:
	@echo "env=$(env)" > default_env

distr: Dockerfile.$(target)-distr $(DISTR_DATA)
	@echo "*" > .dockerignore
	@echo "!$(DISTR_DATA)" >> .dockerignore
	@echo "!$(DISTR_DATA)/**/*" >> .dockerignore

	docker build -t $(DISTRFULLNAME) -f Dockerfile.$(target)-distr \
	--build-arg BASE="$(base):$(base_ver)" \
	--build-arg DISTR_LIBS="$(distr_libs)" \
	--build-arg DISTR_DATA="$(distr_data)" \
	.

conf: Dockerfile.$(target)-conf config.sh

	mkdir -p $(WORKSPACE)
	rm -f $(WORKSPACE)/install_config.txt

	@echo "*" > .dockerignore
	@echo "!config.sh" >> .dockerignore

	docker build -t $(CONFFULLNAME) -f Dockerfile.$(target)-conf \
	--build-arg BASE=$(DISTRFULLNAME) \
	--build-arg USER_ID=$(user_id) \
	.
	
	docker run --rm -i -t -v "$(PWD)/$(WORKSPACE)":/home/$(target)/workspace "$(CONFFULLNAME)" /bin/bash /tmp/config.sh

$(WORKSPACE)/install_config.txt:
	@echo $(shell test ! -e $(WORKSPACE)/install_config.txt && echo -n "run 'make conf ...' or put 'install_config.txt' into '$(WORKSPACE)'")
	CONF = $(shell test -e $(WORKSPACE)/install_config.txt)

check_conf: $(WORKSPACE)/install_config.txt
	@echo "configuration file is at place"

install: Dockerfile.$(target)-install check_conf

	@echo "*" > .dockerignore
	@echo "!$(WORKSPACE)/install_config.txt" >> .dockerignore

	docker build -t $(INSTALLFULLNAME) -f Dockerfile.$(target)-install \
	--build-arg BASE=$(DISTRFULLNAME) \
	--build-arg WOKRKSPACE=$(workspace) \
	--build-arg VIVADO_VERSION=$(version) \
	.

$(WORKSPACE)/Xilinx.lic:
#	@echo $(shell test ! -e $(WORKSPACE)/Xilinx.lic && echo -n "put 'Xilinx.lic' into '$(WORKSPACE)'")
#	LICENSE = $(shell test -e $(WORKSPACE)/Xilinx.lic)

check_license: $(WORKSPACE)/Xilinx.lic
#	@echo "license file is at place"

image: install Dockerfile.$(target) check_license

	@echo "*" > .dockerignore
	@echo "!$(WORKSPACE)/Xilinx.lic" >> .dockerignore

	docker build -t $(IMAGEFULLNAME) -f Dockerfile.$(target) \
	--build-arg BASE=$(INSTALLFULLNAME) \
	--build-arg USER_ID=$(user_id) \
	--build-arg ADD_APPS="$(add_apps)" \
	.

tar: image
	mkdir -p $(WORKSPACE)
	rm -f $(WORKSPACE)/$(WORKSPACE).tar
	docker container rm --force $(target)-export
	docker run --name $(target)-export "$(IMAGEFULLNAME)" echo
	docker export $(target)-export > $(WORKSPACE)/$(WORKSPACE).tar
	docker container rm --force $(target)-export

import:
	docker import $(IMPORT_PATH) "$(IMAGEFULLNAME)"
	rm -f $(WORKSPACE)/$(WORKSPACE).tar	

prune:
	docker rmi $(IMAGEFULLNAME)
	docker rmi $(INSTALLFULLNAME)
	docker rmi $(CONFFULLNAME) || echo "No conf image found for failed to prune it...skipping"
	docker rmi $(DISTRFULLNAME)

clean: prune
	rm -f $(WORKSPACE)/install_config.txt

clean_all: clean
	rm -f $(WORKSPACE)/$(WORKSPACE).tar

version:
	cd examples/version && make IMAGE="$(IMAGEFULLNAME)"

test_sim:
	cd examples/sim && make IMAGE="$(IMAGEFULLNAME)"

test_synth:
	cd examples/synth && make IMAGE="$(IMAGEFULLNAME)"

test_clean:
	cd examples/synth && make clean IMAGE="$(IMAGEFULLNAME)"

simulate:

bitstream:

bash:
	docker run -it --rm \
	-v "$(PWD)/$(WORKSPACE)":/home/$(target)/workspace \
	$(IMAGEFULLNAME) \
	/bin/bash --login

tcl:
	docker run -it --rm \
	-v "$(PWD)/$(WORKSPACE)":/home/$(target)/workspace \
	$(IMAGEFULLNAME) \
	/bin/bash --login -c "source /tools/Xilinx/Vivado/$(version)/settings64.sh && vivado -mode tcl"

gui:
	docker run --env=DISPLAY --rm \
	-v "$(PWD)/$(WORKSPACE)":/home/$(target)/workspace \
	-v /root/.Xauthority:/root/.Xauthority \
	--net=host \
	$(IMAGEFULLNAME) \
	/bin/bash --login -c "source /tools/Xilinx/Vivado/$(version)/settings64.sh && vivado"
