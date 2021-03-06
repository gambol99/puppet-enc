#
# Author: Rohith 
# Date:   2014-03-04 00:00:16
# Last Modified by:   Rohith
#
# vim:ts=4:sw=4:et
#
require 'logger'

module PuppetENC
class Log
    class << self
        attr_accessor :logger

        def init( options = {} )
            options[:level]     = options[:level] || :debug
            self.logger         = ::Logger.new(options[:std] || STDOUT)
            self.logger.level   = ::Logger.const_get "#{options[:level].to_s.upcase}"
        end

        def method_missing(m,*args,&block)
            logger.send m, *args, &block if logger.respond_to? m
        end
    end
end
end