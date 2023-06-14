defmodule Andi.Scripts.ResendEventsTest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA

  import SmartCity.Event
  import Mock

  describe "resend_dataset_events/0" do
    test "resends all datasets in the DatasetStore as dataset:update events in Brook" do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})
      expected_datasets = {:ok, [dataset1, dataset2]}

      with_mocks([
        {DatasetStore, [], [get_all: fn() -> expected_datasets end]},
        {Brook.Event, [], [send: fn(_, _, _, _) -> :ok end]}
      ]) do
        Andi.Scripts.ResendEvents.resend_dataset_events()

        assert_called Brook.Event.send(:andi, dataset_update(), :data_migrator, dataset1)
        assert_called Brook.Event.send(:andi, dataset_update(), :data_migrator, dataset2)
      end
    end
  end

  describe "resend_user_org_assoc_events/0" do
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

      with_mocks([
        {User, [], [get_all: fn() -> users end]},
        {Brook.Event, [], [send: fn(_, _, _, _) -> :ok end]}
      ]) do
        Andi.Scripts.ResendEvents.resend_user_org_assoc_events()

        assert_called Brook.Event.send(:andi, user_organization_associate(), :data_migrator, %UOA{
                        email: "sample@accenture.com",
                        org_id: "1",
                        subject_id: "auth0|1"
                      })

        assert_called Brook.Event.send(:andi, user_organization_associate(), :data_migrator, %UOA{
                        email: "sample@accenture.com",
                        org_id: "2",
                        subject_id: "auth0|1"
                      })

        assert_called Brook.Event.send(:andi, user_organization_associate(), :data_migrator, %UOA{
                        email: "sample@accenture.com",
                        org_id: "3",
                        subject_id: "auth0|2"
                      })

        assert_called Brook.Event.send(:andi, user_organization_associate(), :data_migrator, %UOA{
                        email: "sample@accenture.com",
                        org_id: "4",
                        subject_id: "auth0|2"
                      })
      end
    end
  end
end
