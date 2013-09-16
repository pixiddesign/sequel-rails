require "spec_helper"

describe SequelRails::Configuration do

  describe ".setup" do

    let(:environments) do
      {
        "development" => {
          "adapter" => "postgres",
          "owner" => (ENV["TEST_OWNER"] || ENV["USER"]),
          "username" => (ENV["TEST_OWNER"] || ENV["USER"]),
          "database" => "sequel_rails_test_storage_dev",
          "host" => "127.0.0.1",
        },
        "test" => {
          "adapter" => "postgres",
          "owner" => (ENV["TEST_OWNER"] || ENV["USER"]),
          "username" => (ENV["TEST_OWNER"] || ENV["USER"]),
          "database" => "sequel_rails_test_storage_test",
          "host" => "127.0.0.1",
        },
        "remote" => {
          "adapter" => "mysql",
          "host" => "10.0.0.1",
          "database" => "sequel_rails_test_storage_remote",
        },
        "production" => {
          "host" => "10.0.0.1",
          "database" => "sequel_rails_test_storage_production",
        },
        "url_already_constructed" => {
          "adapter" => "adapter_name",
          "url" => "jdbc:adapter_name://HOST/DB?user=U&password=P&ssl=true&sslfactory=sslFactoryOption"
        },
        "bogus" => {},
      }
    end
    let(:is_jruby) { false }

    before do
      SequelRails.configuration = described_class.new
      SequelRails.configuration.raw = environments
      SequelRails.configuration.instance_variable_set('@environments', nil)
      SequelRails.stub(:jruby?).and_return is_jruby
    end

    subject { SequelRails.setup(environment) }

    shared_examples "max_connections" do
      context "with max_connections config option" do
        let(:max_connections) { 31337 }
        before do
          environments[environment]["max_connections"] = 7
          SequelRails.configuration.max_connections = max_connections
        end

        it "overrides the option from the configuration" do
          ::Sequel.should_receive(:connect) do |hash_or_url, *_|
            if hash_or_url.is_a? Hash
              hash_or_url['max_connections'].should == max_connections
            else
              hash_or_url.should include("max_connections=#{max_connections}")
            end
          end
          subject
        end
      end
    end

    context "for a postgres connection" do

      shared_examples "search_path" do
        context "with search_path config option" do
          let(:search_path) { ['secret', 'private', 'public'] }
          before do
            environments[environment]["search_path"] = "private, public"
            SequelRails.configuration.search_path = search_path
          end

          it "overrides the option from the configuration" do
            ::Sequel.should_receive(:connect) do |hash_or_url, *_|
              if hash_or_url.is_a? Hash
                hash_or_url['search_path'].should == search_path
              else
                hash_or_url.should include("search_path=secret,private,public")
              end
            end
            subject
          end
        end
      end

      let(:environment) { 'development' }

      context "in C-Ruby" do

        include_examples "max_connections"
        include_examples "search_path"

        it "produces a sane config without url" do
          ::Sequel.should_receive(:connect) do |hash|
            hash['adapter'].should == 'postgres'
          end
          subject
        end

      end

      context "in JRuby" do

        include_examples "max_connections"
        include_examples "search_path"

        let(:is_jruby) { true }

        it "produces an adapter config with a url" do
          ::Sequel.should_receive(:connect) do |url, hash|
            url.should =~ /^jdbc:postgresql:\/\//
            hash['adapter'].should == 'jdbc:postgresql'
            hash['host'].should    == '127.0.0.1'
          end
          subject
        end

        context "when url is already given" do

          let(:environment) { "url_already_constructed" }

          it "does not change the url" do
            ::Sequel.should_receive(:connect) do |url, hash|
              url.should == "jdbc:adapter_name://HOST/DB?user=U&password=P&ssl=true&sslfactory=sslFactoryOption"
              hash['adapter'].should == 'jdbc:adapter_name'
            end
            subject
          end

        end
      end
    end

    context "for a mysql connection" do

      let(:environment) { 'remote' }

      context "in C-Ruby" do

        include_examples "max_connections"

        it "produces a config without url" do
          ::Sequel.should_receive(:connect) do |hash|
            hash['adapter'].should == 'mysql'
          end
          subject
        end
      end

      context "in JRuby" do

        include_examples "max_connections"

        let(:is_jruby) { true }

        it "produces a jdbc mysql config" do
          ::Sequel.should_receive(:connect) do |url, hash|
            url.should =~ /^jdbc:mysql:\/\//
            hash['adapter'].should  == 'jdbc:mysql'
            hash['database'].should == 'sequel_rails_test_storage_remote'
          end
          subject
        end

        context "when url is already given" do

          let(:environment) { "url_already_constructed" }

          it "does not change the url" do
            ::Sequel.should_receive(:connect) do |url, hash|
              url.should == "jdbc:adapter_name://HOST/DB?user=U&password=P&ssl=true&sslfactory=sslFactoryOption"
              hash['adapter'].should == 'jdbc:adapter_name'
            end
            subject
          end

        end
      end
    end
  end

  describe "#schema_dump" do
    before{ Rails.stub(:env).and_return environment }
    subject{ described_class.new }

    context "in test environment" do
      let(:environment) { "test" }
      it "defaults to false" do
        subject.schema_dump.should be_false
      end
      it "can be assigned" do
        subject.schema_dump = true
        subject.schema_dump.should be_true
      end
      it "can be set from merging another hash" do
        subject.merge!(:schema_dump => true)
        subject.schema_dump.should be_true
      end
    end

    context "in production environment" do
      let(:environment) { "production" }
      it "defaults to false" do
        subject.schema_dump.should be_false
      end
      it "can be assigned" do
        subject.schema_dump = true
        subject.schema_dump.should be_true
      end
      it "can be set from merging another hash" do
        subject.merge!(:schema_dump => true)
        subject.schema_dump.should be_true
      end
    end

    context "in other environments" do
      let(:environment) { "development" }
      it "defaults to true" do
        subject.schema_dump.should be_true
      end
      it "can be assigned" do
        subject.schema_dump = false
        subject.schema_dump.should be_false
      end
      it "can be set from merging another hash" do
        subject.merge!(:schema_dump => false)
        subject.schema_dump.should be_false
      end
    end
  end

  describe "#load_database_tasks" do
    subject{ described_class.new }

    it "defaults to true" do
      subject.load_database_tasks.should be_true
    end
    it "can be assigned" do
      subject.load_database_tasks = false
      subject.load_database_tasks.should be_false
    end
    it "can be set from merging another hash" do
      subject.merge!(:load_database_tasks => false)
      subject.load_database_tasks.should be_false
    end
  end
end
