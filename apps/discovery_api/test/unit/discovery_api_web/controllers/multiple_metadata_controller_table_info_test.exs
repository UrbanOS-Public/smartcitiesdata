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

      allow(Model.get_all(), return: mock_dataset_summaries)

      response = conn |> get("api/v1/dataset/tableau/tableinfo") |> json_response(200)

      model_ids =
        response
        |> Map.get("results")
        |> Enum.map(&Map.get(&1, "id"))

      assert "Paul" in model_ids
      assert "Richard" in model_ids
      assert "Cam" not in model_ids
      assert "Spongebob" in model_ids
    end

    test "returns only datasets the user is authorized to view" , %{conn: conn}do
      mock_dataset_summaries = [
        generate_model("Paul", ~D(1970-01-01), "stream"),
        generate_model("Richard", ~D(2001-09-09), "ingest"),
        generate_model("Tim", ~D(2091-09-15), "ingest", ["csv", "json"], true)
      ]

      allow(Model.get_all(), return: mock_dataset_summaries)
      response = conn |> get("api/v1/dataset/tableau/tableinfo") |> json_response(200)

      allow(ModelAccessUtils.has_access?(%{id: "Tim"}, any()), return: false)
      allow(ModelAccessUtils.has_access?(any(), any()), return: true)

      model_ids =
        response
        |> Map.get("results")
        |> Enum.map(&Map.get(&1, "id"))

      assert "Paul" in model_ids
      assert "Richard" in model_ids
      assert "Tim" not in model_ids
    end

    test "returns only api-accessible datasets", %{conn: conn} do
      mock_dataset_summaries = [
        generate_model("Paul", ~D(1970-01-01), "remote"),
        generate_model("Richard", ~D(2001-09-09), "ingest"),
        generate_model("Cricket", ~D(2091-09-15), "host")
      ]

      allow(Model.get_all(), return: mock_dataset_summaries)
      allow(ModelAccessUtils.has_access?(any(), any()), return: true)

      response = conn |> get("api/v1/dataset/tableau/tableinfo") |> json_response(200)

      model_ids =
        response
        |> Map.get("results")
        |> Enum.map(&Map.get(&1, "id"))

      assert "Paul" not in model_ids
      assert "Richard" in model_ids
      assert "Cricket" not in model_ids
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
