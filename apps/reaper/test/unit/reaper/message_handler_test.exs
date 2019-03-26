defmodule Reaper.MessageHandlerTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.{ConfigServer, MessageHandler}

  describe ".handle_dataset" do
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

      expect(ConfigServer.process_reaper_config(reaper_config), return: nil)

      MessageHandler.handle_dataset(registry_message)
    end
  end
end
