defmodule Valkyrie.DatasetSupervisorTest do
  use ExUnit.Case
  use Placebo

  alias Valkyrie.DatasetSupervisor
  alias SmartCity.TestDataGenerator, as: TDG

  describe "ensure_started/1" do
    setup %{} do
      dataset = TDG.create_dataset(%{})

      allow(DynamicSupervisor.start_child(any(), any()),
        exec: fn _, _ -> Agent.start(fn -> 36 end, name: :"#{dataset.id}_supervisor") end,
        meck_options: [:passthrough]
      )

      start_options = [
        dataset: dataset,
        input_topic: "input_topic",
        output_topic: "output_topic"
      ]

      %{start_options: start_options}
    end

    test "should start dataset process", %{start_options: start_options} do
      DatasetSupervisor.ensure_started(start_options)

      assert_called(
        DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})
      )
    end

    test "should not restart a running dataset process", %{start_options: start_options} do
      {:ok, first_pid} = DatasetSupervisor.ensure_started(start_options)

      assert {:ok, ^first_pid} = DatasetSupervisor.ensure_started(start_options)

      assert_called(
        DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options}),
        once()
      )
    end
  end
end