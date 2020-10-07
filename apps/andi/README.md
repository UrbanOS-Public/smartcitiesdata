# Andi

This application is used to administer the creation and ongoing management of datasets and their associated organizations for the Smart Cities data platform. The name `Andi` is an acronym that stands for "Administrative Network Data Interface".

Andi is a Phoenix web application defining a RESTful interface to fill the dataset registry. Incoming JSON messages are parsed to create and save dataset definitions into Redis and save the associated organization into both Redis and LDAP.

Interactions with Redis are abstracted with `smartcitiesdata.smart_city*` functions, which format and parse dataset and org definitions into smart_city structs. Access to LDAP and the organizations created by Andi is handled through the `Paddle` library.

## Running Andi

#### Prerequisites for auth0 setup: 
- In `config/integration.exs`, you must enable HTTPS in order to securely access the Auth0 login page. There is a comment block with the necessary config under the `Endpoint` configuration that can be uncommented.
- You must create self-signed SSL certificates in order for this configuration to take hold. Generate `key.pem` and a `cert.pem` file in the `priv` folder. You can do this by running `./generate-certs.sh` in the `priv` folder. Or by running the following line: `openssl req -newkey rsa:2048 -nodes -keyout key.pem -x509 -days 365 -out cert.pem`
- Andi also requires an Auth0 client secret to be set as a system environment variable. You can get this value from auth0.com in the corresponding tenant configuration for the ANDI application. You will need this value to start andi (specified below in the <auth_client_secret> variable)
- Lastly, you need an authorized account to login when the application starts


- Install dependencies with `mix deps.get`
- `cd assets` and `npm i`
- `MIX_ENV=integration mix docker.start`
- `MIX_ENV=integration mix ecto.create && MIX_ENV=integration mix ecto.migrate`
- Start Phoenix endpoint locally with `AUTH0_CLIENT_SECRET="<auth_client_secret>" MIX_ENV=integration iex -S mix phx.server`
- Because Auth0 requires `https`, you can visit paths like `localhost` by using `https://127.0.0.1.xip.io:4443/datasets`
	- port 4443 can be swapped for the port used in the https configuration defined in `integration.exs` under `AndiWeb.Endpoint`

###

These two commands can be run within an `MIX_ENV=integration iex -S mix start` to create sample data for testing things like the datasets list page.

To generate sample datasets:
```
Enum.map(1..3, fn _ -> SmartCity.TestDataGenerator.create_dataset([]) end) |> Enum.each(&(Brook.Event.send(:andi, "dataset:update", :andi, &1)))
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
