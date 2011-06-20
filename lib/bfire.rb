require 'uuidtools'

require 'bfire/pub_sub/publisher'
require 'bfire/provider/puppet'
require 'bfire/version'
require 'bfire/engine'

module Bfire
  class Error < StandardError; end
end