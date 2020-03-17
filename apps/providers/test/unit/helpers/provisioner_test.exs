defmodule TestStruct do
  defstruct name: nil, age: nil
end

defmodule Providers.Helpers.ProvisionerTest do
  use ExUnit.Case
  import Mox

  alias Provider.Exceptions

  @moduletag capture_log: true
  describe "successful provisioning" do
    setup do
      Providers.Echo
      |> stub(:provide, fn _, %{value: value} -> value end)

      :ok
    end

    test "provisions a map with a single provider" do
      map = %{
        id: "bob",
        title: %{
          provider: "Echo",
          opts: %{value: "Mr. President"},
          version: "1"
        }
      }

      provisioned_map = Providers.Helpers.Provisioner.provision(map)

      assert provisioned_map[:title] == "Mr. President"
    end

    test "provisions a map with multiple providers" do
      map = %{
        id: "bob",
        title: %{
          provider: "Echo",
          opts: %{value: "Assistant Manager"},
          version: "1"
        },
        rank: %{
          provider: "Echo",
          opts: %{value: "Assistant to the Manager"},
          version: "1"
        }
      }

      provisioned_map = Providers.Helpers.Provisioner.provision(map)

      assert provisioned_map[:title] == "Assistant Manager"
      assert provisioned_map[:rank] == "Assistant to the Manager"
    end

    test "provisions a struct" do
      struct = %TestStruct{
        name: %{
          provider: "Echo",
          opts: %{value: "Freddy"},
          version: "1"
        },
        age: 25
      }

      %module{} = provisioned_map = Providers.Helpers.Provisioner.provision(struct)

      assert provisioned_map.name == "Freddy"
      assert module == TestStruct
    end

    test "provisions a map with providers at different levels" do
      map = %{
        id: "bob",
        title: %{
          provider: "Echo",
          opts: %{value: "Assistant Sales Rep"},
          version: "1"
        },
        department: %{
          name: "Sales",
          type: %{
            provider: "Echo",
            opts: %{value: "Supremely Important"},
            version: "1"
          }
        }
      }

      provisioned_map = Providers.Helpers.Provisioner.provision(map)

      assert provisioned_map[:title] == "Assistant Sales Rep"

      assert provisioned_map[:department] == %{
               name: "Sales",
               type: "Supremely Important"
             }
    end

    test "provisions a map with providers in a list" do
      map = %{
        resources: [
          %{
            provider: "Echo",
            opts: %{value: "Kelly"},
            version: "1"
          },
          %{
            provider: "Echo",
            opts: %{value: "Amin"},
            version: "1"
          },
          "Bob"
        ]
      }

      provisioned_map = Providers.Helpers.Provisioner.provision(map)

      assert provisioned_map[:resources] == ["Kelly", "Amin", "Bob"]
    end

    test "provisions a map with a list of maps with providers" do
      map = %{
        resources: [
          %{
            name: %{
              provider: "Echo",
              opts: %{value: "Kelly"},
              version: "1"
            },
            title: %{
              provider: "Echo",
              opts: %{value: "Rep class 3"},
              version: "1"
            }
          },
          %{
            name: %{
              provider: "Echo",
              opts: %{value: "Robin"},
              version: "1"
            },
            title: "Rep class 4"
          }
        ]
      }

      provisioned_map = Providers.Helpers.Provisioner.provision(map)

      assert provisioned_map[:resources] == [
               %{name: "Kelly", title: "Rep class 3"},
               %{name: "Robin", title: "Rep class 4"}
             ]
    end
  end

  describe "failed provisioning" do
    test "fails to provision a map if the provider does not exist" do
      map = %{
        id: "bob",
        title: %{
          provider: "ThisProviderDoesNotExist",
          opts: %{},
          version: "1"
        }
      }

      assert_raise Exceptions.ProviderNotFound,
                   "Could not find Providers.ThisProviderDoesNotExist",
                   fn ->
                     Providers.Helpers.Provisioner.provision(map)
                   end
    end

    test "fails to provision a map if a provider fails to execute" do
      Providers.ExceptionTest
      |> expect(:provide, 1, fn _, _ -> raise ArgumentError, message: "This is real bad" end)

      map = %{
        id: "bob",
        title: %{
          provider: "ExceptionTest",
          opts: %{},
          version: "1"
        }
      }

      assert_raise Exceptions.ProviderError,
                   ~r/Provider ExceptionTest at version 1 encountered an error: This is real bad/,
                   fn ->
                     Providers.Helpers.Provisioner.provision(map)
                   end
    end
  end
end
