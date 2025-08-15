defmodule DiscoveryApi.Test.MoxSetup do
  @moduledoc """
  Mox setup for Discovery API tests
  """

  # Define all the mocks we need for Discovery API tests
  
  # Database and Presto mocks (legacy - will be removed)
  
  # Auth mocks
  Mox.defmock(GuardianPlugMock, for: [])
  Mox.defmock(GuardianDBTokenMock, for: [])
  
  # Discovery API mocks
  Mox.defmock(ModelMock, for: [ModelBehaviour])
  Mox.defmock(UsersMock, for: [UsersBehaviour])
  Mox.defmock(PrestoServiceMock, for: [PrestoServiceBehaviour])
  Mox.defmock(PersistenceMock, for: [DiscoveryApi.Data.PersistenceBehaviour])
  
  # Model mock for direct function calls
  Mox.defmock(DataModelMock, for: [])
  
  # ElasticSearch mocks
  Mox.defmock(ElastixMock, for: [])
  
  # TelemetryEvent mock
  Mox.defmock(TelemetryEventMock, for: [])
  
  # RaptorService mock
  Mox.defmock(RaptorServiceMock, for: [RaptorServiceBehaviour])
  
  # Redix mock
  Mox.defmock(RedixMock, for: [RedixBehaviour])
  
  # Cache and Storage mocks
  Mox.defmock(ResponseCacheMock, for: [ResponseCacheBehaviour])
  Mox.defmock(SystemNameCacheMock, for: [SystemNameCacheBehaviour])
  
  # Service mocks
  Mox.defmock(RecommendationEngineMock, for: [RecommendationEngineBehaviour])
  Mox.defmock(MetricsServiceMock, for: [MetricsServiceBehaviour])
  Mox.defmock(DeadLetterMock, for: [DeadLetterBehaviour])
  Mox.defmock(OrganizationsMock, for: [OrganizationsBehaviour])
  Mox.defmock(DataJsonServiceMock, for: [DataJsonServiceBehaviour])
  Mox.defmock(StatsCalculatorMock, for: [])
  Mox.defmock(TableInfoCacheMock, for: [TableInfoCacheBehaviour])
  Mox.defmock(ObjectStorageServiceMock, for: [ObjectStorageServiceBehaviour])
  Mox.defmock(HmacTokenMock, for: [HmacTokenBehaviour])
  Mox.defmock(ModelAccessUtilsMock, for: [ModelAccessUtilsBehaviour])
  Mox.defmock(QueryAccessUtilsMock, for: [QueryAccessUtilsBehaviour])
  
  # Elasticsearch Document mock
  Mox.defmock(ElasticsearchDocumentMock, for: [ElasticsearchDocumentBehaviour])
  
  # Search mock
  Mox.defmock(SearchMock, for: [SearchBehaviour])
  
  # Mapper mock
  Mox.defmock(MapperMock, for: [MapperBehaviour])
  
  # Brook mock
  Mox.defmock(BrookMock, for: [BrookBehaviour])
  
  # DateTime mock
  Mox.defmock(DateTimeMock, for: [DateTimeBehaviour])
  
  # Prestige (Presto client) mocks
  Mox.defmock(PrestigeMock, for: [PrestigeBehaviour])
  Mox.defmock(PrestigeResultMock, for: [PrestigeResultBehaviour])
  
  # Auth service mock
  Mox.defmock(AuthServiceMock, for: [AuthServiceBehaviour])
  
  
  def setup_mox() do
    # Set Mox to private mode by default
    Mox.set_mox_private()
    
    # Note: verify_on_exit! will be called in individual test setups
    # not here during module load time
  end
end