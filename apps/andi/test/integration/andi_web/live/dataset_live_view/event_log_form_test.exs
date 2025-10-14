defmodule AndiWeb.EventLogFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  import Checkov

  alias Andi.Services.DatasetStore

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.Event
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]
  import FlokiHelpers

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.EventLogs
  alias Andi.Schemas.AuditEvent
  alias Andi.Schemas.AuditEvents

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  setup %{curator_subject: curator_subject, public_subject: public_subject} do
    {:ok, curator} = Andi.Schemas.User.create_or_update(curator_subject, %{email: "bob@example.com", name: "Bob"})
    {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com", name: "Bob"})
    [curator: curator, public_user: public_user]
  end

  describe "Event Log Form" do
    test "Event Log Form can be expanded", %{curator_conn: conn, curator: curator} do
      dataset = Datasets.create(curator)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      event_log_view = find_live_child(view, "event_log_form")
      html = render(event_log_view)

      assert element(view, ".component-edit-section--collapsed")
             |> has_element?()

      event_log_view
      |> element("#event_log .component-header")
      |> render_click()

      assert element(view, ".component-edit-section--expanded")
             |> has_element?()
    end

    test "Event Log Form shows empty table when there are no event logs", %{curator_conn: conn, curator: curator} do
      dataset = Datasets.create(curator)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      event_log_view = find_live_child(view, "event_log_form")
      html = render(event_log_view)

      event_log_view
      |> element("#event_log .component-header")
      |> render_click()

      table_headings = get_texts(html, ".datasets-table .datasets-table__th")

      assert find_elements(html, ".datasets-table__tr .datasets-table__cell") |> Enum.count() == 0

      assert Enum.member?(table_headings, "Timestamp")
      assert Enum.member?(table_headings, "Source")
      assert Enum.member?(table_headings, "Title")
      assert Enum.member?(table_headings, "Dataset ID")
      assert Enum.member?(table_headings, "Ingestion ID")
      assert Enum.member?(table_headings, "Description")
    end

    test "Event Log Form shows populated row for each event log", %{curator_conn: conn, curator: curator} do
      dataset = Datasets.create(curator)
      timestamp = ~U[2023-01-01 00:00:00Z]
      timestamp2 = ~U[2023-01-01 00:00:01Z]

      # Insert actual event logs into the database
      event_log_1 = %SmartCity.EventLog{
        dataset_id: dataset.id,
        description: "testDescription",
        ingestion_id: "testIngestionId",
        source: "testSource",
        timestamp: DateTime.to_iso8601(timestamp),
        title: "testTitle"
      }

      event_log_2 = %SmartCity.EventLog{
        dataset_id: dataset.id,
        description: "testDescription2",
        ingestion_id: "testIngestionId2",
        source: "testSource2",
        timestamp: DateTime.to_iso8601(timestamp2),
        title: "testTitle2"
      }

      {:ok, _} = EventLogs.update(event_log_1)
      {:ok, _} = EventLogs.update(event_log_2)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      event_log_view = find_live_child(view, "event_log_form")
      html = render(event_log_view)

      event_log_view
      |> element("#event_log .component-header")
      |> render_click()

      row_values = get_texts(html, ".datasets-table__tr .datasets-table__cell")

      assert find_elements(html, ".datasets-table__tr .datasets-table__cell") |> Enum.count() == 12

      assert Enum.member?(row_values, "testTitle")
      assert Enum.member?(row_values, "testSource")
      assert Enum.member?(row_values, dataset.id)
      assert Enum.member?(row_values, "testIngestionId")
      assert Enum.member?(row_values, DateTime.to_string(timestamp))
      assert Enum.member?(row_values, "testDescription")

      assert Enum.member?(row_values, "testTitle2")
      assert Enum.member?(row_values, "testSource2")
      assert Enum.member?(row_values, dataset.id)
      assert Enum.member?(row_values, "testIngestionId2")
      assert Enum.member?(row_values, DateTime.to_string(timestamp2))
      assert Enum.member?(row_values, "testDescription2")
    end
  end
end
