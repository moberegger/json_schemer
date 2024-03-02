require 'test_helper'

class ConfigurationTest < Minitest::Test
  def run_configuration_test(option, default: (skip_default = true), test:)
    original = JSONSchemer.configuration.public_send(option)

    if default.nil?
      assert_nil(original)
    elsif default.respond_to?(:call)
      default.call(original)
    elsif !skip_default
      assert_equal(default, original)
    end

    JSONSchemer.configure { |config| config.public_send("#{option}=", test) }

    yield if block_given?

    assert_equal(test, JSONSchemer.configuration.public_send(option))

    # We need to reset the configuration to avoid "polluting" other tests.
    JSONSchemer.configure { |config| config.public_send("#{option}=", original) }
  end

  def test_configure
    JSONSchemer.configure do |config|
      assert_instance_of(JSONSchemer::Configuration, config)
    end
  end

  def test_base_uri
    run_configuration_test(
      :base_uri,
      default: URI('json-schemer://schema'),
      test: URI('some-other://schema')
    )
  end

  def test_meta_schema
    run_configuration_test(
      :meta_schema,
      default: 'https://json-schema.org/draft/2020-12/schema',
      test: JSONSchemer.draft201909
    )
  end

  def test_string_meta_schema
    run_configuration_test(:meta_schema, test: 'https://json-schema.org/draft/2019-09/schema') do
      assert_equal(JSONSchemer.draft201909, JSONSchemer.schema({ 'maximum' => 1 }).meta_schema)
      assert(JSONSchemer.schema({ 'maximum' => 1 }).valid?(1))
      refute(JSONSchemer.schema({ 'exclusiveMaximum' => 1 }).valid?(1))
      assert(JSONSchemer.valid_schema?({ 'exclusiveMaximum' => 1  }))
      refute(JSONSchemer.valid_schema?({ 'maximum' => 1, 'exclusiveMaximum' => true  }))
    end
    run_configuration_test(:meta_schema, test: 'http://json-schema.org/draft-04/schema#') do
      assert_equal(JSONSchemer.draft4, JSONSchemer.schema({ 'maximum' => 1 }).meta_schema)
      assert(JSONSchemer.schema({ 'maximum' => 1 }).valid?(1))
      refute(JSONSchemer.schema({ 'maximum' => 1, 'exclusiveMaximum' => true }).valid?(1))
      refute(JSONSchemer.valid_schema?({ 'exclusiveMaximum' => 1  }))
      assert(JSONSchemer.valid_schema?({ 'maximum' => 1, 'exclusiveMaximum' => true  }))
    end
  end

  def test_vocabulary
    run_configuration_test(
      :vocabulary,
      default: nil,
      test: { 'json-schemer://draft4' => true }
    )
  end

  def test_format
    run_configuration_test(
      :format,
      default: true,
      test: false
    )
  end

  def test_formats
    run_configuration_test(
      :formats,
      default: {},
      test: {
        'some-format' => lambda { |instance, _format| true }
      }
    )
  end

  def test_content_encodings
    run_configuration_test(
      :content_encodings,
      default: {},
      test: {
        'lowercase' => lambda { |instance| [true, instance&.downcase] }
      }
    )
  end

  def test_content_media_types
    run_configuration_test(
      :content_media_types,
      default: {},
      test: {
        'text/csv' => lambda do |instance|
          [true, CSV.parse(instance)]
        rescue
          [false, nil]
        end
      }
    )
  end

  def test_keywords
    run_configuration_test(
      :keywords,
      default: {},
      test: {
        'even' => lambda { |data, curr_schema, _pointer| curr_schema.fetch('even') == data.to_i.even? }
      }
    )
  end

  def test_before_property_validation
    run_configuration_test(
      :before_property_validation,
      default: [],
      test: ['something']
    )
  end

  def test_after_property_validation
    run_configuration_test(
      :after_property_validation,
      default: [],
      test: ['something']
    )
  end

  def test_insert_property_defaults
    run_configuration_test(
      :insert_property_defaults,
      default: false,
      test: true
    )
  end

  def test_property_default_resolver
    run_configuration_test(
      :property_default_resolver,
      default: nil,
      test: lambda { |instance, property, results_with_tree_validity| true }
    )
  end

  def test_ref_resolver
    run_configuration_test(
      :ref_resolver,
      default: lambda do |ref_resolver|
        assert_raises(JSONSchemer::UnknownRef) do
          ref_resolver.call(URI('example'))
        end
      end,
      test: lambda { |uri| { 'type' => 'string' } }
    )
  end

  def test_regexp_resolver
    run_configuration_test(
      :regexp_resolver,
      default: 'ruby',
      test: 'ecma'
    )
  end

  def test_output_format
    run_configuration_test(
      :output_format,
      default: 'classic',
      test: 'basic'
    )
  end

  def test_resolve_enumerators
    run_configuration_test(
      :resolve_enumerators,
      default: false,
      test: true
    )
  end

  def test_access_mode
    run_configuration_test(
      :access_mode,
      default: nil,
      test: "write"
    )
  end

  def test_configuration_option_and_override
    configuration = JSONSchemer::Configuration.new
    configuration.format = false
    assert(JSONSchemer.schema({ 'format' => 'time' }).valid?('08:30:06Z'))
    refute(JSONSchemer.schema({ 'format' => 'time' }).valid?('X'))
    assert(JSONSchemer.schema({ 'format' => 'time' }, configuration: configuration).valid?('08:30:06Z'))
    assert(JSONSchemer.schema({ 'format' => 'time' }, configuration: configuration).valid?('X'))
    assert(JSONSchemer.schema({ 'format' => 'time' }, configuration: configuration, format: true).valid?('08:30:06Z'))
    refute(JSONSchemer.schema({ 'format' => 'time' }, configuration: configuration, format: true).valid?('X'))
  end

  def test_configuration_keyword_init
    configuration = JSONSchemer::Configuration.new(:format => false)
    refute(JSONSchemer.schema({ 'format' => 'time' }).valid?('X'))
    assert(JSONSchemer.schema({ 'format' => 'time' }, configuration: configuration).valid?('X'))
  end
end
