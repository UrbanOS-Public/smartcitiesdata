defmodule Andi.Scripts.ResendEventsTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Organizations
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA

  import SmartCity.Event

  @moduletag timeout: 5000

  describe "resend_dataset_events/0" do
    setup do
      # Set up :meck for modules that will be mocked
      modules_to_mock = [Datasets, InputConverter, Brook.Event]

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

    test "resends all published datasets in Postgres as dataset:update events in Brook" do
      andi_dataset1 = %Andi.InputSchemas.Datasets.Dataset{id: "dataset-1", submission_status: :published}
      andi_dataset2 = %Andi.InputSchemas.Datasets.Dataset{id: "dataset-2", submission_status: :published}
      smrt_dataset1 = TDG.create_dataset(%{id: "dataset-1"})
      smrt_dataset2 = TDG.create_dataset(%{id: "dataset-2"})

      # Set up expectations for this test
      :meck.expect(Datasets, :get_all, fn -> [andi_dataset1, andi_dataset2] end)

      :meck.expect(Datasets, :get, fn
        "dataset-1" -> andi_dataset1
        "dataset-2" -> andi_dataset2
      end)

      :meck.expect(InputConverter, :andi_dataset_to_smrt_dataset, fn
        ^andi_dataset1 -> {:ok, smrt_dataset1}
        ^andi_dataset2 -> {:ok, smrt_dataset2}
      end)

      :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)

      Andi.Scripts.ResendEvents.resend_dataset_events(0)

      # Verify calls were made with expected arguments
      assert :meck.called(Brook.Event, :send, [:andi, dataset_update(), :data_migrator, smrt_dataset1])
      assert :meck.called(Brook.Event, :send, [:andi, dataset_update(), :data_migrator, smrt_dataset2])
    end
  end

  describe "resend_all_events/0" do
    setup do
      modules_to_mock = [Organizations, User, Datasets, Ingestions, AccessGroups, Andi.Repo, Brook.Event]

      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          _, _ -> :ok
        end
      end)

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

    test "includes user-organization associations, not just orgs/datasets/ingestions/access groups" do
      user = %Andi.Schemas.User{
        email: "sample@accenture.com",
        organizations: [%Andi.InputSchemas.Organization{id: "1"}],
        subject_id: "auth0|1"
      }

      :meck.expect(Organizations, :get_all, fn -> [] end)
      :meck.expect(User, :get_all, fn -> [user] end)
      :meck.expect(Datasets, :get_all, fn -> [] end)
      :meck.expect(Ingestions, :get_all, fn -> [] end)
      :meck.expect(AccessGroups, :get_all, fn -> [] end)
      :meck.expect(Andi.Repo, :preload, fn _, _ -> [] end)
      :meck.expect(Brook.Event, :send, fn _, _, _, _ -> :ok end)

      Andi.Scripts.ResendEvents.resend_all_events()

      assert :meck.called(Brook.Event, :send, [
               :andi,
               user_organization_associate(),
               :data_migrator,
               %UOA{
                 email: "sample@accenture.com",
                 org_id: "1",
                 subject_id: "auth0|1"
               }
             ])
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
      assert :meck.called(Brook.Event, :send, [
               :andi,
               user_organization_associate(),
               :data_migrator,
               %UOA{
                 email: "sample@accenture.com",
                 org_id: "1",
                 subject_id: "auth0|1"
               }
             ])

      assert :meck.called(Brook.Event, :send, [
               :andi,
               user_organization_associate(),
               :data_migrator,
               %UOA{
                 email: "sample@accenture.com",
                 org_id: "2",
                 subject_id: "auth0|1"
               }
             ])

      assert :meck.called(Brook.Event, :send, [
               :andi,
               user_organization_associate(),
               :data_migrator,
               %UOA{
                 email: "sample@accenture.com",
                 org_id: "3",
                 subject_id: "auth0|2"
               }
             ])

      assert :meck.called(Brook.Event, :send, [
               :andi,
               user_organization_associate(),
               :data_migrator,
               %UOA{
                 email: "sample@accenture.com",
                 org_id: "4",
                 subject_id: "auth0|2"
               }
             ])
    end
  end
end
