SemanticLogger.sync!
SemanticLogger.default_level = :trace # Prefab will take over the filtering
SemanticLogger.add_appender(
  io: $stdout,
  formatter: Rails.env.development? ? :color : :json,
  filter: Prefab.log_filter,
)
