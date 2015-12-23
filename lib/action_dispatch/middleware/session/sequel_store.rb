require 'sequel'
require 'action_dispatch/middleware/session/abstract_store'

# TODO: remove this once rspec-rails supports rails >= 5
require 'rack/session/abstract/id'
if not Rack::Session::Abstract.const_defined?(:ENV_SESSION_OPTIONS_KEY)
  Rack::Session::Abstract.const_set(:ENV_SESSION_OPTIONS_KEY, Rack::RACK_SESSION_OPTIONS)
end

# Implements Sequel model based session store.

module ActionDispatch
  module Session
    class SequelStore < AbstractStore
      SESSION_RECORD_KEY = 'rack.session.record'.freeze
      ENV_SESSION_OPTIONS_KEY = Rack::Session::Abstract::ENV_SESSION_OPTIONS_KEY

      cattr_accessor :session_class
      def self.session_class
        @@session_class ||= begin
          res = Class.new(Sequel::Model(:sessions))
          res.plugin :timestamps, :update_on_create => true
          res.plugin :serialization, :marshal, :data
          res
        end
      end

      private

      def get_session(env, sid)
        sid ||= generate_sid
        session = find_session(sid)
        env[SESSION_RECORD_KEY] = session
        [sid, session.data]
      end

      def set_session(env, sid, session_data, _options)
        session      = get_session_model(env, sid)
        session.data = session_data
        session.save(:raise_on_failure => false) && sid
      end

      def destroy_session(env, sid, options)
        sid = current_session_id(env)
        if sid
          session = get_session_model(env, sid)
          session.destroy unless session.new?
          env[SESSION_RECORD_KEY] = nil
        end

        generate_sid unless options[:drop]
      end

      def get_session_model(env, sid)
        if env[ENV_SESSION_OPTIONS_KEY][:id].nil?
          env[SESSION_RECORD_KEY] = find_session(sid)
        else
          env[SESSION_RECORD_KEY] ||= find_session(sid)
        end
      end

      def find_session(sid)
        klass = self.class.session_class
        klass.where(:session_id => sid).first ||
          klass.new(:session_id => sid, :data => {})
      end
    end
  end
end
