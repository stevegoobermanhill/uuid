# encoding: UTF-8
# Author:: Assaf Arkin  assaf@labnotes.org
#          Eric Hodel drbrain@segment7.net
# Copyright:: Copyright (c) 2005-2008 Assaf Arkin, Eric Hodel
# License:: MIT and/or Creative Commons Attribution-ShareAlike

require 'minitest/autorun'
require 'minitest/mock'
require 'rubygems'
require 'pry'
require_relative '../lib/uuid'

class TestUUID < MiniTest::Unit::TestCase

  def test_state_file_creation
    path = UUID.state_file
    File.delete path if File.exist?(path)
    UUID.new.generate
    File.exist?(path)
  end

  def test_state_file_creation_mode
    UUID.class_eval{ @state_file = nil; @mode = nil }
    UUID.state_file 0666
    path = UUID.state_file
    File.delete path if File.exist?(path)

    old_umask = File.umask(0022)
    UUID.new.generate
    File.umask(old_umask)

    assert_equal '0666', sprintf('%04o', File.stat(path).mode & 0777)
  end

  def test_state_file_specify
    path = File.join("path", "to", "ruby-uuid")
    UUID.state_file = path
    assert_equal path, UUID.state_file
  ensure
    UUID.state_file=nil #ensure state_path is reset
  end

  def test_mode_is_set_on_state_file_specify
    UUID.class_eval{ @state_file = nil; @mode = nil }
    path = File.join(Dir.tmpdir, "ruby-uuid-test")
    File.delete path if File.exist?(path)

    UUID.state_file = path

    old_umask = File.umask(0022)
    UUID.new.generate
    File.umask(old_umask)

    UUID.class_eval{ @state_file = nil; @mode = nil }
    assert_equal '0644', sprintf('%04o', File.stat(path).mode & 0777)
  end

  def test_with_no_state_file
    UUID.state_file = false
    assert !UUID.state_file
    uuid = UUID.new
    assert_match(/\A[\da-f]{32}\z/i, uuid.generate(format: :compact))
    seq = uuid.next_sequence
    assert_equal seq + 1, uuid.next_sequence
    assert !UUID.state_file
  end

  def validate_uuid_generator(uuid)
    assert_match(/\A[\da-f]{32}\z/i, uuid.generate(format: :compact))

    assert_match(/\A[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i,
                 uuid.generate(format: :default))

    assert_match(/^urn:uuid:[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i,
                 uuid.generate(format: :urn))

    e = assert_raises ArgumentError do
      uuid.generate(format: :unknown)
    end
    assert_equal 'invalid UUID format :unknown', e.message

  end
  
  def test_historic_timestamp_generation
    uuid=UUID.new
    u1=uuid.generate(format: :compact)
    u2=uuid.generate(timestamp: Time.at(0))
    u3=uuid.generate(timestamp: Time.now+1)
    assert (u2<u1)
    assert (u3>u1)
  end

  def test_instance_generate
    uuid = UUID.new
    validate_uuid_generator(uuid)
  end

  def test_class_generate
    assert_match(/\A[\da-f]{32}\z/i, UUID.generate(format: :compact))

    assert_match(/\A[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i,
                 UUID.generate(format: :default))

    assert_match(/^urn:uuid:[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}\z/i,
                 UUID.generate(format: :urn))

    e = assert_raises ArgumentError do
      UUID.generate(format: :unknown)
    end
    assert_equal 'invalid UUID format :unknown', e.message
  end

  def test_class_validate
    assert !UUID.validate('')

    assert  UUID.validate('01234567abcd8901efab234567890123'), 'compact'
    assert  UUID.validate('01234567-abcd-8901-efab-234567890123'), 'default'
    assert  UUID.validate('urn:uuid:01234567-abcd-8901-efab-234567890123'),
            'urn'

    assert  UUID.validate('01234567ABCD8901EFAB234567890123'), 'compact'
    assert  UUID.validate('01234567-ABCD-8901-EFAB-234567890123'), 'default'
    assert  UUID.validate('urn:uuid:01234567-ABCD-8901-EFAB-234567890123'),
            'urn'
  end

  def test_monotonic
    seen = {}
    uuid_gen = UUID.new

    20_000.times do
      uuid = uuid_gen.generate
      assert !seen.has_key?(uuid), "UUID repeated"
      seen[uuid] = true
    end
  end

  def test_same_mac
    class << foo = UUID.new
      attr_reader :mac
    end
    class << bar = UUID.new
      attr_reader :mac
    end
    assert_equal foo.mac, bar.mac
  end

  def test_increasing_sequence
    class << foo = UUID.new
      attr_reader :sequence
    end
    class << bar = UUID.new
      attr_reader :sequence
    end
    assert_equal foo.sequence + 1, bar.sequence
  end

  def test_pseudo_random_mac_address
    uuid_gen = UUID.new
    Mac.stub(:addr, "00:00:00:00:00:00") do
      assert uuid_gen.iee_mac_address == 0
      [:compact, :default, :urn].each do |format|
        assert UUID.validate(uuid_gen.generate(format: format)), format.to_s
      end
      validate_uuid_generator(uuid_gen)
    end
  end

end

