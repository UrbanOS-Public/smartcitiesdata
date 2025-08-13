defmodule DiscoveryApi.Data.CachePopulatorTest do
  @moduledoc false
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  alias DiscoveryApi.Test.Helper

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.Data.CachePopulator
  alias DiscoveryApi.Data.SystemNameCache

  @instance_name DiscoveryApi.instance_name()

  describe "init/1" do
    test "Populates the cache with existing view state models" do
      Helper.clear_saved_models()

      organization = %{} |> TDG.create_organization()

      model =
        Helper.sample_model(%{
          title: "Bob is the man",
          organizationDetails: organization |> Map.from_struct()
        })

      Brook.Test.with_event(@instance_name, fn ->
        Brook.ViewState.merge(:models, model.id, model)
      end)

      start_supervised!(CachePopulator)

      SmartCity.TestHelper.eventually(fn ->
        assert SystemNameCache.get(organization.orgName, model.name) == model.id
      end)
    end
  end
end
