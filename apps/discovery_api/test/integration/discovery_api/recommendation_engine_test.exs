defmodule DiscoveryApi.RecommendationEngineTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.RecommendationEngine

  use Divo, services: [:redis]

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

    results = RecommendationEngine.get_recommendations(dataset_to_get_recommendations_for)

    assert [%{id: dataset_that_should_match.id, systemName: dataset_that_should_match.technical.systemName}] == results
  end
end
