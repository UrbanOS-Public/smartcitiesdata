defmodule DiscoveryApi.Data.DatasetEventListenerTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.{DatasetEventListener, Model, SystemNameCache}
  alias SmartCity.Organization
  alias SmartCity.TestDataGenerator, as: TDG

  describe "handle_dataset/1" do
    test "should return :ok when successful" do
      dataset = TDG.create_dataset(%{id: "123"})
      organization = TDG.create_organization(%{id: dataset.technical.orgId})

      allow(Organization.get(dataset.technical.orgId), return: {:ok, organization})
      allow(Model.save(any()), return: {:ok, :success})

      assert :ok == DatasetEventListener.handle_dataset(dataset)
    end

    @tag capture_log: true
    test "should return :ok and log when organization get fails" do
      dataset = TDG.create_dataset(%{id: "123"})

      allow(Organization.get(dataset.technical.orgId), return: {:error, :failure})

      assert :ok == DatasetEventListener.handle_dataset(dataset)
    end

    @tag capture_log: true
    test "should return :ok and log when system cache put fails" do
      dataset = TDG.create_dataset(%{id: "123"})
      organization = TDG.create_organization(%{id: dataset.technical.orgId})

      allow(Organization.get(dataset.technical.orgId), return: {:ok, organization})
      allow(SystemNameCache.put(any(), any()), return: {:error, :failure})

      assert :ok == DatasetEventListener.handle_dataset(dataset)
    end

    @tag capture_log: true
    test "should return :ok and log when model save fails" do
      dataset = TDG.create_dataset(%{id: "123"})
      organization = TDG.create_organization(%{id: dataset.technical.orgId})

      allow(Organization.get(dataset.technical.orgId), return: {:ok, organization})
      allow(SystemNameCache.put(any(), any()), return: {:ok, :cached})
      allow(Model.save(any()), return: {:error, :failure})

      assert :ok == DatasetEventListener.handle_dataset(dataset)
    end

    test "creates orgName/dataName mapping to dataset_id" do
      dataset = TDG.create_dataset(%{id: "123"})
      organization = TDG.create_organization(%{id: dataset.technical.orgId})

      allow Organization.get(organization.id), return: {:ok, organization}
      allow(Model.save(any()), return: {:ok, :success})

      DatasetEventListener.handle_dataset(dataset)

      assert SystemNameCache.get(organization.orgName, dataset.technical.dataName) == "123"
    end
  end
end
