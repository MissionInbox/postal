# frozen_string_literal: true

Rails.application.routes.draw do
  # Legacy API Routes
  match "/api/v1/send/message" => "legacy_api/send#message", via: [:get, :post, :patch, :put]
  match "/api/v1/send/raw" => "legacy_api/send#raw", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/message" => "legacy_api/messages#message", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/deliveries" => "legacy_api/messages#deliveries", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/status" => "legacy_api/messages#status", via: [:get, :post, :patch, :put]
  match "/api/v1/messages/bulk_status" => "legacy_api/messages#bulk_status", via: [:get, :post, :patch, :put]
  match "/api/v1/domains/create" => "legacy_api/domains#create", via: [:get, :post, :patch, :put]
  match "/api/v1/domains/verify" => "legacy_api/domains#verify", via: [:get, :post, :patch, :put]
  match "/api/v1/domains/dns_records" => "legacy_api/domains#dns_records", via: [:get, :post, :patch, :put]
  match "/api/v1/domains/delete/:name" => "legacy_api/domains#delete", via: [:get, :post, :patch, :put, :delete]
  match "/api/v1/domains/delete" => "legacy_api/domains#delete", via: [:get, :post, :patch, :put, :delete]
  match "/api/v1/domains/list" => "legacy_api/domains#list", via: [:get, :post, :patch, :put]
  match "/api/v1/servers/list" => "legacy_api/servers#list", via: [:get, :post, :patch, :put]
  match "/api/v1/servers/show" => "legacy_api/servers#show", via: [:get, :post, :patch, :put]
  match "/api/v1/servers/create" => "legacy_api/servers_public#create", via: [:get, :post, :patch, :put]
  match "/api/v1/servers/delete" => "legacy_api/servers_public#delete", via: [:get, :post, :patch, :put]
  match "/api/v1/organizations/list" => "legacy_api/organizations#index", via: [:get, :post, :patch, :put]
  match "/api/v1/organizations/show" => "legacy_api/organizations#show", via: [:get, :post, :patch, :put]
  match "/api/v1/servers/ip_addresses" => "legacy_api/ip_addresses#index", via: [:get, :post, :patch, :put]
  match "/api/v1/servers/ip_pools" => "legacy_api/ip_pools#index", via: [:get, :post, :patch, :put]
  match "/api/v1/servers/ip_pools/create" => "legacy_api/ip_pools#create", via: [:get, :post, :patch, :put]
  match "/api/v1/servers/ip_pools/least_used" => "legacy_api/ip_pools#least_used", via: [:get, :post, :patch, :put]

  scope "org/:org_permalink", as: "organization" do
    resources :domains, only: [:index, :new, :create, :destroy] do
      match :verify, on: :member, via: [:get, :post]
      get :setup, on: :member
      post :check, on: :member
      post :verify_all, on: :collection
      get :export, on: :collection
    end
    resources :servers, except: [:index] do
      resources :domains, only: [:index, :new, :create, :destroy] do
        match :verify, on: :member, via: [:get, :post]
        get :setup, on: :member
        post :check, on: :member
        post :verify_all, on: :collection
        get :export, on: :collection
      end
      resources :track_domains do
        post :toggle_ssl, on: :member
        post :check, on: :member
      end
      resources :credentials
      resources :routes
      resources :http_endpoints
      resources :smtp_endpoints
      resources :address_endpoints
      resources :ip_pool_rules
      resources :messages do
        get :incoming, on: :collection
        get :outgoing, on: :collection
        get :held, on: :collection
        delete :purge_held_messages, on: :collection
        get :activity, on: :member
        get :plain, on: :member
        get :html, on: :member
        get :html_raw, on: :member
        get :attachments, on: :member
        get :headers, on: :member
        get :attachment, on: :member
        get :download, on: :member
        get :spam_checks, on: :member
        post :retry, on: :member
        post :cancel_hold, on: :member
        get :suppressions, on: :collection
        delete :remove_suppression, on: :collection
        delete :remove_all_suppressions, on: :collection
        delete :remove_from_queue, on: :member
        get :deliveries, on: :member
      end
      resources :webhooks do
        get :history, on: :collection
        get "history/:uuid", on: :collection, action: "history_request", as: "history_request"
      end
      resources :email_ip_mappings
      get :limits, on: :member
      get :retention, on: :member
      get :queue, on: :member
      delete :purge_queued_messages, on: :member
      get :spam, on: :member
      get :delete, on: :member
      get "help/outgoing" => "help#outgoing"
      get "help/incoming" => "help#incoming"
      get :advanced, on: :member
      post :suspend, on: :member
      post :unsuspend, on: :member
    end

    resources :ip_pool_rules
    resources :ip_pools, controller: "organization_ip_pools" do
      put :assignments, on: :collection
    end
    root "servers#index"
    get "settings" => "organizations#edit"
    patch "settings" => "organizations#update"
    get "delete" => "organizations#delete"
    delete "delete" => "organizations#destroy"
  end

  resources :organizations, except: [:index]
  resources :users
  resources :ip_pools do
    resources :ip_addresses
    resources :ip_pool_ip_addresses, only: [:new, :create], path: 'add_ip'
  end

  get "settings" => "user#edit"
  patch "settings" => "user#update"
  post "persist" => "sessions#persist"

  get "login" => "sessions#new"
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy"
  match "login/reset" => "sessions#begin_password_reset", :via => [:get, :post]
  match "login/reset/:token" => "sessions#finish_password_reset", :via => [:get, :post]

  if Postal::Config.oidc.enabled?
    get "auth/oidc/callback", to: "sessions#create_from_oidc"
  end

  get ".well-known/jwks.json" => "well_known#jwks"

  get "ip" => "sessions#ip"

  root "organizations#index"
end
