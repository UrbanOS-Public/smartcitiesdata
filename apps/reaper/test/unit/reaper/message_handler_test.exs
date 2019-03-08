defmodule Reaper.MessageHandlerTest do
  use ExUnit.Case
  use Placebo
  import ExUnit.CaptureLog

  alias Reaper.{ConfigServer, MessageHandler}

  describe ".handle_message" do
    @tag capture_log: true
    test "does not actually handle datasets that are not valid" do
      bad_dataset = %{
        id: "hello",
        business: 1,
        technical: []
      }

      allow ConfigServer.send_sickle(any()), return: nil

      MessageHandler.handle_message(%{value: Jason.encode!(bad_dataset)})

      assert not called?(ConfigServer.send_sickle(any()))
    end

    test "does send the dataset on if it's valid" do
      dataset = FixtureHelper.new_registry_message(%{id: "cool"})

      sickle =
        FixtureHelper.new_sickle(%{
          dataset_id: dataset.id,
          cadence: dataset.technical.cadence,
          sourceUrl: dataset.technical.sourceUrl,
          sourceFormat: dataset.technical.sourceFormat,
          queryParams: dataset.technical.queryParams
        })

      expect ConfigServer.send_sickle(sickle), return: nil

      MessageHandler.handle_message(%{value: Jason.encode!(dataset)})
    end

    @tag capture_log: true
    test "returns ok when invalid json" do
      allow ConfigServer.send_sickle(any()), return: nil

      response = MessageHandler.handle_message(%{value: "a"})

      assert not called?(ConfigServer.send_sickle(any()))
      assert :ok == response
    end
  end
end
