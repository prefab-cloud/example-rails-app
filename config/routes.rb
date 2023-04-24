Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  post '/sign-in-as', to: 'home#sign_in_as'

  # Defines the root path route ("/")
  root 'home#index'
end
