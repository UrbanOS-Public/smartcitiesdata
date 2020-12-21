# Odo

Odo is an Elixir microservice that converts geospatial data files
from one supported format to another.

Currently, this is a single, one-way, lossy transformation from the
Shapefile format to the GeoJson format. This is accomplished by the
[Geomancer](https://github.com/jdenen/geomancer) library.

Odo orchestrates the conversion of file types by scheduling independent
supervised task processes that spawn, schedule the conversion by saving
the operation to the application's view of the event stream, and then
exit.

When tasks are killed unexpectedly, the supervision of the process
ensures it is restarted and the persisted view detailing what conversions
have been started but not completed triggers another conversion attempt.

Once a conversion has completed and the result successfully uploaded to
the storage backend, Odo deletes the record of the queued conversion
and acknowledges the original request message to ensure files are not
continually converted ad infinitum.


## To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

## To run inside a container:
  * Go to the root of smartcitesdata `cd ../../` assuming in your in the root of forklift
  * `./scripts/build.sh odo 1.0`
    