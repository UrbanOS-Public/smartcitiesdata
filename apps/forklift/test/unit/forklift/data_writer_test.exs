defmodule Forklift.DataWriterTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :forklift

  alias Forklift.DataWriter
  alias SmartCity.TestDataGenerator, as: TDG
  import Mox

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)

  setup :set_mox_global
  setup :verify_on_exit!

  test "should delete table and topic when delete is called" do
    expected_dataset =
      TDG.create_dataset(%{
        technical: %{systemName: "some_system_name"}
      })

    expected_endpoints = elsa_brokers()
    expected_topic = "#{input_topic_prefix()}-#{expected_dataset.id}"

    stub(MockTopic, :delete, fn [endpoints: actual_endpoints, topic: actual_topic] ->
      assert expected_endpoints == actual_endpoints
      assert expected_topic == actual_topic
      :ok
    end)

    stub(MockTable, :delete, fn [dataset: actual_dataset] ->
      assert expected_dataset == actual_dataset
      :ok
    end)

    assert :ok == DataWriter.delete(expected_dataset)
  end
end
