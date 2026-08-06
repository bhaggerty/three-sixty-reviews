Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Union Station polls this for liveness (see memory: reference_union_station).
  get "health" => "health#show"

  root "reviews#index"

  resources :assignments, only: [ :index, :show ], controller: "reviews" do
    resource :response, only: [ :create, :update ], controller: "reviews"
    resource :share_request, only: [ :create ]
  end

  namespace :admin do
    resources :review_cycles, only: [ :index, :new, :create ]
    post "send_reminders" => "reminders#create"

    namespace :reviews do
      resources :share_requests, only: [ :index ] do
        member do
          post :approve
          post :deny
        end
      end
      resources :grants, only: [ :index ] do
        member do
          post :revoke
        end
      end
    end
    resource :org_chart, only: [], controller: "org_chart" do
      post :resync
    end
  end

  # Paths match the plan doc's documented Slack app config exactly
  # (Request URL: /slack/commands, /slack/interactions) even though the
  # controllers live under the Api::Slack:: module for code organization.
  post "/slack/commands" => "api/slack/commands#create"
  post "/slack/interactions" => "api/slack/interactions#create"

  get "/sign_in" => "sessions#new"
  get "/auth/:provider/callback" => "sessions#create"
  get "/auth/failure" => "sessions#failure"
  delete "/logout" => "sessions#destroy"
end
