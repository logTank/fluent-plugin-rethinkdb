require 'rethinkdb'

module Fluent
  class RethinkOutput < BufferedOutput
    include RethinkDB::Shortcuts
    Plugin.register_output('rethinkdb', self)

    config_param :database, :string
    config_param :host, :string, :default => 'localhost'
    config_param :table, :string, :default => :log
    config_param :port, :integer, :default => 28015
    config_param :auto_tag_table, :default => false
    config_param :search_replace_subtag, :string, :default => nil

    include SetTagKeyMixin
    config_set_default :include_tag_key, false

    include SetTimeKeyMixin
    config_set_default :include_time_key, false

    # This method is called before starting.
    # 'conf' is a Hash that includes configuration parameters.
    # If the configuration is invalid, raise Fluent::ConfigError.
    def configure(conf)
      super

      @db    = conf['database']
      @host  = conf['host']
      @port  = conf['port']
      @table = conf['table']
      @auto_tag_table = conf['auto_tag_table']
      @search_replace_subtag = conf['search_replace_subtag']
      @search_subtag, @replace_subtag = @search_replace_subtag.split('/') if @search_replace_subtag
    end

    def start
      super
      @conn = r.connect(:host => @host,
                        :port => @port,
                        :db => @db)
    end

    def shutdown
      super
      @conn.close
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    # This method is called every flush interval. Write the buffer chunk
    # to files or databases here.
    # 'chunk' is a buffer chunk that includes multiple formatted
    # events. You can use 'data = chunk.read' to get all events and
    # 'chunk.open {|io| ... }' to get IO objects.
    #
    # NOTE! This method is called by internal thread, not Fluentd's main thread. So IO wait doesn't affect other plugins.
    def write(chunk)
      records = {}
      chunk.msgpack_each {|(tag,time,record)|
        record[@time_key] = Time.at(time || record[@time_key]) if @include_time_key
        record[@tag_key] = get_tag(tag) if @include_tag_key
        records[tag] ||= []
        records[tag] << record
      }

      begin
        records.map do |tag, elements|
          get_table(@auto_tag_table ? tag : @table).insert(elements).run(@conn) if !elements.empty?
        end
      rescue
        log.error "unexpected error when inserting elements", :error=>$!.to_s
        log.error_backtrace
      end
    end

    def get_table(table_name)
      return r.table(table_name) unless @auto_tag_table
      table = nil
      begin
        r.table_create(table_name).run @conn
        table = r.table(table_name)
      rescue RethinkDB::RqlRuntimeError =>e
        table = r.table(table_name)
      ensure
        if table.nil?
          puts "Sucks! Table still nill"
        end
      end

      return table
    end

    def get_tag(tag)
      return tag if @search_replace_subtag.nil?

      tag[@search_subtag] = @replace_subtag
      return tag
    end
  end
end

