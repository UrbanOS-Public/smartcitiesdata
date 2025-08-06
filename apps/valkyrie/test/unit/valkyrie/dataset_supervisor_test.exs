defmodule Valkyrie.DatasetSupervisorTest do
  use ExUnit.Case
  import Mock

  alias Valkyrie.DatasetSupervisor
  alias SmartCity.TestDataGenerator, as: TDG

  describe "ensure_started/1" do
    setup %{} do
      dataset = TDG.create_dataset(%{})

      start_options = [
        dataset: dataset,
        input_topic: "input_topic",
        output_topic: "output_topic"
      ]

      %{start_options: start_options, dataset: dataset}
    end

    test "should start dataset process", %{start_options: start_options} do
      with_mock(DynamicSupervisor, 
        start_child: fn _, _ -> Agent.start(fn -> 36 end, name: :"#{Keyword.get(start_options, :dataset).id}_supervisor") end
      ) do
        DatasetSupervisor.ensure_started(start_options)

        assert_called DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options})
      end
    end

    test "should not restart a running dataset process", %{start_options: start_options} do
      with_mock(DynamicSupervisor,
        start_child: fn _, _ -> Agent.start(fn -> 36 end, name: :"#{Keyword.get(start_options, :dataset).id}_supervisor") end
      ) do
        {:ok, first_pid} = DatasetSupervisor.ensure_started(start_options)

        assert {:ok, ^first_pid} = DatasetSupervisor.ensure_started(start_options)

        assert_called_exactly(DynamicSupervisor.start_child(Valkyrie.Dynamic.Supervisor, {Valkyrie.DatasetSupervisor, start_options}), 1)
      end
    end
  end
end
