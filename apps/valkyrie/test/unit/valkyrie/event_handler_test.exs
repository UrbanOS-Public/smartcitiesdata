defmodule Valkyrie.EventHandlerTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_delete: 0, data_standardization_end: 0]
  use Placebo
  import Checkov

  setup do
    allow Valkyrie.Stream.Supervisor.start_child(any()), return: :does_not_matter
    allow Valkyrie.Stream.Supervisor.terminate_child(any()), return: :does_not_matter
    allow Brook.ViewState.delete(any(), any()), return: :does_not_matter
    allow Valkyrie.TopicHelper.delete_topics(any()), return: :does_not_matter
    :ok
  end

  describe "data:ingest:start event" do
    setup do
      allow Brook.ViewState.create(any(), any(), any()), return: :does_not_matter
      :ok
    end

    test "should store dataset by dataset.id" do
      expect(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)

      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "stream", schema: [%{name: "first", type: "integer"}]}
        )

      event = Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author)

      response = Valkyrie.EventHandler.handle_event(event)

      assert_called Brook.ViewState.create(:datasets, dataset.id, dataset), once()

      assert :ok == response
    end

    test "should start a stream supervisor child" do
      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "ingest", schema: []}
        )

      event = Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author)
      response = Valkyrie.EventHandler.handle_event(event)

      assert_called Valkyrie.Stream.Supervisor.start_child(dataset.id), once()
      assert :ok == response
    end

    data_test "should process datasets with #{source_type}? #{called}" do
      dataset = TDG.create_dataset(technical: %{sourceType: source_type})

      event = Brook.Event.new(type: data_ingest_start(), data: dataset, author: :author)
      Valkyrie.EventHandler.handle_event(event)

      assert called == called?(Valkyrie.Stream.Supervisor.start_child(dataset.id))

      where([
        [:source_type, :called],
        ["ingest", true],
        ["stream", true],
        ["host", false],
        ["remote", false],
        ["invalid", false]
      ])
    end
  end

  describe "dataset:delete event" do
    test "should stop a stream supervisor child" do
      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "ingest", schema: []}
        )

      event = Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
      response = Valkyrie.EventHandler.handle_event(event)

      assert_called Valkyrie.Stream.Supervisor.terminate_child(dataset.id), once()
      assert_called Valkyrie.TopicHelper.delete_topics(dataset.id), once()
      assert_called Brook.ViewState.delete(any(), dataset.id), once()
      assert :ok == response
    end
  end

  describe "end events" do
    test "should stop a dataset with #{dataset_delete()}" do
      dataset =
        TDG.create_dataset(
          id: Faker.UUID.v4(),
          technical: %{sourceType: "ingest", schema: []}
        )

      event = Brook.Event.new(type: dataset_delete(), data: dataset, author: :author)
      response = Valkyrie.EventHandler.handle_event(event)

      assert_called Valkyrie.Stream.Supervisor.terminate_child(dataset.id), once()
      assert_called Valkyrie.TopicHelper.delete_topics(dataset.id), once()
      assert_called Brook.ViewState.delete(any(), dataset.id), once()
      assert :ok == response
    end

    test "should stop a dataset with #{data_standardization_end()}" do
      data = %{"dataset_id" => Faker.UUID.v4()}

      event = Brook.Event.new(type: data_standardization_end(), data: data, author: :author)
      response = Valkyrie.EventHandler.handle_event(event)

      assert_called Valkyrie.Stream.Supervisor.terminate_child(data["dataset_id"]), once()
      assert_called Brook.ViewState.delete(any(), data["dataset_id"]), once()
      assert :ok == response
    end
  end
end
