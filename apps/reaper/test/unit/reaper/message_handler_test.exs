defmodule Reaper.MessageHandlerTest do
  use ExUnit.Case
  use Placebo
  import ExUnit.CaptureLog

  alias Reaper.{ConfigServer, MessageHandler}

  describe ".handle_message" do
    @tag capture_log: true
    test "does not actually handle registry messages that are not valid" do
      bad_registry_message = %{
        id: "hello",
        business: 1,
        technical: []
      }

      allow ConfigServer.process_reaper_config(any()), return: nil

      MessageHandler.handle_message(%{value: Jason.encode!(bad_registry_message)})

      assert not called?(ConfigServer.process_reaper_config(any()))
    end

    test "does send the registry message on if it's valid" do
      registry_message = FixtureHelper.new_registry_message(%{id: "cool"})

      reaper_config =
        FixtureHelper.new_reaper_config(%{
          dataset_id: registry_message.id,
          cadence: registry_message.technical.cadence,
          sourceUrl: registry_message.technical.sourceUrl,
          sourceFormat: registry_message.technical.sourceFormat,
          queryParams: registry_message.technical.queryParams
        })

      expect ConfigServer.process_reaper_config(reaper_config), return: nil

      MessageHandler.handle_message(%{value: Jason.encode!(registry_message)})
    end

    @tag capture_log: true
    test "returns ok when invalid json" do
      allow ConfigServer.process_reaper_config(any()), return: nil

      response = MessageHandler.handle_message(%{value: "a"})

      assert not called?(ConfigServer.process_reaper_config(any()))
      assert :ok == response
    end
  end
end
