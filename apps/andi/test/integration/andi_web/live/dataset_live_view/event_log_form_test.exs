defmodule AndiWeb.EventLogFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
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

      allow(Andi.InputSchemas.EventLogs.get_all_for_dataset_id(dataset.id), return: [])
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

      allow(Andi.InputSchemas.EventLogs.get_all_for_dataset_id(dataset.id), return: [])
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

      event_logs = [
        %{
          dataset_id: "testDatasetId",
          description: "testDescription",
          ingestion_id: "testIngestionId",
          source: "testSource",
          timestamp: ~U[2023-01-01 00:00:00Z],
          title: "testTitle"
        },
        %{
          dataset_id: "testDatasetId2",
          description: "testDescription2",
          ingestion_id: "testIngestionId2",
          source: "testSource2",
          timestamp: ~U[2023-01-01 00:00:00Z],
          title: "testTitle2"
        }
      ]

      allow(Andi.InputSchemas.EventLogs.get_all_with_limit_for_dataset_id(dataset.id, 50), return: event_logs)
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
      assert Enum.member?(row_values, "testDatasetId")
      assert Enum.member?(row_values, "testIngestionId")
      assert Enum.member?(row_values, "testTimestamp")
      assert Enum.member?(row_values, "testTitle")

      assert Enum.member?(row_values, "testTitle2")
      assert Enum.member?(row_values, "testSource2")
      assert Enum.member?(row_values, "testDatasetId2")
      assert Enum.member?(row_values, "testIngestionId2")
      assert Enum.member?(row_values, "testTimestamp2")
      assert Enum.member?(row_values, "testTitle2")
    end
  end
end
