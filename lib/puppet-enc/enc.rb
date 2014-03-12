#
# Author: Rohith 
# Date:   2014-03-03 23:54:57
# Last Modified by:   Rohith
#
# vim:ts=4:sw=4:et
#
require 'yaml'

module PuppetENC
class Classify

    @@mains_sections = [ 'nodes', 'groups', 'stats' ]

    def initialize options
        @classify    = {}
        # step: lets load the classification file
        load options[:classify]
    end

    def list( filter = nil )
        item = { :items => @classify['nodes'] }
    end

    def classify hosts, &block
        raise ArgumentError, "classify: the you not specified any hosts"    unless hosts
        raise ArgumentError, "classify: the hosts must be an array"         unless hosts.is_a?( Array )
        raise ArgumentError, "classify: you need to supply a block"         unless block_given?
        node_classify hosts do |item|
            yield item
        end
    end

    def add( hostname, domain, classes )
        # step: check the node definition doesn't exists already
        raise DuplicateNodeError, "a node definition already exist, please delete or update" if has_host?( hostname, domain )
        nodename = get_key hostname, domain
        add_node nodename, classes
    end

    def remove( hostname, domain )
        nodename = get_key hostname, domain
        unless has_host?( hostname, domain )
            raise NoHostClassifiedError, "a definition for host: %s domain: %s does not exist" % [ hostname, domain ]
        end
        remove_node nodename
    end

    def get( hostname, domain )
        has_host?( hostname, domain, true )
    end

    def update( hostname, domain, classes )
        nodename = get_key hostname, domain
        unless has_host?( hostname, domain )
            raise NoHostClassifiedError, "a definition for host: %s domain: %s does not exist" % [ hostname, domain ]
        end
        add_node nodename, classes, true
    end

    def has_host?( hostname, domain, exception_on_fail = false )
        nodename = get_key hostname, domain
        host?( nodename, exception_on_fail )
    end

    private
    def load( filename )
        begin 
            @classification_file = filename
            info "load: loading the classification file %s" % [ filename ]
            @classify = YAML.load_file( @classification_file )
            info "load: loaded the classification file successfully"
            info "load: check we have the main groups"
            @@mains_sections.each do |section|
                info "load: checking for #{section} section"
                raise ArgumentError, "the #{section} is missing in the classification file" unless @classify[section]
            end
        rescue YAML::ParseError => e 
            fatal "load: you have a syntax error in the classification file, error: %s " % [ e.message ]
            raise Exception, e.message
        rescue Exception => e 
            fatal "load: unable to load classification file %s, error: %s" % [ @classify, e.message ]
            raise Exception, e.message
        end
        @classify
    end

    def host?( nodename, exception_on_fail = false )
        unless @classify['nodes'].has_key?( nodename )
            raise NoHostClassifiedError, "the node %s is not classified" % [ nodename ] if exception_on_fail
            return nil
        end
        @classify['nodes'][nodename]
    end

    # update_node: (true|false)     if the node is ready there, it updates the configuration
    def add_node( nodename, config, update_node = false )
        definition = {
            'classes'    => config[:classes],
            'parameters' => config[:parameters] || {},
            'groups'     => {
                'puppet::default' => {}
            }
        }
        raise ArgumentError, "add_node: you haven't read in the classification data yet"                   unless @classify
        raise ArgumentError, "add_node: you havent' specified a nodename"                                  unless nodename
        raise ArgumentError, "add_node: you haven't specified any configuration for the node #{nodename}"  unless config
        raise ArgumentError, "add_node: the configuration for node #{nodename} must be a hash"             unless config.is_a?( Hash )
        raise ArgumentError, "add_node: the configuration for node #{nodename} must contain classes field" unless config.has_key?( :classes )
        # step: check if the node already exists
        if host?( nodename )
            debug "add_node: the node #{nodename} already has an entry"
            raise DuplicateNodeError, "the node #{nodename} already exists"     unless update_node
            info  "add_node: merging the the update config of node #{nodename}"
            @classify['nodes'][nodename].merge!( definition )
            info  "add_node: updating the classification file"
            node_sync
            info  "add_node: successfully updated the classification file"
        else
            begin
                info "add_node: adding new node #{nodename} to classification"
                @classify['nodes'][nodename] = definition
                info "add_node: updating the classification file"
                node_sync
                info "add_node: successfully updated the classification file"
            rescue Exception => e 
                fatal "add_node: unable to add node #{nodename}, error: " << e.message
                raise Exception, e.message
            end
        end
    end

    def remove_node( nodename )
        raise ArgumentError, "you haven't yet read in the classification data"  unless @classify   
        raise ArgumentError, "you havent' specified a nodename"                 unless nodename
        raise NoHostClassifiedError, "the node #{nodename} does not exist"      unless host?( nodename )
        begin
            info "remove_node: request to remove node #{nodename}"
            @classify['nodes'].delete( nodename )
            info "remove_node: updating the classification file %s" % [ @classification_file ]
            system( "/usr/bin/puppet clean %s" % [ nodename ] )
            info "remove_node: removing the node from puppetdb"
            system( "/usr/bin/puppet node deactivate %s" % [ nodename ] )
            node_sync 
            info "remove_node: successfully updated the classification file %s" % [ @classification_file ]
            info "remove_node: successfully removed the node #{nodename} from classification"
        rescue Exception => e 
            fatal "remove_node: unable to remove node #{nodename}, error: " << e.message
            raise Exception, e.message
        end
    end

    def node_classify( hosts, &block )
        begin
            hosts.each do |host|
                # step: check we have the node
                debug "checking for hostname #{host} in classification"
                definition           = {}
                definition[:classes] = {}
                unless @classify['nodes'][host]
                    debug "classify: no classification for host #{host}, handing back the default"
                    definition[:classes].merge!( @classify['groups']['all'] )
                    yield definition if block_given?
                    next
                end

                data = @classify['nodes'][host]
                definition[:parameters] = data['parameters'] if data['parameters']
                raise ArgumentError, "the classification for host #{host} does not contain a classes sections"    unless data.has_key?( 'classes' )
                
                # step: the node is present - lets merge
                if data['groups']
                   data['groups'].each_pair do |merge_group,nop|
                       debug "classify: looking for group #{merge_group}"
                       raise NoGroupClassifiedError, "the group #{merge_group} does not exist" unless @classify['groups'][ merge_group.to_s ]
                       definition[:classes].merge!( @classify['groups'][merge_group] )
                   end
                end
                debug "classify: constructed the groups classes"
                # create a hash for easy lookup
                # get a list of all the classes defined for the host definition
                debug "merging the host clases into the definition"
                if data['classes']
                    definition[:classes].merge!( data['classes'] ) 
                end
                # yield to any blocks given
                yield definition
                definition unless block_given?
            end
        rescue Exception => e 
            fatal "classify: hosts=>#{hosts} caught exception: " << e.message
            raise ClassifyError, e.message
        end
    end

    # updates the classification file with the current config
    def node_sync( filename = @classification_file )
        begin
            info "update: attempting to update the current classification file #{filename}"
            File.open( @classification_file, "w" ) do |fd|
                # we remove the extra newline and the symbols
                fd.puts @classify.to_yaml.gsub( /\n\n/, "\n" ).gsub( /^([ ]+):(.*)/,'\1\2' )
            end
            info "update: successfully updated the config #{filename}"
        rescue Exception => e 
            fatal "update: unable to update the classification file, error: " << e.message
            raise Exception, e.message
        end
    end

    def get_key( hostname, domain )
        "%s.%s" % [ hostname, domain ]
    end

end
end
