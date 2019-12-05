# Andi

This application is used to administer the creation and ongoing management of datasets and their associated organizations for the Smart Cities data platform. The name `Andi` is an acronym that stands for "Administrative Network Data Interface".

Andi is a Phoenix web application defining a RESTful interface to fill the dataset registry. Incoming JSON messages are parsed to create and save dataset definitions into Redis and save the associated organization into both Redis and LDAP.

Interactions with Redis are abstracted with `smartcitiesdata.smart_city*` functions, which format and parse dataset and org definitions into smart_city structs. Access to LDAP and the organizations created by Andi is handled through the `Paddle` library.

## Running Andi

- Install dependencies with `mix deps.get`
- `cd assets` and `npm i`
- `mix docker.start`
- Start Phoenix endpoint locally with `MIX_ENV=integration mix phx.server`

###

These two commands can be run within an `MIX_ENV=integration iex -S mix phx.server` to create sample data for testing things like the datasets list page.

```
datasets = Enum.map(1..3, fn _ -> SmartCity.TestDataGenerator.create_dataset([]) end)
```

```
Enum.each(datasets, &(Brook.Event.send(:andi, "dataset:update", :andi, &1)))
```

## Testing

### Unit Tests

Andi relies on the standard ExUnit test framework to run unit tests, Run with the usual command:

`mix test`

### Integration Tests

For integration testing, Andi encapsulates its external dependencies in Docker images and orchestrates the test runs through the Divo library. Run with the command:

`mix test.integration`

## License

Released under [Apache 2 license](https://github.com/smartcitiesdata/smartcitiesdata/blob/master/LICENSE).
