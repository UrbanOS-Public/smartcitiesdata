defmodule Forklift.TopicManagementTest do
  use ExUnit.Case
  use Divo, services: [:kafka, :redis]

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [dataset_update: 0]
  alias Forklift.TopicManager

  @endpoints Application.get_env(:forklift, :elsa_brokers)

  test "create new topic for dataset when dataset event is received" do
    dataset = TDG.create_dataset(id: "ds1")
    Brook.Event.send(dataset_update(), :author, dataset)

    eventually(fn ->
      assert {"integration-ds1", 1} in Elsa.Topic.list(@endpoints)
    end)
  end

  test "create new topic for dataset when dataset event is received and topic already exists" do
    dataset = TDG.create_dataset(id: "bob1")
    TopicManager.setup_topics(dataset)
    TopicManager.setup_topics(dataset)

    eventually(fn ->
      assert {"integration-bob1", 1} in Elsa.Topic.list(@endpoints)
    end)
  end
end
