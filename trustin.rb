require "json"
require "net/http"

class TrustIn
  def initialize(evaluations)
    @evaluations = evaluations
  end

  def update_durability()
    @evaluations.each do |evaluation|
      next if evaluation.durability < 0
      # When the durability is greater than 0 and the state is unconfirmed for an ongoing api database update, a new evaluation is done;
      # When the durability is equal to 0, a new evaluation is done
      if evaluation.state == "unconfirmed" && evaluation.reason == "ongoing_database_update" || evaluation.durability == 0
        uri = URI("https://public.opendatasoft.com/api/records/1.0/search/?dataset=sirene_v3" \
          "&q=#{evaluation.value}&sort=datederniertraitementetablissement" \
          "&refine.etablissementsiege=oui")
        response = Net::HTTP.get(uri)
        parsed_response = JSON.parse(response)
        company_state = parsed_response["records"].first["fields"]["etatadministratifetablissement"]
        if company_state == "Actif"
          evaluation.state = "favorable"
          evaluation.reason = "company_opened"
          evaluation.durability = 100
        else
          evaluation.state = "unfavorable"
          evaluation.reason = "company_closed"
          evaluation.durability = 100
        end
      # When the durability is greater than 0 and the state is favorable, the company registration evaluation's durability decreases of 1 point
      elsif evaluation.durability > 0 && evaluation.state == "favorable"
        evaluation.durability = calculate_durability(evaluation.durability, -1, evaluation.state)

      # When the state is unconfirmed because the api is unreachable
      elsif evaluation.state == "unconfirmed" && evaluation.reason == "unable_to_reach_api"
        # and the durability is equal or greater than 50
        if evaluation.durability >= 50
          if evaluation.type == "SIREN"
          # the SIREN evaluation's durability decreases of 5 points
          evaluation.durability = calculate_durability(evaluation.durability, -5, evaluation.state)
          elsif evaluation.type == "VAT"
          # the VAT evaluation's durability decreases of 1 point;
          evaluation.durability = calculate_durability(evaluation.durability, -1, evaluation.state)
          end
        # and the durability is equal or lower than 50
        else
          if evaluation.type == "SIREN"
            # the SIREN evaluation's durability decreases of 1 points
            evaluation.durability = calculate_durability(evaluation.durability, -1, evaluation.state)
          elsif evaluation.type == "VAT"
            #the VAT evaluation's durability decreases of 3 point;
            evaluation.durability = calculate_durability(evaluation.durability, -3, evaluation.state)
          end
        end
      end
    end
  end

  def calculate_durability(current_durability, point, state)
    return current_durability if state == "unfavorable"
    max(current_durability + point, 0)
  end
end

class Evaluation
  attr_accessor :type, :value, :durability, :state, :reason

  def initialize(type:, value:, durability:, state:, reason:)
    @type = type
    @value = value
    @durability = durability
    @state = state
    @reason = reason
  end

  def to_s()
    "#{@type}, #{@value}, #{@durability}, #{@state}, #{@reason}"
  end
end
