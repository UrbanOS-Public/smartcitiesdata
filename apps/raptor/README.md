# Raptor

To start Raptor locally:

  * Install dependencies with `mix deps.get`
  * Run `MIX_ENV=integration mix docker.start`
  * Run `MIX_ENV=integration iex -S mix start`

Now you can visit [`localhost:4000`](http://localhost:4000/healthcheck) from your browser or via Postman and should receive a 200 OK response.

Note: If you view this in Chrome, you will receive a faviocon.ico error message in the console, although you will still receive a 200 OK response. This is because this microservice is just an internal API, it's not intended to be called by a front-end application.

To test that the event stream is working, you can send a smart city event through the microservice and see the result outputted in the console:
  ```
    organization = SmartCity.TestDataGenerator.create_organization(%{})
    Brook.Event.send(Raptor.instance_name(), "organization:update", :testing, organization)

    dataset = SmartCity.TestDataGenerator.create_dataset(%{})
    Brook.Event.send(Raptor.instance_name(), "dataset:update", :testing, dataset)

    ***** CODE TO RUN TO TEST UserOrgAssociate Event!!! *******
    alias SmartCity.UserOrganizationAssociate
    import SmartCity.Event, only: [user_login: 0, user_organization_associate: 0]
    association = %SmartCity.UserOrganizationAssociate{org_id: "org1", subject_id: "user1", email: "blah@blah.com"}
    Brook.Event.send(Raptor.instance_name(), user_organization_associate(), :testing, association)
  ```

To run unit tests: `mix test`
To run integration tests: `mix test.integration`
