# frozen_string_literal: true

module Api
  module V1
    module Accounts
      class DealsController < BaseController
        before_action :set_account
        before_action :set_deal, only: %i[show update destroy move win lose archive reopen]

        # GET /api/v1/accounts/:account_id/deals
        # filtros opcionais: ?deal_pipeline_id=..&deal_stage_id=..&status=open|won|lost|archived
        def index
          deals = @account.deals.includes(:deal_pipeline, :deal_stage).recent
          deals = deals.where(deal_pipeline_id: params[:deal_pipeline_id]) if params[:deal_pipeline_id].present?
          deals = deals.where(deal_stage_id: params[:deal_stage_id])       if params[:deal_stage_id].present?
          deals = deals.where(status: params[:status])                     if params[:status].present?
          render json: deals.as_json, status: :ok
        end

        def show
          render json: @deal.as_json, status: :ok
        end

        def create
          deal = @account.deals.new(deal_params)
          if deal.save
            render json: deal.as_json, status: :created
          else
            render json: { errors: deal.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @deal.update(deal_params)
            render json: @deal.as_json, status: :ok
          else
            render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @deal.destroy
          head :no_content
        end

        # POST /move  body: { deal_stage_id: X, deal_pipeline_id: (opcional) }
        def move
          stage_id = params.require(:deal_stage_id)
          pipeline_id = params[:deal_pipeline_id] || DealStage.find(stage_id).deal_pipeline_id

          if @deal.update(deal_stage_id: stage_id, deal_pipeline_id: pipeline_id)
            render json: @deal.as_json, status: :ok
          else
            render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def win
          if @deal.update(status: 'won', closed_at: Time.current)
            render json: @deal.as_json, status: :ok
          else
            render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def lose
          if @deal.update(status: 'lost', closed_at: Time.current)
            render json: @deal.as_json, status: :ok
          else
            render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def archive
          if @deal.update(status: 'archived')
            render json: @deal.as_json, status: :ok
          else
            render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def reopen
          if @deal.update(status: 'open', closed_at: nil)
            render json: @deal.as_json, status: :ok
          else
            render json: { errors: @deal.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_account
          @account = Current.account || Account.find(params[:account_id])
        end

        def set_deal
          @deal = @account.deals.find(params[:id])
        end

        def deal_params
          params.require(:deal).permit(
            :deal_pipeline_id, :deal_stage_id, :title, :amount_cents, :currency,
            :status, :source, :owner_id, :contact_id, :inbox_id, :conversation_id,
            :closed_at, custom_fields: {}
          )
        end
      end
    end
  end
end
