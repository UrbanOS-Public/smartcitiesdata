ExUnit.start(capture_log: true)

Mox.defmock(DlqMock, for: Dlq.Behaviour)
Mox.defmock(Elsa.Kafka.Mock, for: Elsa.Kafka.Producer)