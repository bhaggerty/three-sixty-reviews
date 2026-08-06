require "rails_helper"

RSpec.describe "Admin::Reminders", type: :request do
  let(:admin) { build(:user, :admin) }
  let(:non_admin) { build(:user) }

  describe "POST /admin/send_reminders" do
    it "enqueues the reminder job for an admin" do
      sign_in(admin)

      expect {
        post admin_send_reminders_path
      }.to have_enqueued_job(Reviews::ReminderJob)

      expect(response).to redirect_to(root_path)
    end

    it "forbids a non-admin" do
      sign_in(non_admin)

      expect {
        post admin_send_reminders_path
      }.not_to have_enqueued_job(Reviews::ReminderJob)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
