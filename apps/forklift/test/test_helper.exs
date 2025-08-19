ExUnit.start()
Mox.start_link_ownership()

# Consolidated Mox mock definitions
Mox.defmock(MockReader, for: Pipeline.Reader)
Mox.defmock(MockTopic, for: Pipeline.Writer)
Mox.defmock(MockTable, for: Pipeline.Writer)
Mox.defmock(DateTimeMock, for: Forklift.Test.DateTimeBehaviour)
Mox.defmock(DatasetsMock, for: Forklift.Test.DatasetsBehaviour)
Mox.defmock(BrookMock, for: Forklift.Test.BrookBehaviour)
Mox.defmock(BrookEventMock, for: Forklift.Test.BrookSendBehaviour)
Mox.defmock(ElsaMock, for: Forklift.Test.ElsaBehaviour)
Mox.defmock(DataWriterMock, for: Forklift.Test.DataWriterBehaviour)
Mox.defmock(PrestigeHelperMock, for: Forklift.Test.PrestigeHelperBehaviour)
Mox.defmock(TelemetryEventMock, for: Forklift.Test.TelemetryEventBehaviour)
Mox.defmock(MockRedix, for: Forklift.Test.RedixBehaviour)
# Additional mocks needed by specific test files
Mox.defmock(MockBrook, for: Brook.Event.Handler)
Mox.defmock(MockDateTime, for: Forklift.Test.DateTimeBehaviour)
Mox.defmock(MockDataMigration, for: Forklift.Test.DataMigrationBehaviour)
Mox.defmock(MockPrestigeHelper, for: Forklift.Test.PrestigeHelperBehaviour)
# Create a behavior for Prestige and its mock
Mox.defmock(PrestigeMock, for: Forklift.Test.PrestigeBehaviour)
