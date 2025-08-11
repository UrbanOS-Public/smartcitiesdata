import Config

System.put_env("AWS_ACCESS_KEY_ID", "minioadmin")
System.put_env("AWS_ACCESS_KEY_SECRET", "minioadmin")

config :logger,
  level: :warn

config :phoenix, :json_library, Jason

config :reaper,
  output_topic_prefix: "raw",
  produce_retries: 2,
  produce_timeout: 10,
  secrets_endpoint: "http://vault:8200",
  hosted_file_bucket: "hosted-dataset-files",
  task_delay_on_failure: 1_000,
  json_encoder: JasonMock,
  cache_module: CacheMock,
  date_time: DateTimeMock,
  processor: ProcessorMock,
  elsa_brokers: [localhost: 9092],
  
  ex_aws: ExAwsMock,
  ex_aws_s3: ExAwsS3Mock,
  ftp: FtpMock,
  redix_client: RedixMock,
  timex: TimexMock,
  secret_retriever: SecretRetrieverMock,
  mint_http: MintHttpMock,
  stop_ingestion: StopIngestionMock,
  topic_manager: TopicManagerMock



config :reaper, :brook,
  driver: [
    module: Brook.Driver.Test,
    init_arg: []
  ],
  handlers: [Reaper.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ],
  dispatcher: Brook.Dispatcher.Noop
