# -*- coding: utf-8 -*-
require_relative '../test_helper'
require 'time'

class RethinkOutputTest < Test::Unit::TestCase
  include RethinkTestHelper

  def setup
    Fluent::Test.setup
    require 'fluent/plugin/out_rethinkdb'
    setup_rethinkdb
  end

  def teardown
    r.table_drop(table_name).run(@@conn) rescue nil
    r.table_create(table_name).run(@@conn) rescue nil
    teardown_rethinkdb
  end

  def table_name
    'test'
  end

  def base_config
    %[
      type rethinkdb
      database #{RETHINK_DB}
      table #{table_name}
      port #{unused_port}
      ]
  end

  def default_config
    base_config + %[
      include_time_key true
      include_tag_key false # TestDriver ignore config_set_default?
    ]
  end

  def create_driver(conf = default_config)
    conf = conf + %[
      port #{@@rethinkdb_port}
      ]
      Fluent::Test::BufferedOutputTestDriver.new(Fluent::RethinkOutput).configure(conf)
  end

  def test_configure
    d = create_driver(%[
      type rethink
      database fluent_test
      table log
      host localhost
      port #{unused_port}
      ])

    assert_equal('fluent_test', d.instance.database)
    assert_equal('log', d.instance.table)
    assert_equal('localhost', d.instance.host)
    assert_equal(@@rethinkdb_port.to_s, d.instance.port)
    assert_equal('log', d.instance.table)
    # buffer_chunk_limit moved from configure to start
    # I will move this test to correct space after BufferedOutputTestDriver supports start method invoking
    # assert_equal(Fluent::RethinkOutput::LIMIT_BEFORE_v1_8, d.instance.instance_variable_get(:@buffer).buffer_chunk_limit)
  end

  def test_start

  end

  def test_format
    d = create_driver(default_config + %[
      include_tag_key true
    ])
    r.table_create(table_name).run(@@conn) rescue nil
    time = Time.parse("2011-01-02 13:14:15 UTC")
    d.emit({'field' => 1}, time)
    d.emit({'field' => 2}, time)
    d.expect_format([ 'test', time.to_i, {'field' => 1, 'tag' => 'test', 'time'=>time.utc.iso8601 }].to_msgpack)
    d.expect_format([ 'test', time.to_i, {'field' => 2, 'tag' => 'test', 'time'=>time.utc.iso8601}].to_msgpack)
    d.run
    assert_equal(2, r.table(table_name).count().run(@@conn))
  end

  def emit_documents(d)
    time = Time.parse("2011-01-02 13:14:15 UTC")
    d.emit({'field' => 1}, time)
    d.emit({'field' => 2}, time)
    time
  end

  def get_documents
    r.table(table_name).run(@@conn)
  end

  def test_write
    d = create_driver default_config
    t = emit_documents(d)
    d.run
    records = []
    get_documents.each do |r|
      records << r['field']
    end
    #documents = documents.map { |e| e['a'] }.sort
    records.sort!
    assert_equal([1, 2], records)
    assert_equal(2, records.length)
  end

  def test_format_no_tagkey
    d = create_driver(base_config + %[
                      include_time_key true
                      include_tag_key false
                      ])
    r.table_create(table_name).run(@@conn) rescue nil
    time = Time.parse("2011-01-02 13:14:15 UTC")
    d.emit({'field' => 1}, time)
    d.emit({'field' => 2}, time)
    d.expect_format(['test', time.to_i, {'field' => 1, 'time'=>time.utc.iso8601}].to_msgpack)
    d.expect_format(['test', time.to_i, {'field' => 2, 'time'=>time.utc.iso8601}].to_msgpack)
    d.run
    assert_equal(2, r.table(table_name).count().run(@@conn))
  end

  def test_format_no_timekey
    d = create_driver(base_config + %[include_time_key no])
    r.table_create(table_name).run(@@conn) rescue nil
    time = Time.parse("2011-01-02 13:14:15 UTC")
    d.emit({'field' => 1}, time)
    d.emit({'field' => 2}, time)
    d.expect_format(['test', time.to_i, {'field' => 1}].to_msgpack)
    d.expect_format(['test', time.to_i, {'field' => 2}].to_msgpack)
    d.run
    assert_equal(2, r.table(table_name).count().run(@@conn))
  end

  def test_format_no_time_no_tag
    d = create_driver(base_config +
                      %[
          include_tag_key false
          include_time_key false
    ])
    r.table_create(table_name).run(@@conn) rescue nil
    time = Time.parse("2011-01-02 13:14:15 UTC")
    d.emit({'field' => 1}, time)
    d.emit({'field' => 2}, time)
    d.expect_format(['test', time.to_i, {'field' => 1}].to_msgpack)
    d.expect_format(['test', time.to_i, {'field' => 2}].to_msgpack)
    d.run
    assert_equal(2, r.table(table_name).count().run(@@conn))
  end

  def test_auto_tag_table
    d = Fluent::Test::BufferedOutputTestDriver.new(Fluent::RethinkOutput, "system").configure(default_config + %[
      auto_tag_table true
    ])
    emit_documents(d)
    d.run
    records = []
    r.table("system").run(@@conn).each do |r|
      records << r['field']
    end
    records.sort!
    assert_equal([1, 2], records)
    assert_equal(2, records.length)
  end

end

