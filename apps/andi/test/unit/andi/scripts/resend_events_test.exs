defmodule Andi.Scripts.ResendEventsTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA

  import SmartCity.Event
  
  @moduletag timeout: 5000

  describe "resend_dataset_events/0" do
    setup do
      # Set up :meck for modules that will be mocked
      modules_to_mock = [DatasetStore, Brook.Event]
      
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
      
      :ok
    end
    
    test "resends all datasets in the DatasetStore as dataset:update events in Brook" do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})
      expected_datasets = {:ok, [dataset1, dataset2]}

      # Set up expectations for this test
      :meck.expect(DatasetStore, :get_all, fn -> expected_datasets end)
      :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)
      
      Andi.Scripts.ResendEvents.resend_dataset_events()

      # Verify calls were made with expected arguments
      assert :meck.called(Brook.Event, :send, [:andi, dataset_update(), :data_migrator, dataset1])
      assert :meck.called(Brook.Event, :send, [:andi, dataset_update(), :data_migrator, dataset2])
    end
  end

  describe "resend_user_org_assoc_events/0" do
    setup do
      # Set up :meck for modules that will be mocked
      modules_to_mock = [User, Brook.Event]
      
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
      
      :ok
    end
    
    test "resends all user-organization associations in the DatasetStore as dataset:update events in Brook" do
      users = [
        %Andi.Schemas.User{
          email: "sample@accenture.com",
          organizations: [
            %Andi.InputSchemas.Organization{
              id: "1"
            },
            %Andi.InputSchemas.Organization{
              id: "2"
            }
          ],
          subject_id: "auth0|1"
        },
        %Andi.Schemas.User{
          email: "sample@accenture.com",
          organizations: [
            %Andi.InputSchemas.Organization{
              id: "3"
            },
            %Andi.InputSchemas.Organization{
              id: "4"
            }
          ],
          subject_id: "auth0|2"
        },
        %Andi.Schemas.User{
          email: "sample@accenture.com",
          organizations: [],
          subject_id: "auth0|3"
        }
      ]

      # Set up expectations for this test
      :meck.expect(User, :get_all, fn -> users end)
      :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)
      
      Andi.Scripts.ResendEvents.resend_user_org_assoc_events()

      # Verify calls were made with expected arguments
      assert :meck.called(Brook.Event, :send, [:andi, user_organization_associate(), :data_migrator, %UOA{
                      email: "sample@accenture.com",
                      org_id: "1",
                      subject_id: "auth0|1"
                    }])

      assert :meck.called(Brook.Event, :send, [:andi, user_organization_associate(), :data_migrator, %UOA{
                      email: "sample@accenture.com",
                      org_id: "2",
                      subject_id: "auth0|1"
                    }])

      assert :meck.called(Brook.Event, :send, [:andi, user_organization_associate(), :data_migrator, %UOA{
                      email: "sample@accenture.com",
                      org_id: "3",
                      subject_id: "auth0|2"
                    }])

      assert :meck.called(Brook.Event, :send, [:andi, user_organization_associate(), :data_migrator, %UOA{
                      email: "sample@accenture.com",
                      org_id: "4",
                      subject_id: "auth0|2"
                    }])
    end
  end
end
