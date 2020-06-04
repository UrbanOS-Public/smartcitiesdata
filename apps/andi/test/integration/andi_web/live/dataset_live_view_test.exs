defmodule AndiWeb.DatasetLiveViewTest do
  use ExUnit.Case
  use Divo
  use Andi.DataCase
  use AndiWeb.ConnCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [data_ingest_end: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.InputSchemas.Datasets

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"

  test "data_ingest_end events updates ingested time", %{conn: conn} do
    dataset = TDG.create_dataset(%{technical: %{schema: [%{name: "cam", type: "string"}]}})

    {:ok, _andi_dataset} = Datasets.update(dataset)

    assert {:ok, view, _html} = live(conn, @url_path)

    table_text = get_text(render(view), ".datasets-index__table")
    assert not (table_text =~ "check")

    Brook.Test.send(instance_name(), data_ingest_end(), :andi, dataset)

    eventually(fn ->
      table_text = get_text(render(view), ".datasets-index__table")
      assert table_text =~ "check"
    end)
  end

  test "data_ingest_end events does not change dataset order", %{conn: conn} do
    datasets =
      Enum.map(1..3, fn _x ->
        dataset = TDG.create_dataset(%{technical: %{schema: [%{name: "cam", type: "string"}]}})

        {:ok, _andi_dataset} = Datasets.update(dataset)

        dataset
      end)

    dataset = Enum.at(datasets, 1)

    assert {:ok, view, _html} = live(conn, @url_path)
    initial_table_text = get_text(render(view), ".datasets-index__table")

    Brook.Test.send(instance_name(), data_ingest_end(), :andi, dataset)

    eventually(fn ->
      table_text = get_text(render(view), ".datasets-index__table")
      assert table_text =~ "check"
      # If we remove the check that was added, is everything else the same?
      assert initial_table_text == String.replace(table_text, "check", "")
    end)
  end
end
