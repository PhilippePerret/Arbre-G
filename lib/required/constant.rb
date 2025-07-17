class Genea
  LIB_FOLDER    = File.dirname(__dir__)
  APP_FOLDER    = File.dirname(LIB_FOLDER)
  FICHES_FOLDER = File.join(APP_FOLDER, 'fiches')
  EXPORT_FOLDER = File.join(APP_FOLDER, 'exports')
  TMP_FOLDER    = File.join(APP_FOLDER, 'xtemp')

  YAML_OPTIONS = {symbolize_names: true, aliases: true, permitted_classes: [Date, Symbol, TrueClass, FalseClass]}.freeze
end