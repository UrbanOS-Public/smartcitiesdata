defmodule Andi.Harvest.HarvesterTest do
  use ExUnit.Case

  alias Andi.Harvest.Harvester
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.Event, only: [dataset_update: 0, dataset_harvest_end: 0, dataset_harvest_start: 0]

  @moduletag timeout: 5000
  @instance_name Andi.instance_name()

  describe "data json harvester" do
    setup do
      # Set up :meck for modules that will be mocked across tests
      modules_to_mock = [Brook.Event, OrgStore, Organizations]
      
      # Clean up any existing mocks first
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)
      
      # Set up fresh mocks
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.new(module, [:passthrough])
        catch
          :error, {:already_started, _} -> :ok
        end
      end)
      
      on_exit(fn ->
        Enum.each(modules_to_mock, fn module ->
          try do
            :meck.unload(module)
          catch
            _, _ -> :ok
          end
        end)
      end)
      
      data_json = get_schema_from_path("./test/integration/schemas/data_json.json")
      org = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title", id: "95254592-d611-4bcb-9478-7fa248f4118d"})
      bypass = Bypass.open()
      %{data_json: data_json, org: org, bypass: bypass}
    end

    test "start_harvesting/0 when orgs with dataJsonUrls are in the system" do
      org_1 =
        TDG.create_organization(%{
          orgTitle: "Awesome Title",
          orgName: "awesome_title",
          id: "95254592-d611-4bcb-9478-7fa248f4118d",
          dataJsonUrl: "http://www.google.com"
        })

      # Set up expectations for this test
      :meck.expect(Brook.Event, :send, fn @instance_name, dataset_harvest_start(), :andi, _ -> :ok end)
      :meck.expect(OrgStore, :get_all, fn -> {:ok, [org_1]} end)
      :meck.expect(Organizations, :get_harvested_dataset, fn _ -> %{include: true} end)
      
      Harvester.start_harvesting()

      # Verify calls were made
      assert :meck.num_calls(Brook.Event, :send, 4) == 1
    end

    test "start_harvesting/0 when orgs without dataJsonUrls are in the system" do
      org_1 =
        TDG.create_organization(%{
          orgTitle: "Awesome Title",
          orgName: "awesome_title",
          id: "95254592-d611-4bcb-9478-7fa248f4118d",
          dataJsonUrl: nil
        })

      # Set up expectations for this test
      :meck.expect(Brook.Event, :send, fn @instance_name, dataset_harvest_start(), :andi, _ -> :ok end)
      :meck.expect(OrgStore, :get_all, fn -> [org_1] end)
      
      Harvester.start_harvesting()

      # Verify no calls were made (org has nil dataJsonUrl)
      assert :meck.num_calls(Brook.Event, :send, 4) == 0
    end

    test "get_data_json/1", %{data_json: data_json, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      {:ok, actual} = Jason.decode(data_json)
      resp = Harvester.get_data_json("http://localhost:#{bypass.port()}/data.json") |> elem(1) |> Jason.decode!()

      assert resp == actual
    end

    test "get_data_json/1 handles non existent urls" do
      assert {:error, _err_text} = Harvester.get_data_json("")
    end

    test "map_data_json_to_dataset/2", %{data_json: data_json, org: org} do
      {:ok, data_json} = Jason.decode(data_json)
      datasets = Harvester.map_data_json_to_dataset(data_json, org)
      assert length(datasets) == 3
    end

    test "map_data_json_to_harvested_dataset/2", %{data_json: data_json, org: org} do
      {:ok, data_json} = Jason.decode(data_json)
      harvested_datasets = Harvester.map_data_json_to_harvested_dataset(data_json, org)
      assert length(harvested_datasets) == 3
    end

    test "dataset_update/1", %{data_json: data_json, org: org} do
      # Set up expectations for this test
      :meck.expect(Brook.Event, :send, fn @instance_name, dataset_update(), :andi, _ -> :ok end)
      :meck.expect(Organizations, :get_harvested_dataset, fn _ -> %{include: true} end)
      
      {:ok, data_json} = Jason.decode(data_json)
      datasets = Harvester.map_data_json_to_dataset(data_json, org)

      Harvester.dataset_update(datasets)

      # Verify calls were made (3 datasets in test data)
      assert :meck.num_calls(Brook.Event, :send, 4) == 3
    end

    test "harvested_dataset_update/1", %{data_json: data_json, org: org} do
      # Set up expectations for this test
      :meck.expect(Brook.Event, :send, fn @instance_name, dataset_harvest_end(), :andi, _ -> :ok end)
      :meck.expect(Organizations, :get_harvested_dataset, fn _ -> %{include: true} end)
      
      {:ok, data_json} = Jason.decode(data_json)
      harvested_datasets = Harvester.map_data_json_to_harvested_dataset(data_json, org)

      Harvester.harvested_dataset_update(harvested_datasets)

      # Verify calls were made (3 datasets in test data)
      assert :meck.num_calls(Brook.Event, :send, 4) == 3
    end

    test "datasets without a modified date should be set to todays date", %{data_json: data_json, org: org} do
      {:ok, data_json} = Jason.decode(data_json)
      datasets = Harvester.map_data_json_to_dataset(data_json, org)

      [unmodified_dataset] = datasets |> Enum.filter(fn dataset -> dataset.id == "e13fc009-7ccd-511f-8895-a7c0c50b5b86" end)

      {:ok, date, _} = unmodified_dataset.business.modifiedDate |> DateTime.from_iso8601()
      current_date = DateTime.utc_now()

      assert date.day == current_date.day
    end
  end

  defp get_schema_from_path(path) do
    path
    |> File.read!()
  end
end
