# Andi

This application is used to administer the creation and ongoing management of datasets and their associated organizations for the Smart Cities data platform. The name `Andi` is an acronym that stands for "Administrative Network Data Interface".

Andi is a Phoenix web application defining a RESTful interface to fill the dataset registry. Incoming JSON messages are parsed to create and save dataset definitions into Redis and save the associated organization into both Redis and LDAP.

Interactions with Redis are abstracted with `smartcitiesdata.smart_city*` functions, which format and parse dataset and org definitions into smart_city structs. Access to LDAP and the organizations created by Andi is handled through the `Paddle` library.

## Running Andi

#### Prerequisites for auth0 setup: 
- In `config/integration.exs`, TLS is enabled for Phoenix by default to allow you to work with Auth0, which requires it.
- You must create self-signed TLS certificates in order for this configuration to take hold. These certs will be regenerated if you run `MIX_ENV=integration mix start` or `mix test.integration`. However, you can generate a key and self-signed certificate that works with the `config/integration.exs` setup by running `mix x509.gen.selfsigned localhost 127.0.0.1.nip.io --force` separately.
- Andi also requires an Auth0 client secret to be set as a system environment variable. You can get this value from auth0.com in the corresponding tenant configuration for the ANDI application. You will need this value to start andi (specified below in the <auth_client_secret> variable)
- Lastly, you need an authorized account to login when the application starts


- Install dependencies with `mix deps.get` (in the smartcitiesdata directory)
- `cd assets` and `npm i` (in this directory)
- `MIX_ENV=integration mix docker.start` (in this directory)
- Start Phoenix endpoint locally with `AUTH0_CLIENT_SECRET="<auth_client_secret>" MIX_ENV=integration iex -S mix start` (in this directory)
- Because Auth0 requires `https`, you can visit paths like `localhost` by using `https://127.0.0.1.nip.io:4443/datasets`
	- port 4443 can be swapped for the port used in the https configuration defined in `integration.exs` under `AndiWeb.Endpoint`
    - `MIX_ENV=integration mix start` will automatically generate the self-signed certificate for HTTPS. Review the output it gives for directions on how to allow the self-signed cert on your dev machine for ONLY localhost

- NOTE:
  - If this page `https://127.0.0.1.nip.io:4443/datasets` is not loading on the browser after successful start of the server (This may happen in LINUX OS).
    - Consider adding `127.0.0.1       127.0.0.1.nip.io` at the end of file `/etc/hosts`. Using `sudo vim /etc/hosts`

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

Released under [Apache 2 license](https://github.com/Datastillery/smartcitiesdata/blob/master/LICENSE).
