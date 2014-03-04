#!/usr/bin/ruby
#
# Author: Rohith 
# Date:   2014-03-03 23:48:01
# Last Modified by:   Rohith
#
# vim:ts=4:sw=4:et
#

$:.unshift File.join(File.dirname(__FILE__),'.','../libs' )
require 'optparse'
require 'puppet-enc'

Meta = {
    :prog     => "#{__FILE__}",
    :author   => "Rohith",
    :email    => "gambol99@gmail.com",
    :date     => "2013-10-10 10:10:32 +0100",
    :version  => "0.0.1"
}

@@options = {
    :hosts       => [],
    :classify    => './classification.yaml',
    :output      => 'yaml',
    :verbose     => false,
    :lock_file   => './classify.lock',
    :with_lock   => false,
    :quiet       => false,
    :timeout     => 10,
    :lock        => nil
}

def usage( message )
    puts Parser unless @options[:quiet]
    if message
        puts "\n[error] %s\n" % [ message ] unless @options[:quiet]
        exit 1
    end
    exit 0
end

Parser = OptionParser::new do |opts|
    opts.on( "-H", "--host hostname",      "the hostname you wish to classify" )                                            { |arg| @options[:hosts]        << arg   }
    opts.on( "-c", "--classify filename",  "the location of the classification file (defaults to #{@options[:classify]})" ) { |arg| @options[:classify]     = arg    }
    opts.on( "-o", "--output type",        "the output type (defaults to #{@options[:output]})")                            { |arg| @options[:output]       = arg    }
    opts.on( "-1", "--quiut",              "do not product any output, just an exit code")                                  { @options[:quiet]              = true   }
    opts.on( "-L", "--withlock",           "specify we need to acquire the lock file before proceeding" )                   { @options[:withlock]           = true   }
    opts.on( "-l", "--lock file",          "the location of the lock file (defaults to #{@options[:lock_file]})" )          { |arg| @options[:lock_file]    = arg    }
    opts.on( "-v", "--verbose",            "switch on verbose logging" )                                                    { @options[:verbose]            = true   }
    opts.on( "-V", "--version",            "display the version information"  ) do
        puts "%s written by %s ( %s ) version: %s\n" % [ Meta[:prog], Meta[:author], Meta[:email], Meta[:version] ]
        exit 0
    end
    opts.on( "-h", "--help",               "display this help menu" ) do
        puts Parser
        exit 0
    end
end
Parser.parse!

# perform some sanity checks
begin
    usage "you have not specified a location for the classification files" unless @options[:classify]
    usage "the classification file #{@options[:classify]} does not exist"   unless File.exist?( @options[:classify] )                        
    usage "the classification file #{@options[:classify]} is not readable"  unless File.readable?( @options[:classify] )   
    usage "the classification file #{@options[:classify]} is not writable"  unless File.writable?( @options[:classify] )   
    usage "the output type #{@options[:output]} is not supported, only yaml and json" unless ['yaml','json'].include?( @options[:output ])
    usage "you have not specified any host/s to classify"                  if @options[:hosts].empty?
rescue SystemExit => e
    exit e.status
rescue Exception => e
    usage "a exception was caught trying to process the arguments, error: " << e.message    
end

# ok, lets classify
begin
    if @options[:withlock]
        begin
            Timeout::timeout( @options[:timeout] ) {
                @options[:lock] = File.open( @options[:lock_file], File::RDWR | File::CREAT , 0644 ) 
                @options[:lock].flock( File::LOCK_EX ) 
            }
        rescue Timeout::Error => e
            raise Exception, "exceeded timeout #{@options[:timeout]} secs, trying to acquire lock file #{@options[:lock_file]}"
        end
    end
    enc = PuppetENC::new @options
    enc.classify( @options[:hosts] ) do |definition|
        case @options[:output]
        when 'json'
            puts definition.to_json
        when 'yaml'
            puts definition.to_yaml
        end
    end
rescue Exception => e
    usage "exception caught trying to classify, error: " << e.message
rescue SystemExit => e
    exit e.status
ensure 
    @options[:lock].flock( File::LOCK_UN ) if @options[:lock]
end
