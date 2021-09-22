defmodule Andi.Scripts.ResendEventsTest do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.Schemas.User
  alias SmartCity.UserOrganizationAssociate, as: UOA
  import SmartCity.Event

  describe "resend_dataset_events/0" do
    test "resends all datasets in the DatasetStore as dataset:update events in Brook" do
      dataset1 = TDG.create_dataset(%{})
      dataset2 = TDG.create_dataset(%{})
      expected_datasets = {:ok, [dataset1, dataset2]}
      allow(DatasetStore.get_all(), return: expected_datasets)
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      Andi.Scripts.ResendEvents.resend_dataset_events()

      assert_called Brook.Event.send(:andi, dataset_update(), :testing, dataset1)
      assert_called Brook.Event.send(:andi, dataset_update(), :testing, dataset2)
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

      assert_called Brook.Event.send(:andi, user_organization_associate(), :testing, %UOA{
                      email: "sample@accenture.com",
                      org_id: "1",
                      subject_id: "auth0|1"
                    })

      assert_called Brook.Event.send(:andi, user_organization_associate(), :testing, %UOA{
                      email: "sample@accenture.com",
                      org_id: "2",
                      subject_id: "auth0|1"
                    })

      assert_called Brook.Event.send(:andi, user_organization_associate(), :testing, %UOA{
                      email: "sample@accenture.com",
                      org_id: "3",
                      subject_id: "auth0|2"
                    })

      assert_called Brook.Event.send(:andi, user_organization_associate(), :testing, %UOA{
                      email: "sample@accenture.com",
                      org_id: "4",
                      subject_id: "auth0|2"
                    })
    end
  end
end
