require 'spaceship/connect_api/models/app_screenshot_set'
require 'spaceship/connect_api/models/app_preview_set'

module Deliver
  class DeviceHelper
    #
    module ScreenSize
      # iPhone 4
      IOS_35 = "iOS-3.5-in"
      # iPhone 5
      IOS_40 = "iOS-4-in"
      # iPhone 6, 7, & 8
      IOS_47 = "iOS-4.7-in"
      # iPhone 6 Plus, 7 Plus, & 8 Plus
      IOS_55 = "iOS-5.5-in"
      # iPhone XS
      IOS_58 = "iOS-5.8-in"
      # iPhone XR
      IOS_61 = "iOS-6.1-in"
      # iPhone XS Max
      IOS_65 = "iOS-6.5-in"

      # iPad
      IOS_IPAD = "iOS-iPad"
      # iPad 10.5
      IOS_IPAD_10_5 = "iOS-iPad-10.5"
      # iPad 11
      IOS_IPAD_11 = "iOS-iPad-11"
      # iPad Pro
      IOS_IPAD_PRO = "iOS-iPad-Pro"
      # iPad Pro (12.9-inch) (3rd generation)
      IOS_IPAD_PRO_12_9 = "iOS-iPad-Pro-12.9"

      # iPhone 5 iMessage
      IOS_40_MESSAGES = "iOS-4-in-messages"
      # iPhone 6, 7, & 8 iMessage
      IOS_47_MESSAGES = "iOS-4.7-in-messages"
      # iPhone 6 Plus, 7 Plus, & 8 Plus iMessage
      IOS_55_MESSAGES = "iOS-5.5-in-messages"
      # iPhone XS iMessage
      IOS_58_MESSAGES = "iOS-5.8-in-messages"
      # iPhone XR iMessage
      IOS_61_MESSAGES = "iOS-6.1-in-messages"
      # iPhone XS Max iMessage
      IOS_65_MESSAGES = "iOS-6.5-in-messages"

      # iPad iMessage
      IOS_IPAD_MESSAGES = "iOS-iPad-messages"
      # iPad 10.5 iMessage
      IOS_IPAD_10_5_MESSAGES = "iOS-iPad-10.5-messages"
      # iPad 11 iMessage
      IOS_IPAD_11_MESSAGES = "iOS-iPad-11-messages"
      # iPad Pro iMessage
      IOS_IPAD_PRO_MESSAGES = "iOS-iPad-Pro-messages"
      # iPad Pro (12.9-inch) (3rd generation) iMessage
      IOS_IPAD_PRO_12_9_MESSAGES = "iOS-iPad-Pro-12.9-messages"

      # Apple Watch
      IOS_APPLE_WATCH = "iOS-Apple-Watch"
      # Apple Watch Series 4
      IOS_APPLE_WATCH_SERIES4 = "iOS-Apple-Watch-Series4"

      # Apple TV
      APPLE_TV = "Apple-TV"

      # Mac
      MAC = "Mac"
    end

    # Nice name
    def formatted_name
      matching = {
        ScreenSize::IOS_35 => "iPhone 4",
        ScreenSize::IOS_40 => "iPhone 5",
        ScreenSize::IOS_47 => "iPhone 6", # also 7 & 8
        ScreenSize::IOS_55 => "iPhone 6 Plus", # also 7 Plus & 8 Plus
        ScreenSize::IOS_58 => "iPhone XS",
        ScreenSize::IOS_61 => "iPhone XR",
        ScreenSize::IOS_65 => "iPhone XS Max",
        ScreenSize::IOS_IPAD => "iPad",
        ScreenSize::IOS_IPAD_10_5 => "iPad 10.5",
        ScreenSize::IOS_IPAD_11 => "iPad 11",
        ScreenSize::IOS_IPAD_PRO => "iPad Pro",
        ScreenSize::IOS_IPAD_PRO_12_9 => "iPad Pro (12.9-inch) (3rd generation)",
        ScreenSize::IOS_40_MESSAGES => "iPhone 5 (iMessage)",
        ScreenSize::IOS_47_MESSAGES => "iPhone 6 (iMessage)", # also 7 & 8
        ScreenSize::IOS_55_MESSAGES => "iPhone 6 Plus (iMessage)", # also 7 Plus & 8 Plus
        ScreenSize::IOS_58_MESSAGES => "iPhone XS (iMessage)",
        ScreenSize::IOS_61_MESSAGES => "iPhone XR (iMessage)",
        ScreenSize::IOS_65_MESSAGES => "iPhone XS Max (iMessage)",
        ScreenSize::IOS_IPAD_MESSAGES => "iPad (iMessage)",
        ScreenSize::IOS_IPAD_PRO_MESSAGES => "iPad Pro (iMessage)",
        ScreenSize::IOS_IPAD_PRO_12_9_MESSAGES => "iPad Pro (12.9-inch) (3rd generation) (iMessage)",
        ScreenSize::IOS_IPAD_10_5_MESSAGES => "iPad 10.5 (iMessage)",
        ScreenSize::IOS_IPAD_11_MESSAGES => "iPad 11 (iMessage)",
        ScreenSize::MAC => "Mac",
        ScreenSize::IOS_APPLE_WATCH => "Watch",
        ScreenSize::IOS_APPLE_WATCH_SERIES4 => "Watch Series4",
        ScreenSize::APPLE_TV => "Apple TV"
      }
      return matching[self.screen_size]
    end

    #
    def is_messages?
      return [
        ScreenSize::IOS_40_MESSAGES,
        ScreenSize::IOS_47_MESSAGES,
        ScreenSize::IOS_55_MESSAGES,
        ScreenSize::IOS_58_MESSAGES,
        ScreenSize::IOS_65_MESSAGES,
        ScreenSize::IOS_IPAD_MESSAGES,
        ScreenSize::IOS_IPAD_PRO_MESSAGES,
        ScreenSize::IOS_IPAD_PRO_12_9_MESSAGES,
        ScreenSize::IOS_IPAD_10_5_MESSAGES,
        ScreenSize::IOS_IPAD_11_MESSAGES
      ].include?(self.screen_size)
    end

  end

  ScreenSize = DeviceHelper::ScreenSize
end