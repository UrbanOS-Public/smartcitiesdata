clean:
	mix deps.clean --all
	rm -f mix.lock

deps:	mix.lock

mix.lock:
	mix deps.get

compile:
	mix compile
