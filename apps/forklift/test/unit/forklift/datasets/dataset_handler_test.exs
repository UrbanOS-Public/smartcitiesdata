defmodule Forklift.Datasets.DatasetHandlerTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.Datasets.DatasetHandler
  alias Forklift.Datasets.DatasetRegistryServer
  alias SmartCity.TestDataGenerator, as: TDG

  describe "handle_dataset/1" do
    test "ignores remote datasets" do
      allow DatasetRegistryServer.send_message(any()), return: :ignore
      allow Forklift.TopicManager.create_and_subscribe(any()), return: :ignore

      %{id: "1", technical: %{sourceType: "remote"}}
      |> TDG.create_dataset()
      |> DatasetHandler.handle_dataset()

      refute_called DatasetRegistryServer.send_message(any())
      refute_called Forklift.TopicManager.create(any())
    end
  end
end
