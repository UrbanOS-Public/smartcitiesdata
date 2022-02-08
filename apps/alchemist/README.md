# Template

This repo contains a sample application that can be used as a template to create a new elixir microservice. To use this template:

1. Copy and paste this folder in the smartcitiesdata/apps repository and update the name from template to your new microservice.
2. Find and replace references to 'template' with the name of your new microservice in the folder.
3. Rename all the files to use the name of your new microservice, as appropriate.
4. Run the application following the steps below.

-OR-

1. Use this application as a reference after generating a new microservice using the `phx.new` command.

Note: A Dockerfile is not included as part of the template application.

To run the template application:

- Install dependencies with `mix deps.get` (from the smartcities root)
- Run `MIX_ENV=integration mix docker.start`
- Run `MIX_ENV=integration iex -S mix start`

Now you can visit [`localhost:4000`](http://localhost:4000/healthcheck) from your browser or via Postman and should receive a 200 OK response.

Note: If you view this in Chrome, you will receive a faviocon.ico error message in the console, although you will still receive a 200 OK response. This is because this microservice is just an internal API, it's not intended to be called by a front-end application.

To test that the event stream is working, you can send a smart city event through the microservice and see the result outputted in the console:

```
  organization = SmartCity.TestDataGenerator.create_organization(%{})
  Brook.Event.send(Alchemist.instance_name(), "organization:update", :testing, organization)
```

To run unit tests: `mix test`
To run integration tests: `mix test.integration`
