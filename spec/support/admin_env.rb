# User.admin? is derived from ADMIN_SLACK_USER_IDS (see app/models/user.rb
# for why it's not a stored/DB-mutable attribute). This must be set before
# User is first loaded, since the allowlist is frozen into a constant at
# class-load time -- hence a plain support file required early by
# rails_helper, not a before(:each) hook.
ENV["ADMIN_SLACK_USER_IDS"] = "ADMIN-TEST-SLACK-ID"
