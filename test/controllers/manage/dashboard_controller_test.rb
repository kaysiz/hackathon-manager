require 'test_helper'

class Manage::DashboardControllerTest < ActionController::TestCase
  context "while not authenticated" do
    should "redirect to sign in page on manage_dashboard#index" do
      get :index
      assert_response :redirect
      assert_redirected_to new_user_session_path
    end
  end

  context "while authenticated as a user" do
    setup do
      @user = create(:user)
      @request.env["devise.mapping"] = Devise.mappings[:admin]
      sign_in @user
    end

    should "allow access to manage_dashboard#index" do
      get :index
      assert_response :redirect
      assert_redirected_to root_path
    end
  end

  context "while authenticated as an admin" do
    setup do
      @user = create(:admin)
      @request.env["devise.mapping"] = Devise.mappings[:admin]
      sign_in @user
    end

    should "allow access to manage_dashboard#index" do
      get :index
      assert_response :success
    end

    should "allow access to all data endpoints" do
      school1 = FactoryBot.create(:school)
      school2 = FactoryBot.create(:school)
      FactoryBot.create_list(:questionnaire, 20, school_id: school1.id, acc_status: "pending")
      FactoryBot.create_list(:questionnaire, 20, school_id: school1.id, acc_status: "accepted")
      FactoryBot.create_list(:questionnaire, 10, school_id: school2.id, acc_status: "accepted")
      Questionnaire::POSSIBLE_ACC_STATUS.each do |status, _name|
        FactoryBot.create_list(:questionnaire, 1, school_id: school2.id, acc_status: status)
      end

      stub_request(:get, "https://maps.googleapis.com/maps/api/geocode/json?address=Rochester%20NY&sensor=true").
        to_return(status: 200, body: '{"results":[{"geometry":{"location":{"lat": 100, "lng": 100}}}]}', headers: {'Content-Type' => 'application/json; charset=UTF-8'})
      stub_request(:get, "https://geo.fcc.gov/api/census/area?format=json&lat=100&lon=100").
        to_return(status: 200, body: '{"results":[{"country_fips":1234}]}', headers: {'Content-Type' => 'application/json; charset=UTF-8'})

      paths = [
        :todays_activity_data,
        :todays_stats_data,
        :checkin_activity_data,
        :confirmation_activity_data,
        :application_activity_data,
        :schools_confirmed_data,
        :user_distribution_data,
        :application_distribution_data,
        :schools_applied_data
      ]

      paths.each do |path|
        get path
        assert_response :success
      end

      get :map_data, format: "tsv"
      assert_response :success
    end
  end
end
