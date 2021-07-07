defmodule DiscoveryApi.RecommendationEngineTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.RecommendationEngine
  alias DiscoveryApi.Test.Helper

  use DiscoveryApi.DataCase

  import SmartCity.Event, only: [dataset_update: 0]

  @instance_name DiscoveryApi.instance_name()

  test "dataset recommendations" do
    organization = Helper.create_persisted_organization()
    {:ok, organization} = DiscoveryApi.Schemas.Organizations.get_organization(organization.id)

    dataset_to_get_recommendations_for =
      TDG.create_dataset(%{
        organization_id: organization.id,
        technical: %{
          schema: [
            %{name: "id", type: "int"},
            %{name: "name", type: "string"},
            %{name: "age", type: "int"},
            %{name: "address_line_1", type: "string"},
            %{name: "lat", type: "double"},
            %{name: "long", type: "double"}
          ]
        }
      })

    

    dataset_with_wrong_types =
      TDG.create_dataset(%{
        organization_id: organization.id,
        technical: %{
          schema: [
            %{name: "id", type: "bad"},
            %{name: "name", type: "bad"},
            %{name: "age", type: "bad"},
            %{name: "address_line_1", type: "bad"},
            %{name: "lat", type: "bad"},
            %{name: "long", type: "bad"}
          ]
        }
      })

    dataset_that_should_match =
      TDG.create_dataset(%{
        organization_id: organization.id,
        technical: %{
          schema: [
            %{name: "id", type: "int"},
            %{name: "name", type: "string"},
            %{name: "age", type: "int"},
            %{name: "random", type: "string"}
          ]
        }
      })

    dataset_that_doesnt_meet_column_count_threshold =
      TDG.create_dataset(%{
        organization_id: organization.id,
        technical: %{
          schema: [
            %{name: "id", type: "int"},
            %{name: "name", type: "string"},
            %{name: "random_stuff", type: "string"}
          ]
        }
      })

    RecommendationEngine.save(dataset_to_get_recommendations_for, organization)
    RecommendationEngine.save(dataset_with_wrong_types, organization)
    RecommendationEngine.save(dataset_that_should_match, organization)
    RecommendationEngine.save(dataset_that_doesnt_meet_column_count_threshold, organization)

    Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset_to_get_recommendations_for)

    Patiently.wait_for!(
      fn -> DiscoveryApi.Data.Model.get(dataset_to_get_recommendations_for.id) != nil end,
      dwell: 100,
      max_tries: 20
    )

    %{body: body, status_code: 200} =
      "http://localhost:4000/api/v1/dataset/#{dataset_to_get_recommendations_for.id}/recommendations"
      |> HTTPoison.get!()

    results = Jason.decode!(body, keys: :atoms)

    assert [
             %{
               id: dataset_that_should_match.id,
               systemName: dataset_that_should_match.technical.systemName,
               dataName: dataset_that_should_match.technical.dataName,
               orgName: organization.name,
               dataTitle: dataset_that_should_match.business.dataTitle
             }
           ] == results
  end
end
