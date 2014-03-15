#
# Author: Rohith 
# Date:   2014-03-03 23:54:57
# Last Modified by:   Rohith
#
# vim:ts=4:sw=4:et
#
require 'pp'
module PuppetENC
module Utils

    [:info,:error,:warn,:debug,:fatal].each do |m|
        define_method m do |*args,&block|
            Log.send m, *args, &block
        end
    end

end
end