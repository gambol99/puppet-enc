#!/usr/bin/ruby
#
#   Author: Rohith
#   Date: 2014-03-03 23:44:58 +0000 (Mon, 03 Mar 2014)
#
#  vim:ts=4:sw=4:et
#
$:.unshift File.join(File.dirname(__FILE__),'.','./puppet-enc' )
require 'rubygems' if RUBY_VERSION < '1.9.0'

module PuppetENC

    ROOT = File.expand_path File.dirname __FILE__

    require "#{ROOT}/puppet-enc/enc"

    autoload :Version,  "#{ROOT}/puppet-enc/version"
    autoload :Logger,   "#{ROOT}/puppet-enc/logger"
    autoload :Loader,   "#{ROOT}/puppet-enc/enc"  
    
    def self.version
        PuppetENC::VERSION
    end 

    def self.load options
        PuppetENC::Classify::new options
    end
      
end
