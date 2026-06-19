# name: discourse-avatar-frames
# about: Allows users to select animated CSS avatar frames
# version: 0.1
# authors: asa0w0
# url: https://github.com/asa0w0/discourse-avatar-frames

enabled_site_setting :avatar_frames_enabled

register_asset "stylesheets/common/avatar-frames.scss"

after_initialize do
  User.register_custom_field_type('avatar_frame', :string)
  register_editable_user_custom_field(:avatar_frame)

  # Validate frame permissions when user saves their profile
  User.class_eval do
    validate :validate_avatar_frame_permission

    def validate_avatar_frame_permission
      frame = self.custom_fields['avatar_frame']
      return if frame.blank? || frame == 'none'

      config_str = SiteSetting.avatar_frames_config || ""
      allowed = false
      frame_found = false

      config_str.split("|").each do |conf|
        parts = conf.split(":")
        next unless parts.length >= 3
        
        id = parts[0].strip
        if id == frame
          frame_found = true
          condition = parts[2..-1].join(":").strip
          
          if condition.start_with?("tl")
            req_level = condition.sub("tl", "").to_i
            allowed = true if self.trust_level >= req_level
          elsif condition.start_with?("group:")
            req_group = condition.sub("group:", "").strip.downcase
            allowed = true if self.groups.any? { |g| g.name.downcase == req_group }
          end
          
          break
        end
      end

      if frame_found && !allowed
        self.errors.add(:base, "Du hast nicht die benötigte Berechtigung für diesen Avatar Rahmen.")
      elsif !frame_found
        self.errors.add(:base, "Dieser Avatar Rahmen existiert nicht.")
      end
    end
  end

  # Make it public so the frontend can read it everywhere
  allow_public_user_custom_field(:avatar_frame)

  # Expose ALL of the current user's group names (including automatic and
  # hidden groups) so the frontend lock detection matches the server-side
  # permission check exactly. currentUser.groups only contains *visible*
  # groups, which caused group-gated frames to stay locked for eligible users.
  add_to_serializer(:current_user, :avatar_frame_group_names) do
    object.groups.pluck(:name)
  end

  # Serialize into User (Profile / Card)
  add_to_serializer(:user, :avatar_frame) do
    object.custom_fields['avatar_frame']
  end

  add_to_serializer(:user_card, :avatar_frame) do
    object.custom_fields['avatar_frame']
  end

  # Serialize into Post (Topic stream)
  add_to_serializer(:post, :user_avatar_frame, false) do
    object.user&.custom_fields&.[]('avatar_frame')
  end
end
