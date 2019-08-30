defmodule Valkyrie.DatasetSupervisorTest do
  use ExUnit.Case
  use Placebo

  alias Valkyrie.DatasetSupervisor
  alias SmartCity.TestDataGenerator, as: TDG

  describe "ensure_started/1" do
    setup do
      dataset = TDG.create_dataset(%{})

      allow(DynamicSupervisor.start_child(any(), any()),
        return: Agent.start(fn -> 42 end, name: :"#{dataset.id}_supervisor"),
        meck_options: [:passthrough]
      )

      %{dataset: dataset}
    end

    test "should start dataset process", setup_params do
      start_options = [
        dataset: setup_params.dataset,
        input_topic: "input_topic",
        output_topic: "output_topic"
      ]

      DatasetSupervisor.ensure_started(start_options)

      assert_called(
        DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})
      )
    end

    test "should handle restarting a dataset process", setup_params do
      start_options = [
        dataset: setup_params.dataset,
        input_topic: "input_topic",
        output_topic: "output_topic"
      ]

      {:ok, first_pid} = DatasetSupervisor.ensure_started(start_options)

      {:ok, _second_pid} = DatasetSupervisor.ensure_started(start_options)

      assert_called(DynamicSupervisor.terminate_child(Valkyrie.Dynamic.Supervisor, first_pid))
    end
  end
end
