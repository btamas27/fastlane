require 'fastimage'

require_relative 'module'
require_relative 'device_helper'

module Deliver
  # AppScreenshot represents one screenshots for one specific locale and
  # device type.
  class AppScreenshot
    # @return [Deliver::ScreenSize] the screen size (device type)
    #  specified at {Deliver::ScreenSize}
    attr_accessor :screen_size

    attr_accessor :path

    attr_accessor :language

    # @param path (String) path to the screenshot file
    # @param language (String) Language of this screenshot (e.g. English)
    # @param screen_size (Deliver::AppScreenshot::ScreenSize) the screen size, which
    #  will automatically be calculated when you don't set it.
    def initialize(path, language, screen_size = nil)
      self.path = path
      self.language = language
      screen_size ||= self.class.calculate_screen_size(path)

      self.screen_size = screen_size

      UI.error("Looks like the screenshot given (#{path}) does not match the requirements of #{screen_size}") unless self.is_valid?
    end

    # Validates the given screenshots (size and format)
    def is_valid?
      return false unless ["png", "PNG", "jpg", "JPG", "jpeg", "JPEG"].include?(self.path.split(".").last)

      return self.screen_size == self.class.calculate_screen_size(self.path)
    end

    # The iTC API requires a different notation for the device
    def device_type
      matching = {
        ScreenSize::IOS_35 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPHONE_35,
        ScreenSize::IOS_40 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPHONE_40,
        ScreenSize::IOS_47 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPHONE_47, # also 7 & 8
        ScreenSize::IOS_55 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPHONE_55, # also 7 Plus & 8 Plus
        ScreenSize::IOS_58 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPHONE_58,
        ScreenSize::IOS_65 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPHONE_65,
        ScreenSize::IOS_IPAD => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPAD_97,
        ScreenSize::IOS_IPAD_10_5 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPAD_105,
        ScreenSize::IOS_IPAD_11 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPAD_PRO_3GEN_11,
        ScreenSize::IOS_IPAD_PRO => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPAD_PRO_129,
        ScreenSize::IOS_IPAD_PRO_12_9 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_IPAD_PRO_3GEN_129,
        ScreenSize::IOS_40_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPHONE_40,
        ScreenSize::IOS_47_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPHONE_47, # also 7 & 8
        ScreenSize::IOS_55_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPHONE_55, # also 7 Plus & 8 Plus
        ScreenSize::IOS_58_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPHONE_58,
        ScreenSize::IOS_65_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPHONE_65,
        ScreenSize::IOS_IPAD_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPAD_97,
        ScreenSize::IOS_IPAD_PRO_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPAD_PRO_129,
        ScreenSize::IOS_IPAD_PRO_12_9_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPAD_PRO_3GEN_129,
        ScreenSize::IOS_IPAD_10_5_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPAD_105,
        ScreenSize::IOS_IPAD_11_MESSAGES => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::IMESSAGE_APP_IPAD_PRO_3GEN_11,
        ScreenSize::MAC => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_DESKTOP,
        ScreenSize::IOS_APPLE_WATCH => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_WATCH_SERIES_3,
        ScreenSize::IOS_APPLE_WATCH_SERIES4 => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_WATCH_SERIES_4,
        ScreenSize::APPLE_TV => Spaceship::ConnectAPI::AppScreenshotSet::DisplayType::APP_APPLE_TV
      }
      return matching[self.screen_size]
    end

    def self.device_messages
      # This list does not include iPad Pro 12.9-inch (3rd generation)
      # because it has same resoluation as IOS_IPAD_PRO and will clobber
      return {
        ScreenSize::IOS_65_MESSAGES => [
          [1242, 2688],
          [2688, 1242]
        ],
        ScreenSize::IOS_61_MESSAGES => [
          [828, 1792],
          [1792, 828]
        ],
        ScreenSize::IOS_58_MESSAGES => [
          [1125, 2436],
          [2436, 1125]
        ],
        ScreenSize::IOS_55_MESSAGES => [
          [1242, 2208],
          [2208, 1242]
        ],
        ScreenSize::IOS_47_MESSAGES => [
          [750, 1334],
          [1334, 750]
        ],
        ScreenSize::IOS_40_MESSAGES => [
          [640, 1096],
          [640, 1136],
          [1136, 600],
          [1136, 640]
        ],
        ScreenSize::IOS_IPAD_MESSAGES => [
          [1024, 748],
          [1024, 768],
          [2048, 1496],
          [2048, 1536],
          [768, 1004],
          [768, 1024],
          [1536, 2008],
          [1536, 2048]
        ],
        ScreenSize::IOS_IPAD_10_5_MESSAGES => [
          [1668, 2224],
          [2224, 1668]
        ],
        ScreenSize::IOS_IPAD_11_MESSAGES => [
          [1668, 2388],
          [2388, 1668]
        ],
        ScreenSize::IOS_IPAD_PRO_MESSAGES => [
          [2732, 2048],
          [2048, 2732]
        ]
      }
    end

    # reference: https://help.apple.com/app-store-connect/#/devd274dd925
    def self.devices
      # This list does not include iPad Pro 12.9-inch (3rd generation)
      # because it has same resoluation as IOS_IPAD_PRO and will clobber
      return {
        ScreenSize::IOS_65 => [
          [1242, 2688],
          [2688, 1242]
        ],
        ScreenSize::IOS_61 => [
          [828, 1792],
          [1792, 828]
        ],
        ScreenSize::IOS_58 => [
          [1125, 2436],
          [2436, 1125]
        ],
        ScreenSize::IOS_55 => [
          [1242, 2208],
          [2208, 1242]
        ],
        ScreenSize::IOS_47 => [
          [750, 1334],
          [1334, 750]
        ],
        ScreenSize::IOS_40 => [
          [640, 1096],
          [640, 1136],
          [1136, 600],
          [1136, 640]
        ],
        ScreenSize::IOS_35 => [
          [640, 920],
          [640, 960],
          [960, 600],
          [960, 640]
        ],
        ScreenSize::IOS_IPAD => [# 9.7 inch
          [1024, 748],
          [1024, 768],
          [2048, 1496],
          [2048, 1536],
          [768, 1004], # portrait without status bar
          [768, 1024],
          [1536, 2008], # portrait without status bar
          [1536, 2048]
        ],
        ScreenSize::IOS_IPAD_10_5 => [
          [1668, 2224],
          [2224, 1668]
        ],
        ScreenSize::IOS_IPAD_11 => [
          [1668, 2388],
          [2388, 1668]
        ],
        ScreenSize::IOS_IPAD_PRO => [
          [2732, 2048],
          [2048, 2732]
        ],
        ScreenSize::MAC => [
          [1280, 800],
          [1440, 900],
          [2560, 1600],
          [2880, 1800]
        ],
        ScreenSize::IOS_APPLE_WATCH => [
          [312, 390]
        ],
        ScreenSize::IOS_APPLE_WATCH_SERIES4 => [
          [368, 448]
        ],
        ScreenSize::APPLE_TV => [
          [1920, 1080],
          [3840, 2160]
        ]
      }
    end

    def self.resolve_ipadpro_conflict_if_needed(screen_size, filename)
      is_3rd_gen = [
        "iPad Pro (12.9-inch) (3rd generation)", # default simulator name has this
        "iPad Pro (12.9-inch) (4th generation)", # default simulator name has this
        "ipadPro129" # downloaded screenshots name has this
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
      size = FastImage.size(path)

      UI.user_error!("Could not find or parse file at path '#{path}'") if size.nil? || size.count == 0

      # iMessage screenshots have same resolution as app screenshots so we need to distinguish them
      path_component = Pathname.new(path).each_filename.to_a[-3]
      devices = path_component.eql?("iMessage") ? self.device_messages : self.devices

      devices.each do |screen_size, resolutions|
        if resolutions.include?(size)
          filename = Pathname.new(path).basename.to_s
          return resolve_ipadpro_conflict_if_needed(screen_size, filename)
        end
      end

      UI.user_error!("Unsupported screen size #{size} for path '#{path}'")
    end
  end
end
