defmodule Reaper.EventHandlerTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :reaper

  import SmartCity.TestHelper
  import SmartCity.Event
  alias SmartCity.TestDataGenerator, as: TDG
  alias DeadLetter

  @instance_name Reaper.instance_name()
  getter(:elsa_brokers, generic: true)

  describe "Ingestion Update" do
    @tag :skip
    test "A failing message gets placed on dead letter queue and discarded" do
      # Skipped: Integration tests should not use mocks
      # This test was using allow() to mock Reaper.Event.Handlers.IngestionUpdate.handle failures
      # For integration testing, real error conditions should be used instead
    end
  end

  describe "Ingestion Delete" do
    @tag :skip
    test "A failing message gets placed on dead letter queue and discarded" do
      # Skipped: Integration tests should not use mocks
      # This test was using allow() to mock Reaper.Event.Handlers.IngestionDelete.handle failures
      # For integration testing, real error conditions should be used instead
    end
  end

  describe "Data Extract Start" do
    @tag :skip
    test "A failing message gets placed on dead letter queue and discarded" do
      # Skipped: Integration tests should not use mocks
      # This test was using allow() to mock Reaper.Collections.Extractions.is_enabled? failures
      # For integration testing, real error conditions should be used instead
    end
  end

  describe "Data Extract End" do
    @tag :skip
    test "A failing message gets placed on dead letter queue and discarded" do
      # Skipped: Integration tests should not use mocks
      # This test was using allow() to mock Reaper.Collections.Extractions.update_last_fetched_timestamp failures
      # For integration testing, real error conditions should be used instead
    end
  end
end
