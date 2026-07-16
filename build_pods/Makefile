# From the project root dir:
#   make -f build_pods/Makefile discovery_api
#   make -f build_pods/Makefile discovery_api PUSH=1
#   PUSH=1 make -f build_pods/Makefile discovery_api

ifdef PUSH
PUSH_FLAG := --push
else
PUSH_FLAG :=
endif

discovery_api:
	scripts/build-local.sh $(PUSH_FLAG) discovery_api

valkyrie:
	scripts/build-local.sh $(PUSH_FLAG) valkyrie

alchemist:
	scripts/build-local.sh $(PUSH_FLAG) alchemist

andi:
	scripts/build-local.sh $(PUSH_FLAG) andi

reaper:
	scripts/build-local.sh $(PUSH_FLAG) reaper

forklift:
	scripts/build-local.sh $(PUSH_FLAG) forklift



