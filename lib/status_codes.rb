module Rocksteady
  Ok             = 200
  Created        = 201
  Accepted       = 202
  NoContent      = 204
  BadRequest     = 400
  Unauthorized   = 401
  Forbidden      = 403
  NotFound       = 404
  NotProcessable = 422
  InternalError  = 500


  class RS_Error < StandardError
    attr_reader :code

    def initialize(code, title = '', detail = '')
      @code = code
      @title = title
      @detail = detail
    end

    def to_json
      {
        errors: [
                 {
                   status: "#{@code}",
                   title:  "#{@title}",
                   detail: "#{@detail}"
                 }
                ]
      }.to_json
    end


    def to_s
      "#{@code} : #{@title} - #{@detail}"
    end
  end


  class RS_NotFound < RS_Error

    def initialize(detail)
      super(Rocksteady::NotFound, 'The required resource could not be found', detail)
    end

  end


  class RS_BadParams< RS_Error

    def initialize(detail)
      super(Rocksteady::BadRequest, 'The request cannot be processed as it is semantically invalid', detail)
    end
  end


  class RS_Inconsistent < RS_Error

    def initialize(detail)
      super(Rocksteady::InternalError, 'An internal error has been detected', detail)
    end
  end


  class RS_NotProcessable < RS_Error

    def initialize(detail)
      super(Rocksteady::NotProcessable, 'An internal error has been detected', detail)
    end
  end


  class RS_InternalError < RS_Error

    def initialize(detail)
      super(Rocksteady::InternalError, 'An internal error has been detected', detail)
    end
  end


  def self.is_ok?(status_code)
    [Ok, Created, Accepted].include? status_code
  end
end
