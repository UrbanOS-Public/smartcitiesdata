defmodule DiscoveryApi.Data.ProjectOpenDataHandlerTest do
  use ExUnit.Case
  use Placebo
  use TemporaryEnv
  alias DiscoveryApi.Data.ProjectOpenDataHandler
  alias DiscoveryApi.Data.Persistence
  alias DiscoveryApi.Data.Mapper

  describe "process_project_open_data_event/1" do
    setup do
      allow(Persistence.persist(any(), any()), return: {:ok, :does_not_matter})

      dataset = %SmartCity.Dataset{
        id: "myfancydata",
        business: %SmartCity.Dataset.Business{
          contactEmail: "here_to_make_podms_mapper_happy@example.com"
        },
        technical: %SmartCity.Dataset.Technical{
          private: false
        }
      }

      private_dataset = %SmartCity.Dataset{
        id: "private_dataset_id",
        technical: %SmartCity.Dataset.Technical{
          private: true
        }
      }

      {:ok,
       %{
         dataset: dataset,
         private_dataset: private_dataset
       }}
    end

    test "saves project open data to persistence layer", %{dataset: dataset} do
      base_url = "this_is_the_host"

      TemporaryEnv.put :discovery_api, DiscoveryApiWeb.Endpoint, %{url: %{host: base_url}} do
        podms_map = Mapper.to_podms(dataset, "https://data.#{base_url}")

        {:ok, _} = ProjectOpenDataHandler.process_project_open_data_event(dataset)

        assert_called(Persistence.persist("discovery-api:project-open-data:#{dataset.id}", podms_map))
      end
    end

    test "does not save private datasets to persistence layer", %{private_dataset: private_dataset} do
      {:ok, response} = ProjectOpenDataHandler.process_project_open_data_event(private_dataset)

      refute_called(Persistence.persist(any(), any()))
      assert :not_persisted == response
    end
  end
end
