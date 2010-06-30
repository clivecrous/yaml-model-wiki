require 'yaml'

class YAML::Model

  class Error < Exception
  end

  attr_reader :id

  @@database_filename = nil

  @@database = {
    :next_oid => 1,
    :data => {}
  }

  @@volatile = [ :@volatile ]

  def self.all
    @@database[ :data ][ self.name ] ||= []
  end

  def assert( assertion, info )
    raise Error.new( info.inspect ) unless assertion
  end

  def assert_type( variable, types )
    assert( [types].flatten.inject(false){|result,type|result||=(type===variable)}, "Invalid type: `#{variable.class.name}`" )
  end

  def self.type attribute, types, &block
    define_method attribute do
      instance_eval "@#{attribute}"
    end
    define_method "#{attribute}=".to_sym do |value|
      assert_type value, types
      instance_exec( value, &block ) if block_given?
      instance_eval "@#{attribute} = value"
    end
  end

  def self.init *attributes, &block
    define_method :initialize do |*args|
      attributes.each do |attribute|
        self.send( "#{attribute}=".to_sym, args.shift )
        self.instance_eval( &block ) if block_given?
      end
    end
  end

  def self.[]( id )
    all.select{|n|n.id==id}.first
  end

  def self.load!
    @@database = YAML.load( File.read( @@database_filename ) ) if File.exists?( @@database_filename )
  end

  def self.filename=( filename )
    @@database_filename = filename
    self.load!
  end

  def self.save!
    if @@database_filename
      File.open( @@database_filename, 'w' ) do |file|
        file.write( @@database.to_yaml )
      end
    end
  end

  def self.each &block
    all.each &block
  end

  def self.select &block
    all.select &block
  end

  def self.filter hash
    select do |this|
      hash.keys.inject( true ) do |result,variable|
        this.instance_eval( "@#{variable}" ) == hash[ variable ]
      end
    end
  end

  def self.volatile variable
    @@volatile << "@#{variable}".to_sym
  end

  def to_yaml_properties
    instance_variables - @@volatile
  end

  def self.create( *args )
    this = self.new( *args )
    this.instance_eval do
      @id = @@database[ :next_oid ]
      @id.freeze
    end
    @@database[ :next_oid ] += 1
    @@database[ :data ][ this.class.name ] ||= []
    @@database[ :data ][ this.class.name ] << this
    this
  end

  def delete
    @@database[ :data ][ self.class.name ].delete( self )
  end

  def <=>( other )
    self.id <=> other.id
  end

  def self.has( attribute_name, klass )
    define_method attribute_name do
      klass.select do |this|
        this.instance_variables.inject( false ) do |result,variable|
          result ||= this.instance_eval(variable).class == self.class && this.instance_eval(variable).id == self.id
        end
      end
    end
  end

  at_exit { self.save! }

end
