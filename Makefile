clean:
	mix deps.clean --all
	rm -f mix.lock

deps:	mix.lock

mix.lock:
	mix deps.get

compile:
	mix compile

lint:
	#cd apps/forklift; mix format
	./scripts/gh-action-static-checks.sh forklift


