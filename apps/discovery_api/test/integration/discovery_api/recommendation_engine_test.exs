defmodule DiscoveryApi.RecommendationEngineTest do
  use ExUnit.Case
  alias DiscoveryApi.TestDataGenerator, as: TDG
  alias DiscoveryApi.RecommendationEngine
  alias DiscoveryApi.Test.Helper

  use Divo, services: [:redis, :zookeeper, :kafka, :"ecto-postgres"]
  use DiscoveryApi.DataCase

  setup do
    Helper.wait_for_brook_to_be_ready()
    :ok
  end

  test "dataset recommendations" do
    dataset_to_get_recommendations_for =
      TDG.create_dataset(%{
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

    Helper.create_persisted_organization(%{id: dataset_to_get_recommendations_for.technical.orgId})

    dataset_with_wrong_types =
      TDG.create_dataset(%{
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
        technical: %{
          schema: [
            %{name: "id", type: "int"},
            %{name: "name", type: "string"},
            %{name: "random_stuff", type: "string"}
          ]
        }
      })

    RecommendationEngine.save(dataset_to_get_recommendations_for)
    RecommendationEngine.save(dataset_with_wrong_types)
    RecommendationEngine.save(dataset_that_should_match)
    RecommendationEngine.save(dataset_that_doesnt_meet_column_count_threshold)

    SmartCity.Registry.Dataset.write(dataset_to_get_recommendations_for)

    Patiently.wait_for!(
      fn -> DiscoveryApi.Data.Model.get(dataset_to_get_recommendations_for.id) != nil end,
      dwell: 100,
      max_tries: 20
    )

    DiscoveryApi.Data.Model.get(dataset_to_get_recommendations_for.id)

    %{body: body, status_code: 200} =
      "http://localhost:4000/api/v1/dataset/#{dataset_to_get_recommendations_for.id}/recommendations"
      |> HTTPoison.get!()

    results = Jason.decode!(body, keys: :atoms)

    assert [
             %{
               id: dataset_that_should_match.id,
               systemName: dataset_that_should_match.technical.systemName,
               dataName: dataset_that_should_match.technical.dataName,
               orgName: dataset_that_should_match.technical.orgName,
               dataTitle: dataset_that_should_match.business.dataTitle
             }
           ] == results
  end
end
