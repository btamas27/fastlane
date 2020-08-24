require_relative 'module'

require 'spaceship/connect_api/models/app_preview_set'
require 'fastlane/helper/sh_helper'
require 'ffprobe'

module Deliver
  # AppPreview represents one preview for one specific locale
  # and device type.
  class AppPreview
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

      # Mac
      MAC = "Mac"
    end

    # @return [Deliver::ScreenSize] the screen size (device type)
    #  specified at {Deliver::ScreenSize}
    attr_accessor :screen_size

    attr_accessor :path

    attr_accessor :language

    def initialize(path, language, screen_size = nil)
      self.path = path
      self.language = language
      screen_size ||= self.class.calculate_screen_size(path)

      self.screen_size = screen_size

      UI.error("Looks like the preview given (#{path}) does not match the requirements of #{screen_size}") unless self.is_valid?
    end

    def device_type
      matching = {
        ScreenSize::IOS_35 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPHONE_35,
        ScreenSize::IOS_40 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPHONE_40,
        ScreenSize::IOS_47 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPHONE_47, # also 7 & 8
        ScreenSize::IOS_55 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPHONE_55, # also 7 Plus & 8 Plus
        ScreenSize::IOS_58 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPHONE_58,
        ScreenSize::IOS_65 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPHONE_65,
        ScreenSize::IOS_IPAD => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPAD_97,
        ScreenSize::IOS_IPAD_10_5 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPAD_105,
        ScreenSize::IOS_IPAD_11 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPAD_PRO_3GEN_11,
        ScreenSize::IOS_IPAD_PRO => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPAD_PRO_129,
        ScreenSize::IOS_IPAD_PRO_12_9 => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::IPAD_PRO_3GEN_129,
        ScreenSize::MAC => Spaceship::ConnectAPI::AppPreviewSet::PreviewType::DESKTOP
      }
      return matching[self.screen_size]
    end

    def formatted_name
      matching = {
        ScreenSize::IOS_35 => "iPhone 4",
        ScreenSize::IOS_40 => "iPhone 5",
        ScreenSize::IOS_47 => "iPhone 6", # also 7 & 8
        ScreenSize::IOS_55 => "iPhone 6 Plus", # also 7 Plus & 8 Plus
        ScreenSize::IOS_58 => "iPhone XS",
        ScreenSize::IOS_65 => "iPhone XS Max",
        ScreenSize::IOS_IPAD => "iPad",
        ScreenSize::IOS_IPAD_10_5 => "iPad 10.5",
        ScreenSize::IOS_IPAD_11 => "iPad 11",
        ScreenSize::IOS_IPAD_PRO => "iPad Pro",
        ScreenSize::IOS_IPAD_PRO_12_9 => "iPad Pro (12.9-inch) (3rd generation)",
        ScreenSize::MAC => "Mac"
      }
      return matching[self.screen_size]
    end

    def is_valid?
      return false unless ["mov", "m4v", "mp4"].include?(self.path.split(".").last)

      return self.screen_size == self.class.calculate_screen_size(self.path)
    end

    # reference: https://help.apple.com/app-store-connect/#/dev4e413fcb8
    def self.devices
      # This list does not include iPad Pro 12.9-inch (3rd generation)
      # because it has same resolution as IOS_IPAD_PRO and will clobber
      return {
        # Same as IPHONE_58
        ScreenSize::IOS_65 => [
          [886, 1920],
          [1920, 886]
        ],
        # Same as IPHONE_40
        ScreenSize::IOS_55 => [
          [1080, 1920],
          [1920, 1080]
        ],
        ScreenSize::IOS_47 => [
          [750, 1334],
          [1334, 750]
        ],
        # Same as IOS_IPAD_11, IOS_IPAD_10_5, IOS_IPAD
        ScreenSize::IOS_IPAD_PRO => [
          [900, 1200],
          [1200, 900],
          [1200, 1600],
          [1600, 1200],
          [1440, 1080],
          [1080, 1440]
        ],
        ScreenSize::MAC => [
          [1280, 800],
          [1440, 900],
          [2560, 1600],
          [2880, 1800]
        ]
      }
    end

    def self.resolve_device_conflict_if_needed(screen_size, filename)
      is_3rd_gen = [
        "iPad Pro (12.9-inch) (3rd generation)", # default simulator name has this
        "iPad Pro (12.9-inch) (4th generation)", # default simulator name has this
        "ipadPro129", # downloaded screenshots name has this
        "IPAD_PRO_3GEN_129"
      ].any? { |key| filename.include?(key) }
      if is_3rd_gen
        if screen_size == ScreenSize::IOS_IPAD_PRO
          return ScreenSize::IOS_IPAD_PRO_12_9
        elsif screen_size == ScreenSize::IOS_IPAD_PRO_MESSAGES
          return ScreenSize::IOS_IPAD_PRO_12_9_MESSAGES
        end
      end
      screen_size
    end

    def self.calculate_screen_size(path)
      size = Fastlane::Actions.sh("ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 #{path}", log: false).split("x").map { |s| s.to_i }

      UI.user_error!("Could not find or parse file at path '#{path}'") if size.nil? || size.count == 0

      devices = self.devices

      devices.each do |screen_size, resolutions|
        if resolutions.include?(size)
          filename = Pathname.new(path).basename.to_s
          return resolve_device_conflict_if_needed(screen_size, filename)
        end
      end

      UI.user_error!("Unsupported screen size #{size} for path '#{path}'")
    end
  end

  ScreenSize = AppPreview::ScreenSize
end