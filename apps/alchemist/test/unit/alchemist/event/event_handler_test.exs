defmodule Alchemist.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo
  use Brook.Event.Handler
  import Checkov
  import SmartCity.Event, only: [ingestion_delete: 0, ingestion_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Alchemist.Event.EventHandler
  alias Alchemist.IngestionProcessor

  @instance_name Alchemist.instance_name()

  setup do
    allow(Alchemist.IngestionProcessor.start(any()), return: :does_not_matter, meck_options: [:passthrough])

    :ok
  end

  describe "handle_event/1" do
    setup do
      :ok
    end

    test "should update an ingestion when ingestion_update event fires" do
      ingestion = TDG.create_ingestion(%{})
      allow(IngestionProcessor.start(any()), return: :ok)

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: ingestion_update(),
            data: ingestion,
            author: :author
          )
        )
      end)

      assert_called(IngestionProcessor.start(ingestion))
    end

    test "should delete ingestion when ingestion_delete event fires" do
      ingestion = TDG.create_ingestion(%{})
      allow(IngestionProcessor.delete(any()), return: :ok)

      Brook.Test.with_event(@instance_name, fn ->
        EventHandler.handle_event(
          Brook.Event.new(
            type: ingestion_delete(),
            data: ingestion,
            author: :author
          )
        )
      end)

      assert_called(IngestionProcessor.delete(ingestion.id))
    end
  end
end
