# frozen_string_literal: true

module Api
  module V1
    module Accounts
      class DealPipelinesController < BaseController
        before_action :set_account
        before_action :set_pipeline, only: %i[show update destroy reorder]

        def index
          pipelines = @account.deal_pipelines.ordered
          render json: pipelines.as_json, status: :ok
        end

        def show
          render json: @pipeline.as_json, status: :ok
        end

        def create
          pipeline = @account.deal_pipelines.new(pipeline_params)
          if pipeline.save
            render json: pipeline.as_json, status: :created
          else
            render json: { errors: pipeline.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def update
          if @pipeline.update(pipeline_params)
            render json: @pipeline.as_json, status: :ok
          else
            render json: { errors: @pipeline.errors.full_messages }, status: :unprocessable_entity
          end
        end

        def destroy
          @pipeline.destroy
          head :no_content
        end

        # POST /reorder  body: { order: [{id: 10, position: 1}, ...] }
        def reorder
          ActiveRecord::Base.transaction do
            (params[:order] || []).each do |item|
              @account.deal_pipelines.where(id: item[:id]).update_all(position: item[:position].to_i)
            end
          end
          head :no_content
        end

        private

        def set_account
          @account = Current.account || Account.find(params[:account_id])
        end

        def set_pipeline
          @pipeline = @account.deal_pipelines.find(params[:id])
        end

        def pipeline_params
          params.require(:deal_pipeline).permit(:name, :is_default, :position)
        end
      end
    end
  end
end
