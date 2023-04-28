# Andi

This application is used to administer the creation and ongoing management of datasets and their associated organizations for the Smart Cities data platform. The name `Andi` is an acronym that stands for "Administrative Network Data Interface".

A detailed user guide explaining how Andi works from a user perspective is [available here](https://github.com/UrbanOS-Public/smartcitiesdata/wiki/Data-Curator-Interface-(ANDI)-User-Manual)

Andi is a Phoenix web application defining a RESTful interface to fill the dataset registry. Incoming JSON messages are parsed to create and save dataset definitions into Redis and save the associated organization into both Redis and LDAP.

Interactions with Redis are abstracted with `smartcitiesdata.smart_city*` functions, which format and parse dataset and org definitions into smart_city structs.

## Using Andi

### Prerequisites 

#### Auth0 Requirements
In order to access ANDI, Auth0 credentials are required. Follow these steps in order to set up auth0 to access ANDI:
1. Create an authorized account in Auth0 to access ANDI. Make sure to create the account in the tenant that matches the development environment that you are using. 
2. Get the Auth0 Client Secret from Auth0. Andi requires an Auth0 client secret to be set as a system environment variable. You can get this value from auth0.com in the corresponding tenant configuration for the ANDI application. You will need this value to start andi (specified below in the <auth_client_secret> variable)
3. Create self-signed TLS certificates. These certs will be regenerated when you run `MIX_ENV=integration mix start` or `mix test.integration`. 

NOTES: 
- In `config/integration.exs`, TLS is enabled for Phoenix by default to allow you to work with Auth0, which requires it. You can generate a key and self-signed certificate that works with the `config/integration.exs` setup by running `mix x509.gen.selfsigned localhost 127.0.0.1.xip.io --force` separately.

### Running Locally

To run ANDI locally, take the following steps:
1.  Install dependencies with `mix deps.get`. (Ths should be done in the smartcitiesdata directory.)
2.  Move to the assests folder using the command: `cd apps/andi/assets`.
3.  Run the command `npm install` in the assets folder.
4.  Move to the root ANDI folder by running the command `cd ..`. (You should now be in the same directory as this README.)
5.  Run `MIX_ENV=integration mix docker.start` to start docker for ANDI local development. If this command times out and you see an error message like 'patiently gave up waiting for...', re-run the command. 
6.  Start Phoenix endpoint locally with `AUTH0_CLIENT_SECRET="<auth_client_secret>" MIX_ENV=integration iex -S mix start`. Use the auth_client_secret that you obtained in the Auth0 requirements steps above.
7.  Congratulations! ANDI is now running locally. Because Auth0 requires `https`, you can visit paths like `localhost` by using `https://127.0.0.1.nip.io:4443/datasets`

NOTES:
  - Port 4443 can be swapped for the port used in the https configuration defined in `integration.exs` under `AndiWeb.Endpoint`.
  - If the page `https://127.0.0.1.nip.io:4443/datasets` is not loading on the browser after successful start of the server (This may happen in LINUX OS), consider adding `127.0.0.1       127.0.0.1.nip.io` at the end of file `/etc/hosts`. Using `sudo vim /etc/hosts`

### Generating Sample Data

This command can be run within the elixir console once ANDI is running to create sample data for testing things like the datasets list and dataset edit pages.

To generate 3 sample datasets and send them to the event stream as dataset update events run the following command:
```
Enum.map(1..3, fn _ -> SmartCity.TestDataGenerator.create_dataset([]) end) |> Enum.each(&(Brook.Event.send(:andi, "dataset:update", :andi, &1)))
```

#### ResendEvent Scripts

ANDI has the capability to send a dataset:update and a user-organization:associate event for all existing datasets and user organization associations. In order to use this capability, execute the functions in the module `Andi.Scripts.ResendEvents`. This is useful when standing up a new microservice that listens to the event stream, in order to get that new service caught up to the current state of datasets and user-organization associations.

Example:
```
# To resend all dataset events
Andi.Scripts.ResendEvents.resend_dataset_events()

# To resend all user-organizations associations
Andi.Scripts.ResendEvents.resend_user_org_assoc_events()
```

## Testing ANDI

### Unit Tests

Andi relies on the standard ExUnit test framework to run unit tests, Run with the usual command:

`mix test`

### Integration Tests

For integration testing, Andi encapsulates its external dependencies in Docker images and orchestrates the test runs through the Divo library. Run with the command:

`mix test.integration`

Individual files can be run using the following command:

`mix test.integration /path/to/file.exs`

Individual tests can be run by adding the test's line number to the end of the file:

`mix test.integration /path/to/file.exs:10`

## Documentation 

For details on how to use the ANDI API, please review the Postman collection located [here](https://github.com/UrbanOS-Public/smartcitiesdata/blob/master/apps/andi/ANDI.postman_collection.json).

### How to Access Log Events

When ANDI emits events of various types, it logs the details of the event to a Postgres table named `audit_events`.

To access these logs a user will need access to the elixir console from a running version of ANDI. If ANDI is running in a kubernetes pod, the user will need to shell into the pod then run the `bin/andi remote_console` command to get access to ANDI's elixir console. Then see the below options for what logs can be accessed.

1. To get all logs of all events, run the command `Andi.Schemas.AuditEvents.get_all()`. Note that this may result in a large volume of events.
2. To get a specific log entry by id, run the command `Andi.Schemas.AuditEvents.get(audit_event_id)`.
3. To get a log of all events performed by a specific user, run the command `Andi.Schemas.AuditEvents.get_all_for_user(user_id)`. Note that the user_id is the user's email address.
4. To get all log entries for a specific event type, run the command `Andi.Schemas.AuditEvents.get_all_of_type(event_type)`. Note that the event type will be a string matching a SmartCity.Event.
5. To get all of the log entries for a specific date range, run the command `Andi.Schemas.AuditEvents.get_all_in_range(start_date, end_date)`. Note, start_date and end_date should be in the format `~D[YYYY-MM-DD]`. This can be generated using the command `{:ok, date} = Date.new(YYYY, MM, DD)`. Dates are in UTC time.
6. To get all log entries for a specific event, run the command `Andi.Schemas.AuditEvents.get_all_by_event_id(event_id)`. Valid entries for `event_id` are a dataset_id, an organization_id, or an ingestion_id.
