defmodule AndiWeb.DatasetLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.ConnCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_text: 2,
      get_value: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [data_ingest_end: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Andi.InputSchemas.Datasets

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets"

  describe "dataset status" do
    test "is empty if the dataset has not been ingested", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)

      assert {:ok, view, html} = live(conn, @url_path)

      assert andi_dataset.dlq_message == nil
      table_row = get_dataset_table_row(html, dataset)
      {_, _, row_children} = table_row

      {_, _, status} = row_children |> List.first()

      assert Enum.empty?(status)
    end

    test "shows success when there is no dlq message stored for a dataset", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, andi_dataset} = Datasets.update(dataset)
      current_time = DateTime.utc_now()
      Datasets.update_ingested_time(dataset.id, current_time)

      assert {:ok, view, html} = live(conn, @url_path)

      assert andi_dataset.dlq_message == nil
      table_row = get_dataset_table_row(html, dataset)

      refute Enum.empty?(Floki.find(table_row, ".datasets-table__ingested-cell--success"))
    end

    test "shows failure when there is a dlq message stored for a dataset", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, _} = Datasets.update(dataset)
      current_time = DateTime.utc_now()
      Datasets.update_ingested_time(dataset.id, current_time)

      dlq_time = DateTime.utc_now() |> Timex.shift(days: -3) |> DateTime.to_iso8601()
      dlq_message = %{"dataset_id" => dataset.id, "timestamp" => dlq_time}
      Datasets.update_latest_dlq_message(dlq_message)

      assert {:ok, view, html} = live(conn, @url_path)
      table_row = get_dataset_table_row(html, dataset)

      refute Enum.empty?(Floki.find(table_row, ".datasets-table__ingested-cell--failure"))
    end

    test "shows success when the latest dlq meessage is older than seven days", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      {:ok, _} = Datasets.update(dataset)
      current_time = DateTime.utc_now()
      Datasets.update_ingested_time(dataset.id, current_time)

      old_time = current_time |> Timex.shift(days: -8) |> DateTime.to_iso8601()
      dlq_message = %{"dataset_id" => dataset.id, "timestamp" => old_time}
      Datasets.update_latest_dlq_message(dlq_message)

      eventually(fn ->
        assert %{"dataset_id" => dataset.id, "timestamp" => old_time} == Datasets.get(dataset.id) |> Map.get(:dlq_message)
      end)

      assert {:ok, view, html} = live(conn, @url_path)
      table_row = get_dataset_table_row(html, dataset)

      refute Enum.empty?(Floki.find(table_row, ".datasets-table__ingested-cell--success"))
    end
  end

  test "add dataset button creates a dataset with a default dataTitle and dataName", %{conn: conn} do
    assert {:ok, view, _html} = live(conn, @url_path)

    {:error, {:live_redirect, %{kind: :push, to: edit_page}}} = render_click(view, "add-dataset")

    assert {:ok, view, html} = live(conn, edit_page)
    metadata_view = find_child(view, "metadata_form_editor")

    assert "New Dataset - #{Date.utc_today()}" == get_value(html, "#form_data_dataTitle")

    assert "new_dataset_#{Date.utc_today() |> to_string() |> String.replace("-", "", global: true)}" ==
             get_value(html, "#form_data_dataName")

    html = render_change(metadata_view, :save)

    refute Enum.empty?(find_elements(html, "#orgId-error-msg"))
  end

  defp get_dataset_table_row(html, dataset) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find(".datasets-table__tr")
    |> Enum.reduce_while([], fn row, _acc ->
      {_, _, children} = row

      [{_, _, [row_title]}] =
        children
        |> Floki.find(".datasets-table__data-title-cell")

      case dataset.business.dataTitle == row_title do
        true -> {:halt, row}
        false -> {:cont, []}
      end
    end)
  end
end
