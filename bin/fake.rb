#!/usr/bin/env ruby

require 'httparty'
require 'byebug'
require 'openssl'


OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE


require './storage/interface'

id = $ARGV[0]

puts "You forgot the id IDIOT" unless id

job = Rocksteady::Storage::Orders.find_meta_by_id id


amount = job['print_request']['total_cost'].to_f * 100


message = {
  echoCheckCode: 'oob5Eshohpee6eir',
  responsecode: '00',
  message: 'AUTHCODE:487858',
  qaname: 'MR Chris McCauley',
  avscv2responsecode: '',
  amount: "#{amount}",
  currencycode: "978",
  crossreference: 'Harcourt Test System',
  PrintRequestToken: "#{id}"
}

headers = {
  'Accept-Language' => 'en-US,en;q=0.8',
  'Accept' => 'application/json,text/html'
}

auth = {:username => 'rockSteady', :password => 'Simpsons'}


puts "If you are NOT running on Production, change the post to use https"

HTTParty.post('http://127.0.0.1/upg/echo',
             :headers => headers,
             :body => message,
             :basic_auth => auth)
