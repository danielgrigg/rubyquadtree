# run all the tests

$LOAD_PATH.unshift File.dirname(__FILE__)
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../src"
require 'test_bbox'
require 'test_quad_tree_accelerator.rb'
