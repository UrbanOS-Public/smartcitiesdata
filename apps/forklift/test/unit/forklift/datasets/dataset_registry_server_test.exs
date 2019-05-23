defmodule Forklift.Datasets.DatasetRegistryServerTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG

  describe "doctests" do
    setup do
      dataset =
        TDG.create_dataset(%{
          id: "123",
          technical: %{
            systemName: "system__name",
            schema: [
              %{
                name: "id",
                type: "int"
              },
              %{
                name: "name",
                type: "string"
              }
            ]
          }
        })

      Forklift.Datasets.DatasetRegistryServer.send_message(dataset)
      :ok
    end

    doctest Forklift.Datasets.DatasetRegistryServer
  end
end
