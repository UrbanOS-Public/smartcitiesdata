ExUnit.start()
Mox.start_link_ownership()

Mox.defmock(DatasetsMock, for: Forklift.Test.DatasetsBehaviour)
Mox.defmock(BrookEventMock, for: Forklift.Test.BrookSendBehaviour)
Mox.defmock(ElsaMock, for: Forklift.Test.ElsaBehaviour)
