defmodule DiscoveryApiWeb.MultipleMetadataController.TableInfoTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Data.Model
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  alias DiscoveryApi.Test.Helper

  describe "fetch tableau table info" do
    test "returns only models with csv or geojson as an available file type" , %{conn: conn}do
      mock_dataset_summaries = [
        generate_model("Paul", ~D(1970-01-01), "stream"),
        generate_model("Richard", ~D(2001-09-09), "ingest"),
        generate_model("Cam", ~D(2091-09-15), "ingest", ["json"], false),
        generate_model("Spongebob", ~D(2091-09-15), "ingest", ["geojson"], false)
      ]

      allow(Model.get_all(), return: mock_dataset_summaries, meck_options: [:passthrough])

      response = conn |> get("api/v1/dataset/tableau/tableinfo") |> json_response(200)

      model_ids =
        response
        |> Enum.map(&Map.get(&1, "id"))

      assert "paul" in model_ids
      assert "richard" in model_ids
      assert "cam" not in model_ids
      assert "spongebob" in model_ids
    end

    test "returns only datasets the user is authorized to view" , %{conn: conn}do
      mock_dataset_summaries = [
        generate_model("Paul", ~D(1970-01-01), "stream"),
        generate_model("Richard", ~D(2001-09-09), "ingest"),
        generate_model("Tim", ~D(2091-09-15), "ingest", ["csv", "json"], true)
      ]

      allow(Model.get_all(), return: mock_dataset_summaries, meck_options: [:passthrough])
      response = conn |> get("api/v1/dataset/tableau/tableinfo") |> json_response(200)

      allow(ModelAccessUtils.has_access?(%{id: "Tim"}, any()), return: false)
      allow(ModelAccessUtils.has_access?(any(), any()), return: true)

      model_ids =
        response
        |> Enum.map(&Map.get(&1, "id"))

      assert "paul" in model_ids
      assert "richard" in model_ids
      assert "tim" not in model_ids
    end

    test "returns only api-accessible datasets", %{conn: conn} do
      mock_dataset_summaries = [
        generate_model("Paul", ~D(1970-01-01), "remote"),
        generate_model("Richard", ~D(2001-09-09), "ingest"),
        generate_model("Cricket", ~D(2091-09-15), "host")
      ]

      allow(Model.get_all(), return: mock_dataset_summaries, meck_options: [:passthrough])
      allow(ModelAccessUtils.has_access?(any(), any()), return: true)

      response = conn |> get("api/v1/dataset/tableau/tableinfo") |> json_response(200)

      model_ids =
        response
        |> Enum.map(&Map.get(&1, "id"))

      assert "paul" not in model_ids
      assert "richard" in model_ids
      assert "cricket" not in model_ids
    end

    test "returns models as tableinfos", %{conn: conn} do
      mock_dataset_summaries = [
        generate_model("Richard", ~D(2001-09-09), "ingest")
      ]

      allow(Model.get_all(), return: mock_dataset_summaries, meck_options: [:passthrough])
      allow(ModelAccessUtils.has_access?(any(), any()), return: true)

      first_model = conn |> get("api/v1/dataset/tableau/tableinfo") |> json_response(200) |> List.first()

      assert Map.has_key?(first_model,  "id")
      assert Map.has_key?(first_model,  "description")
      assert Map.has_key?(first_model,  "alias")
      assert Map.has_key?(first_model,  "columns")
    end
  end

  defp generate_model(id, date, sourceType, fileTypes \\ ["csv"], is_private \\ false) do
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
