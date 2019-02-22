defmodule Reaper.MessageHandlerTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.{ConfigServer, MessageHandler}

  describe ".handle_message" do
    test "does not actually handle datasets that are not valid" do
      bad_dataset = %Dataset{
        id: "hello",
        business: 1,
        operational: []
      }

      allow ConfigServer.send_dataset(any()), return: nil

      MessageHandler.handle_message("", %{value: Jason.encode!(bad_dataset)})

      assert not called?(ConfigServer.send_dataset(any()))
    end

    test "does send the dataset on if it's valid" do
      good_dataset = FixtureHelper.new_dataset(%{id: "cool"})

      expect ConfigServer.send_dataset(good_dataset), return: nil

      MessageHandler.handle_message("", %{value: Jason.encode!(good_dataset)})
    end
  end
end
