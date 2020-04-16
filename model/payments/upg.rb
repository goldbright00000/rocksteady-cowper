require './lib/logging'


module Rocksteady
  module UPG

    #
    #   This is triggered by UPG telling us that the payment worked.
    #   This is spoofable as no certs are in place to ensure that
    #   it is UPG sending the message.
    #
    def self.handle_successful_echo_response(params)
      print_job_id    = params['PrintRequestToken'] rescue nil
      amount          = params['amount'].to_f rescue nil
      currency_code   = params['currencycode'] rescue nil


      _return = nil

      if print_job_id && amount && currency_code
        #
        #   Got an apparently valid & successful purchase
        #
        #   e.g. "amount"=>"821", "currencycode"=>"978", "PrintRequestToken"=>"53fc9db6098f6b654c000082"}
        #
        #

        #
        #   UPG sends the amount in pence, cents, etc
        #
        amount /= 100

        _return = Rocksteady::Orders.attempt_payment(print_job_id, amount, currency_code)
      end

      _return
    end




    #
    #   This is triggered by UPG telling us that the payment failed
    #   This is spoofable as no certs are in place to ensure that
    #   it is UPG sending the message.
    #
    def self.handle_failure_echo_response(params)
      print_job_id = params['PrintRequestToken'] rescue nil
      reason       = params['message'] rescue 'No message given'

      if print_job_id
        Rocksteady::Logging.info("UPG says payment failed for order #{print_job_id} because '#{reason}'")

        Rocksteady::Orders.payment_failed(print_job_id)
      end
    end




    #
    #   This is triggered by the UI (not UPG) telling us that the payment failed
    #   This is NOT verifiable.
    #
    def self.handle_purchase_lose(params)
      print_job_id = params['PrintRequestToken'] rescue nil
      reason  = params['message'] rescue 'No message given'

      if print_job_id
        Rocksteady::Logging.info("UI says payment failed for order #{print_job_id} because '#{reason}'")

        Rocksteady::Orders.payment_failed(print_job_id)
      end
    end

  end
end
