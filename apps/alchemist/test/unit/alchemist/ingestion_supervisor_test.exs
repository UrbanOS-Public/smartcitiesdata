defmodule Alchemist.IngestionSupervisorTest do
  use ExUnit.Case
  use Placebo

  alias Alchemist.IngestionSupervisor
  alias SmartCity.TestDataGenerator, as: TDG

  describe "ensure_started/1" do
    setup %{} do
      ingestion = TDG.create_ingestion(%{})

      allow(DynamicSupervisor.start_child(any(), any()),
        exec: fn _, _ -> Agent.start(fn -> 36 end, name: :"#{ingestion.id}_supervisor") end,
        meck_options: [:passthrough]
      )

      start_options = [
        ingestion: ingestion,
        input_topic: "input_topic",
        output_topics: "output_topics"
      ]

      %{start_options: start_options}
    end

    test "should start ingestion process", %{start_options: start_options} do
      IngestionSupervisor.ensure_started(start_options)

      assert_called(
        DynamicSupervisor.start_child(Alchemist.Dynamic.Supervisor, {Alchemist.IngestionSupervisor, start_options})
      )
    end

    test "should not restart a running ingestion process", %{start_options: start_options} do
      {:ok, first_pid} = IngestionSupervisor.ensure_started(start_options)

      assert {:ok, ^first_pid} = IngestionSupervisor.ensure_started(start_options)

      assert_called(
        DynamicSupervisor.start_child(Alchemist.Dynamic.Supervisor, {Alchemist.IngestionSupervisor, start_options}),
        once()
      )
    end
  end
end
