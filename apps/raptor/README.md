# Raptor

Raptor is an elixir microservice that can be used to authorize access to private datasets. It has a REST endpoint that accepts an API Key from Auth0 and a system_name of a SmartCity dataset. It will then return a boolean indicating whether or not a user has access to the given dataset.

## Using Raptor

### Prerequisites

#### Auth0 Requirements

In order to access Raptor, Auth0 credentials are required. Follow these steps in order to set up auth0 to access Raptor:

1. Create an authorized account in Auth0 to access Raptor. Make sure to create the account in the tenant that matches the development environment that you are using.
2. Get the Auth0 Client Secret from Auth0. Raptor requires an Auth0 client secret to be set as a system environment variable. You can get this value from auth0.com in the corresponding tenant configuration for the ANDI application. (Note: Eventually this will change to use the Auth0 Management API instead of ANDI's configuration.) You will need this value to start raptor (specified below in the <auth_client_secret> variable)
3. Get the API Key for the user that you created in Auth0. This APIKey should be generated the first time that you use your Auth0 credentials to log in to either ANDI or Discovery API. It can be found in the app_metadata section of the Auth0 management console for your user.

### Running Locally

To run Raptor locally, take the following steps:

1. Install dependencies with `mix deps.get`
2. Run `MIX_ENV=integration mix docker.start`
3. Run `AUTH0_CLIENT_SECRET=<auth_client_secret> MIX_ENV=integration iex -S mix start`

Now you can visit [`localhost:4002`](http://localhost:4002/healthcheck) from your browser or via Postman and should receive a 200 OK response.

### Generating Sample Data

To test that the event stream is working, you can send a SmartCity event through the microservice and see the result outputted in the console:

To send a dataset update event:

```
  dataset = SmartCity.TestDataGenerator.create_dataset(%{})
  Brook.Event.send(Raptor.instance_name(), "dataset:update", :testing, dataset)
```

To send a user_organization_associate event:

```
  alias SmartCity.UserOrganizationAssociate
  import SmartCity.Event
  association = %SmartCity.UserOrganizationAssociate{org_id: "org1", subject_id: "user1", email: "blah@blah.com"}
  Brook.Event.send(Raptor.instance_name(), user_organization_associate(), :testing, association)
```

To send a user_organization_disassociate event:

```
  alias SmartCity.UserOrganizationDisassociate
  import SmartCity.Event
  disassociation = %SmartCity.UserOrganizationDisassociate{org_id: "org1", subject_id: "user1"}
  Brook.Event.send(Raptor.instance_name(), user_organization_disassociate(), :testing, disassociation)
```

Note: You should not send a disassociate event before sending an associate event.

## Testing Raptor

### Unit Tests

Raptor relies on the standard ExUnit test framework to run unit tests, Run with the usual command: `mix test`

### Integration Tests

For integration testing, Andi encapsulates its external dependencies in Docker images and orchestrates the test runs through the Divo library. Run with the command: `mix test.integration`

## Documentation

For details on how to use the Raptor API, please review the Postman collection located [here](https://github.com/Datastillery/smartcitiesdata/blob/master/apps/raptor/Raptor.postman_collection.json).
