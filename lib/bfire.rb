require 'backports'
require 'logger'

require 'bfire/ext'
require 'bfire/version'
require 'bfire/campaign'
require 'bfire/api'


module Bfire
  class Error < StandardError; end
  
  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new(STDOUT).tap {|l| l.level = Logger::INFO }
    end
  end
end