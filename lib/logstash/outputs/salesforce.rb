require "logstash/namespace"
require "logstash/outputs/file"

class LogStash::Outputs::SalesForce < LogStash::Outputs::Base

  # Setting the config_name here is required. This is how you
  # configure this output from your Logstash config.
  #
  # output {
  #   salesforce { ... }
  # }
  config_name "salesforce"
  
  # Set this to true to connect to a sandbox sfdc instance
  # logging in through test.salesforce.com
  config :test, :validate => :boolean, :default => false
  # Consumer Key for authentication. You must set up a new SFDC
  # connected app with oath to use this output. More information
  # can be found here:
  # https://help.salesforce.com/apex/HTViewHelpDoc?id=connected_app_create.htm
  config :client_id, :validate => :string, :required => true
  # Consumer Secret from your oauth enabled connected app
  config :client_secret, :validate => :string, :required => true
  # A valid salesforce user name, usually your email address.
  # Used for authentication and will be the user all objects
  # are created or modified by
  config :username, :validate => :string, :required => true
  # The password used to login to sfdc
  config :password, :validate => :string, :required => true
  # The security token for this account. For more information about
  # generting a security token, see:
  # https://help.salesforce.com/apex/HTViewHelpDoc?id=user_security_token.htm
  config :security_token, :validate => :string, :required => true
  # The name of the salesforce object you are creating or updating
  config :sfdc_object_name, :validate => :string, :required => true
  # This is a mapping of document fields to sfdc object fields. This
  # is used for querying for sfdc objects and the combination of these
  # values should be unique to the object.
  config :event_to_sfdc_keys_mapping, :validate => :hash, :required => true
  # This is a mapping of event fields to sfdc object fields. If the event
  # field is not present, it is ignored. Fields that are not allowed to be
  # updated are automatically removed.
  config :event_to_sfdc_mapping, :validate => :hash, :default => {}
  # Use this mapping to put static values into SFDC
  config :raw_values_to_sfdc_mapping, :validate => :hash, :default => {}
  # These fileds will be incremented by 1 if an existing record is found
  # They will be set to 1 on all new records
  config :increment_fields, :validate => :array, :default => []
  # Set this to False to disable creating new records
  config :should_create_new_records, :validate => :boolean, :default => true
  # The field name to store the results in if needed.
  config :store_results_in, :validate => :string, :default => nil

  public
  def register
    require 'restforce'
    if @test
      @client = Restforce.new :host           => 'test.salesforce.com',
                              :username       => @username,
                              :password       => @password,
                              :security_token => @security_token,
                              :client_id      => @client_id,
                              :client_secret  => @client_secret
    else
      @client = Restforce.new :username       => @username,
                              :password       => @password,
                              :security_token => @security_token,
                              :client_id      => @client_id,
                              :client_secret  => @client_secret
    end
    obj_desc = @client.describe(@sfdc_object_name)
    @static_fields = get_static_fields(obj_desc)
    @field_types = get_field_types(obj_desc)
  end

  public
  def receive(event)
    return unless output?(event)
    @event_to_sfdc_keys_mapping.each_key do |event_key_field|
      return unless event[event_key_field]
    end
    begin
      results = @client.query(get_query(event))
      if results.first
        results.each do |result|
          sfdc_object = @client.find(@sfdc_object_name, result.Id)
          update_sfdc_object(event,sfdc_object)
        end
      else
        if @should_create_new_records
          create_sfdc_object(event)
        end
      end
    rescue StandardError => e
      @logger.error(e.message)
      #ignore this error so logstash doesn't crash
    end
  end #def receive

  private
    def update_sfdc_object(event,sfdc_obj)
      return unless event
      return unless sfdc_obj
      @event_to_sfdc_mapping.each do |evt_key,sfdc_key|
        if defined?(event[evt_key]) and not event[evt_key].nil?
          if @field_types[sfdc_key] == 'datetime'
            if event[evt_key].respond_to?(:strftime)
              sfdc_obj[sfdc_key] = Time.parse(event[evt_key].strftime("%Y-%m-%d %H:%M:%S"))
            else
              sfdc_obj[sfdc_key] = Time.parse(event[evt_key].to_s)
            end
          elsif @field_types[sfdc_key] == 'date'
            sfdc_obj[sfdc_key] = Date.parse(event[evt_key])
          else
            sfdc_obj[sfdc_key] = event[evt_key]
          end
        end
      end
      @increment_fields.each do |increment_field|
        sfdc_obj[increment_field] += 1
      end
      @raw_values_to_sfdc_mapping.each do |static_value,sfdc_key|
        sfdc_obj[sfdc_key] = static_value
      end
      update_hash = sfdc_obj.to_hash
      @static_fields.each do |k|
        update_hash.delete(k)
      end
      @logger.debug("Values to be updated: "+update_hash.to_s)
      for i in 0..3
        resp = @client.update(@sfdc_object_name,update_hash)
        if resp
          break
        end
        @logger.debug("Retrying...")
        sleep(1) # Sleep one second between retries
      end
      if !resp
        @logger.error('Was not able to update: '+update_hash['Id'])
      end
      @logger.debug("Response: "+resp.to_s)
      if !@store_results_in.nil?
        event[@store_results_in] = {
          'status' => resp,
          'object_id' => update_hash['Id']
        }
      end
    end

    def create_sfdc_object(event)
      return unless event
      vals_to_update = {}
      @event_to_sfdc_mapping.each do |evt_key,sfdc_key|
        if defined?(event[evt_key])
          if @field_types[sfdc_key] == 'datetime'
            if event[evt_key].respond_to?(:strftime)
              vals_to_update[sfdc_key] = Time.parse(event[evt_key].strftime("%Y-%m-%d %H:%M:%S"))
            else
              vals_to_update[sfdc_key] = Time.parse(event[evt_key].to_s)
            end
          elsif @field_types[sfdc_key] == 'date'
            vals_to_update[sfdc_key] = Date.parse(event[evt_key])
          else
            vals_to_update[sfdc_key] = event[evt_key]
          end
        end
      end
      @increment_fields.each do |increment_field|
        vals_to_update[increment_field] = 1
      end
      @raw_values_to_sfdc_mapping.each do |static_value,sfdc_key|
        vals_to_update[sfdc_key] = static_value
      end
      resp = @client.create(@sfdc_object_name,vals_to_update)
      @logger.debug("Id of created object: "+resp.to_s)
      if !@store_results_in.nil?
        event[@store_results_in] = {
          'status' => !resp.nil?,
          'object_id' => resp.to_s
        }
      end
      return resp
    end

    def get_static_fields(obj_desc)
      static_fields = []
      obj_desc.fields.each do |f|
        if not f.updateable and f.name != 'Id'
          static_fields.push(f.name)
        end
      end
      @logger.debug("Un-updatable fields: "+static_fields.to_s)
      return static_fields
    end

    def get_field_types(obj_desc)
      field_types = {}
      obj_desc.fields.each do |f|
        field_types[f.name] = f.type
      end
      @logger.debug("Field types: "+field_types.to_s)
      return field_types
    end

    def get_query(event)
      query = ""
      @event_to_sfdc_keys_mapping.each do |evt_key,sfdc_key|
        query += sfdc_key+" = '"+event[evt_key].to_s+"'"
        query += ' AND '
      end
      query = "SELECT Id FROM "+@sfdc_object_name+" WHERE "+query[0..-6] #remove the last and
      @logger.debug("SFDC Query: "+query)
      return query
    end

end # class LogStash::Outputs::SalesForce
