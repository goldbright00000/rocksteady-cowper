#
#  The purchase_win is sent by the UI when the payment apparently works.
#  We take no real action on this message as it is not from UPG.  It's
#  only purpose is to trigger an appropriate UI change
#
#
#  The message can be in two different formats; one for credit cards ...
#
# GET /upg/purchase_win?
# responsecode=00
# message=AUTHCODE%3a956544
# qaname=John+Jones
# avscv2responsecode=200000
# amount=16382
# currencycode=036
# crossreference=151014104053956544E0S
# PrintRequestToken=561e216bfd897806ef0005aa
# NonIframeRetOKAddress=https://app.motocal.com/app/#/kits/-/-/-/-/5613087afd89786805001487/checkout/purchased/je.smjones%40iinet.net.au/
# NonIframeRetNotOKAddress=https://app.motocal.com/app/#/kits/-/-/-/-/5613087afd89786805001487/checkout/declined/
#
#  ... and one for PayPal ...
#
# GET /purchase_win?
# responsecode=00
# message=Authorised
# paypalpaymentid=PAY-2UM663579V655652BKYOEKMQ
# paypaltransactionid=4SK06341YF1032301
# qaname=max+piskula
# qaaddress=7100+decator+dr%2c+wausau%2c+WI
# qapostcode=54401
# qaphonenumber=7152189455
# qaemailaddress=maxpiskula5%40gmail.com
# amount=9021
# currencycode=840
# PrintRequestToken=561c4508fd89780733000482
# NonIframeRetOKAddress=https://app.motocal.com/app/#/kits/Honda/CR125R/Motocross/2002_2004/56199a8cfd897807330002bb/checkout/purchased/maxpiskula5@gmail.com/
# NonIframeRetNotOKAddress=https://app.motocal.com/app/#/kits/Honda/CR125R/Motocross/2002_2004/56199a8cfd897807330002bb/checkout/declined/

#   NB There is no change to the job status on purchase_win
#
get '/purchase_win', provides: :html do
  status Rocksteady::Ok

  @print_request_id = params['PrintRequestToken'] rescue 'There was a problem processing your order.'

  address = params['NonIframeRetOKAddress']

  raise Rocksteady::RS_BadParams.new('There was no NonIframeRetOkAddress') unless address

  #
  #   'NonIframeRetOKAddress' provided by our Javascript
  #
  #   This line provided by David
  #
  @non_iframe_redirect_url = address + URI.escape(@print_request_id, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

  @domain_of_client = "https://#{Rocksteady::Config.url_hostname}"

  haml :'/upg/purchase_win'
end





#
#  The purchase_lose is sent by the UI when the payment fails.
#  We take no real action on this message as it is not from UPG.  It's
#  only purpose is to trigger an appropriate UI change
#
#
#/upg/purchase_lose?
# responsecode=05
# message=CARD+DECLINED
# qaname=BJORN+J+BAKER
# threedserrorcode=1007
# threedserrordetail=Non+participating+PAN+XXXXXXXXXXXX7972
# crossreference=151014072329U61790ERL
# PrintRequestToken=561df4bdfd897806e10005b6
# NonIframeRetOKAddress=https://app.motocal.com/app/#/kits/-/-/-/-/561ad37dfd89780720000374/checkout/purchased/bjorn.baker@miltonabbey.co.uk/
# NonIframeRetNotOKAddress=https://app.motocal.com/app/#/kits/-/-/-/-/561ad37dfd89780720000374/checkout/declined/
#
#
#
#
#/upg/purchase_lose?
# responsecode=05
# message=cancelled
# paypalpaymentid=PAY-1PF78765RE858853AKYBWNSY
# paypaltransactionid=
# amount=13220
# currencycode=840
# PrintRequestToken=56036683fd8978684f000db4
# NonIframeRetOKAddress=https://app.motocal.com/app/#/kits/-/-/-/-/55e3c16bfd89784621000076/checkout/purchased/codyschroeder52%40gmail.com/
# NonIframeRetNotOKAddress=https://app.motocal.com/app/#/kits/-/-/-/-/55e3c16bfd89784621000076/checkout/declined/
#
#
#   NB There is no change to the job status on purchase_win
#
get '/purchase_lose', provides: :html do
  status Rocksteady::Ok

  Rocksteady::UPG.handle_purchase_lose(params)

  @upg_failure_message = params['message'] rescue 'No reason given'

  address = params['NonIframeRetNotOKAddress']

  raise Rocksteady::RS_BadParams.new('There was no NonIframeRetNotOkAddress') unless address

  #
  #   'NonIframeRetOKAddress' provided by our Javascript
  #
  #   This line provided by David
  #
  @non_iframe_redirect_url = address + URI.escape(@upg_failure_message, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

  @domain_of_client = "https://#{Rocksteady::Config.url_hostname}"

  haml :'/upg/purchase_lose'
end





#
#  The echo response is sent after a payment is attempted
#
#  Failure ...
#
#{"echoCheckCode"=>"oob5Eshohpee6eir", "responsecode"=>"30", "message"=>"3DS COMPLETE AUTHENTICATION FAILED", "errorcode"=>"3050", "qaname"=>"5453010000070789", "threedserrorcode"=>"1143", "threedserrordetail"=>"Cardholder could not be authenticated status code: N", "PrintRequestToken"=>"53fc5f6a830f7873ca000005"}
#
#  Success ...
#
#{"echoCheckCode"=>"oob5Eshohpee6eir", "responsecode"=>"00", "message"=>"AUTHCODE:487858", "qaname"=>"4909630000000008", "avscv2responsecode"=>"", "amount"=>"821", "currencycode"=>"978", "crossreference"=>"140826154500487858E23", "PrintRequestToken"=>"53fc9db6098f6b654c000082"}
#
#
post '/echo', provides: :html do
  #
  #   UPG expect 200, 'rocksteady_ok' no matter what happens
  #
  status Rocksteady::Ok

  Rocksteady::Logging.info "Cowper got an echo response from UPG #{params}"

  upg_response_code = params["responsecode"] rescue nil


  case upg_response_code
  when nil
    Rocksteady::Logging.warn "Cowper received a badly formatted message from UPG #{params}"
  when '00'
    #
    #   Update the model
    #
    job = Rocksteady::UPG.handle_successful_echo_response(params)

    #
    #   Let any listening mq clients know that the purchase worked
    #
    Rocksteady::Notification.purchase_win(job) if job
  else
    Rocksteady::UPG.handle_failure_echo_response(params)
  end

  #
  #   UPG want this stupid response
  #
  'rocksteady_ok'
end
