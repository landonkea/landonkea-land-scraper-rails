Rails.application.routes.draw do
  # The dashboard is the whole app, so it just gets a GET on /listings...
  get "listings", to: "listings#index"
  # ...and it's also what loads at the bare root URL, so visiting the site needs no extra clicks.
  root "listings#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
