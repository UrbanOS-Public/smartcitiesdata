defmodule Valkyrie.DatasetSupervisorTest do
  use ExUnit.Case
  use Placebo

  alias Valkyrie.DatasetSupervisor
  alias SmartCity.TestDataGenerator, as: TDG

  describe "ensure_started/1" do
    test "should start dataset process" do
      dataset_id = "some-fantastic-id"

      allow(DynamicSupervisor.start_child(any(), any()),
        exec: fn _, _ -> Agent.start(fn -> 36 end, name: :"#{dataset_id}_supervisor") end,
        meck_options: [:passthrough]
      )

      start_options = [
        dataset_id: dataset_id,
        input_topic: "input_topic",
        output_topic: "output_topic"
      ]

      %{start_options: start_options}

      DatasetSupervisor.ensure_started(start_options)

      assert_called(
        DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})
      )
    end

    test "should not restart a running dataset process" do
      dataset_id = "some-unimaginable-id"

      allow(DynamicSupervisor.start_child(any(), any()),
        exec: fn _, _ -> Agent.start(fn -> 36 end, name: :"#{dataset_id}_supervisor") end,
        meck_options: [:passthrough]
      )

      start_options = [
        dataset_id: dataset_id,
        input_topic: "input_topic",
        output_topic: "output_topic"
      ]

      %{start_options: start_options}

      {:ok, first_pid} = DatasetSupervisor.ensure_started(start_options)

      assert {:ok, ^first_pid} = DatasetSupervisor.ensure_started(start_options)

      assert_called(
        DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options}),
        once()
      )
    end
  end
end
