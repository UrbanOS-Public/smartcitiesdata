defmodule Alchemist.Event.EventHandlerTest do
  use ExUnit.Case
  use Brook.Event.Handler

  import SmartCity.Event, only: [ingestion_delete: 0, ingestion_update: 0]
  import Mock

  alias SmartCity.TestDataGenerator, as: TDG
  alias Alchemist.Event.EventHandler
  alias Alchemist.IngestionProcessor

  @instance_name Alchemist.instance_name()

  setup_with_mocks([
    {Alchemist.IngestionProcessor, [:passthrough], [start: fn(_) -> :does_not_matter end]}
  ]) do
    :ok
  end

  describe "handle_event/1" do
    setup do
      :ok
    end

    test "should update an ingestion when ingestion_update event fires" do
      ingestion = TDG.create_ingestion(%{})

      with_mock(IngestionProcessor, [start: fn(_) -> :ok end]) do
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
    end

    test "should delete ingestion when ingestion_delete event fires" do
      ingestion = TDG.create_ingestion(%{})

      with_mock(IngestionProcessor, [delete: fn(_) -> :ok end]) do
        Brook.Test.with_event(@instance_name, fn ->
          EventHandler.handle_event(
            Brook.Event.new(
              type: ingestion_delete(),
              data: ingestion,
              author: :author
            )
          )
        end)

        assert_called(IngestionProcessor.delete(ingestion))
      end
    end
  end
end
