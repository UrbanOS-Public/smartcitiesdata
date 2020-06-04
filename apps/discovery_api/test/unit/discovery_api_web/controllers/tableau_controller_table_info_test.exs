defmodule DiscoveryApiWeb.TableauControllerTableInfoTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Model
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  alias DiscoveryApi.Test.Helper

  describe "fetch tableau table info" do
    setup do
      DiscoveryApi.Data.TableInfoCache.invalidate()

      mock_dataset_summaries = [
        generate_model("csvstream", ~D(1970-01-01), "stream"),
        generate_model("csv", ~D(2001-09-09), "ingest"),
        generate_model("json", ~D(2091-09-15), "ingest", ["JSON"], false),
        generate_model("geojson", ~D(2091-09-15), "ingest", ["GEOJSON"], false),
        generate_model("private", ~D(2091-09-15), "ingest", ["CSV", "JSON"], true),
        generate_model("remote", ~D(1970-01-01), "remote"),
        generate_model("host", ~D(2091-09-15), "host")
      ]

      allow(Model.get_all(), return: mock_dataset_summaries, meck_options: [:passthrough])
      allow(ModelAccessUtils.has_access?(%{id: "private"}, any()), return: false)
      allow(ModelAccessUtils.has_access?(any(), any()), return: true)

      response = build_conn() |> get("api/v1/tableau/table_info") |> json_response(200)

      model_ids =
        response
        |> Enum.map(&Map.get(&1, "id"))

      {:ok, %{response: response, model_ids: model_ids}}
    end

    test "returns only models with csv or geojson as an available file type", %{model_ids: model_ids} do
      assert "csv" in model_ids
      assert "csvstream" in model_ids
      assert "json" not in model_ids
      assert "geojson" in model_ids
    end

    test "returns only datasets the user is authorized to view", %{model_ids: model_ids} do
      assert "private" not in model_ids
    end

    test "returns only api-accessible datasets", %{model_ids: model_ids} do
      assert "remote" not in model_ids
      assert "host" not in model_ids
    end

    test "returns models as tableinfos", %{response: response} do
      keys = response |> List.first() |> Map.keys()

      assert keys == ["alias", "columns", "description", "id"]
    end

    test "table info is cached" do
      build_conn() |> get("api/v1/tableau/table_info") |> json_response(200)

      assert_called Model.get_all(), once()
    end

    test "table info is cached per user" do
      allow(DiscoveryApiWeb.AuthTokens.Guardian.Plug.current_resource(any()), return: %{subject_id: "bob123"}, meck_options: [:passthrough])
      build_conn() |> get("api/v1/tableau/table_info") |> json_response(200)
      build_conn() |> get("api/v1/tableau/table_info") |> json_response(200)

      assert_called Model.get_all(), times(2)
    end
  end

  defp generate_model(id, date, sourceType, fileTypes \\ ["CSV"], is_private \\ false) do
    Helper.sample_model(%{
      description: "#{id}-description",
      fileTypes: fileTypes,
      id: id,
      name: "#{id}-name",
      title: "#{id}-title",
      modifiedDate: "#{date}",
      organization: "#{id} Co.",
      keywords: ["#{id} keywords"],
      sourceType: sourceType,
      organizationDetails: %{
        orgTitle: "#{id}-org-title",
        orgName: "#{id}-org-name",
        logoUrl: "#{id}-org.png"
      },
      private: is_private
    })
  end
end
