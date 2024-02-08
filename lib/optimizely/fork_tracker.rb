# frozen_string_literal: true

# This class is used for re-starting of threads after a fork
# Sourced from https://github.com/rails/rails/blob/a44559679aa26a54ea9867a68a78c5a4a55a3b9f/activesupport/lib/active_support/fork_tracker.rb

module Optimizely
  module ForkTracker
    module ModernCoreExt
      def _fork
        pid = super
        ForkTracker.after_fork_callback if pid.zero?
        pid
      end
    end

    module CoreExt
      def fork(...)
        if block_given?
          super do
            ForkTracker.check!
            yield
          end
        else
          unless (pid = super)
            ForkTracker.check!
          end
          pid
        end
      end
    end

    module CoreExtPrivate
      include CoreExt
      private :fork
    end

    @pid = Process.pid
    @callbacks = []

    class << self
      def after_fork_callback
        new_pid = Process.pid
        return unless @pid != new_pid

        @callbacks.each(&:call)
        @pid = new_pid
      end

      if Process.respond_to?(:_fork) # Ruby 3.1+
        def check!
          # We trust the `_fork` callback
        end
      else
        alias check! after_fork_callback
      end

      def hook!
        if Process.respond_to?(:_fork) # Ruby 3.1+
          ::Process.singleton_class.prepend(ModernCoreExt)
        elsif Process.respond_to?(:fork)
          ::Object.prepend(CoreExtPrivate) if RUBY_VERSION < '3.0'
          ::Kernel.prepend(CoreExtPrivate)
          ::Kernel.singleton_class.prepend(CoreExt)
          ::Process.singleton_class.prepend(CoreExt)
        end
      end

      def after_fork(&block)
        @callbacks << block
        block
      end

      def unregister(callback)
        @callbacks.delete(callback)
      end
    end
  end
end

Optimizely::ForkTracker.hook!
