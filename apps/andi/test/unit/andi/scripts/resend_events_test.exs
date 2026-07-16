defmodule Andi.Scripts.ResendEventsTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Organizations
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA
  import SmartCity.Event

  describe "resend_dataset_events/0" do
    test "resends all published datasets in Postgres as dataset:update events in Brook" do
      andi_dataset1 = %Andi.InputSchemas.Datasets.Dataset{id: "dataset-1", submission_status: :published}
      andi_dataset2 = %Andi.InputSchemas.Datasets.Dataset{id: "dataset-2", submission_status: :published}
      smrt_dataset1 = TDG.create_dataset(%{id: "dataset-1"})
      smrt_dataset2 = TDG.create_dataset(%{id: "dataset-2"})

      allow(Datasets.get_all(), return: [andi_dataset1, andi_dataset2])
      allow(Datasets.get("dataset-1"), return: andi_dataset1)
      allow(Datasets.get("dataset-2"), return: andi_dataset2)
      allow(InputConverter.andi_dataset_to_smrt_dataset(andi_dataset1), return: {:ok, smrt_dataset1})
      allow(InputConverter.andi_dataset_to_smrt_dataset(andi_dataset2), return: {:ok, smrt_dataset2})
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      Andi.Scripts.ResendEvents.resend_dataset_events(0)

      assert_called Brook.Event.send(:andi, dataset_update(), :data_migrator, smrt_dataset1)
      assert_called Brook.Event.send(:andi, dataset_update(), :data_migrator, smrt_dataset2)
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

      allow(User.get_all(), return: users)
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

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

  describe "resend_all_events/0" do
    test "includes user-organization associations, not just orgs/datasets/ingestions/access groups" do
      user = %Andi.Schemas.User{
        email: "sample@accenture.com",
        organizations: [%Andi.InputSchemas.Organization{id: "1"}],
        subject_id: "auth0|1"
      }

      allow(Organizations.get_all(), return: [])
      allow(User.get_all(), return: [user])
      allow(Datasets.get_all(), return: [])
      allow(Ingestions.get_all(), return: [])
      allow(AccessGroups.get_all(), return: [])
      allow(Andi.Repo.preload(any(), any()), return: [])
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      Andi.Scripts.ResendEvents.resend_all_events()

      assert_called Brook.Event.send(:andi, user_organization_associate(), :data_migrator, %UOA{
                      email: "sample@accenture.com",
                      org_id: "1",
                      subject_id: "auth0|1"
                    })
    end
  end
end
