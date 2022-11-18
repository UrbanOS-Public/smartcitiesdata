defmodule AndiWeb.EditLiveView.CuratorDataDictionaryFieldEditorTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  import Phoenix.LiveViewTest
  import Checkov

  @moduletag shared_data_connection: true

  alias IngestionHelpers

  import FlokiHelpers,
    only: [
      get_attributes: 3
    ]

  @ingestions_url_path "/ingestions/"

  test "xml selector is *disabled* when source type is *not* xml", %{conn: conn} do
    {:ok, ingestion} =
      IngestionHelpers.create_ingestion(%{sourceFormat: "text/csv"})
      |> IngestionHelpers.save_ingestion()

    {:ok, _view, html} = live(conn, @ingestions_url_path <> ingestion.id)

    refute Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__selector", "disabled"))
  end

  test "xml selector is *enabled* when source type *is* xml", %{conn: conn} do
    {:ok, ingestion} =
      IngestionHelpers.create_ingestion(%{sourceFormat: "text/xml"})
      |> IngestionHelpers.save_ingestion()

    {:ok, _view, html} = live(conn, @ingestions_url_path <> ingestion.id)

    assert Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__selector", "disabled"))
  end
end
