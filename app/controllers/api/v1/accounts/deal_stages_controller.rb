# frozen_string_literal: true

module Api
  module V1
    module Accounts
      class DealStagesController < BaseController
        before_action :set_account
        before_action :set_pipeline
        before_action :set_stage, only: %i[show update destroy reorder]

        def index
          stages = @pipeline.deal_stages.ordered
          render json: stages.as_json, status: :ok
        end

        def show
          render json: @stage.as_json, status: :ok
        end

        def create
          stage = @pipeline.deal_stages.new(stage_params.merge(account_id: @account.id))
          if stage.save
            render json: stage.as_json, status: :created
          else
            render json: { errors: stage.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @stage.update(stage_params)
            render json: @stage.as_json, status: :ok
          else
            render json: { errors: @stage.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @stage.destroy
          head :no_content
        end

        # POST /reorder  body: { order: [{id: 1, position: 1}, ...] }
        def reorder
          ActiveRecord::Base.transaction do
            (params[:order] || []).each do |item|
              @pipeline.deal_stages.where(id: item[:id]).update_all(position: item[:position].to_i)
            end
          end
          head :no_content
        end

        private

        def set_account
          @account = Current.account || Account.find(params[:account_id])
        end

        def set_pipeline
          @pipeline = @account.deal_pipelines.find(params[:deal_pipeline_id])
        end

        def set_stage
          @stage = @pipeline.deal_stages.find(params[:id])
        end

        def stage_params
          params.require(:deal_stage).permit(:name, :position, :win_stage, :lose_stage, :probability)
        end
      end
    end
  end
end
