class Genea::Config
  
class << self

  def init
    Genea.const_set('CONFIG', data)
  end
  def data
    @data ||= load
  end
  def load
    YAML.safe_load(IO.read(path), **Genea::YAML_OPTIONS)
  end
  def path
    @path ||= File.join(Genea::APP_FOLDER,'config.yaml')
  end
end #/class << self
end #/class Genea::Config