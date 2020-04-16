# config.ru
$: << File.expand_path(File.dirname(__FILE__))

require 'run'

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

run Sinatra::Application
